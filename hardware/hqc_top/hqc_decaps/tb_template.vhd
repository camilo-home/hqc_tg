-- Testbench de hqc_decaps  (generado por gen_tb_decaps.py)
--
-- * dk (291 palabras = salida del keygen) y ct (555 palabras: u | v | salt) entran a la vez, cada uno con su
--   propio valid/ready. Se comprueba ss (4 palabras, out_last), el pulso done y el pin match.
-- * Casos: KAT oficiales (ct valido -> ss) y ct corruptos (re-cifrado no coincide -> ss = k_rej).
--   Esperados calculados con kem_decaps de hqc128.py.
-- * Pasada 0: dk_valid, ct_valid y out_ready siempre a 1.  Pasada 1: con huecos aleatorios.
-- * Imprime cycles y cycles_core de cada ejecucion.
-- Orden de compilacion: todo el proyecto (sponge, sample_vect, samplefxwtrej, samplefxwtmod, poly_mul2,
-- sparse_xor, rs_encoder, RMEncoder, rs_decoder, rm_decoder, memorias), hqc_encaps.vhd, hqc_decaps.vhd, este archivo.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_hqc_decaps is
end entity;

architecture sim of tb_hqc_decaps is

  constant NCASES   : integer := @NCASES@;
  constant DK_WORDS : integer := 291;
  constant CT_WORDS : integer := 555;
  constant CLK_P    : time := 10 ns;

  type dk_arr   is array (0 to DK_WORDS - 1) of std_logic_vector(63 downto 0);
  type dk_cases is array (0 to NCASES - 1) of dk_arr;
  type ct_arr   is array (0 to CT_WORDS - 1) of std_logic_vector(63 downto 0);
  type ct_cases is array (0 to NCASES - 1) of ct_arr;
  type ss_arr   is array (0 to 3) of std_logic_vector(63 downto 0);
  type ss_cases is array (0 to NCASES - 1) of ss_arr;
  type int_arr  is array (0 to NCASES - 1) of integer;

  -- casos: @NAMES@
  constant DKS : dk_cases := @DKS@;
  constant CTS : ct_cases := @CTS@;
  constant EXP : ss_cases := @EXP@;
  constant EXP_MATCH : int_arr := @MATCH@;   -- 1: el re-cifrado debe coincidir ; 0: ct invalido (ss = k_rej)

  signal clk, rst, start : std_logic := '0';
  signal ready, done : std_logic;
  signal dk_valid, ct_valid : std_logic := '0';
  signal dk_ready, ct_ready : std_logic;
  signal dk_data, ct_data : std_logic_vector(63 downto 0);
  signal out_valid : std_logic;
  signal out_ready : std_logic := '0';
  signal out_data  : std_logic_vector(63 downto 0);
  signal out_last  : std_logic;
  signal match, err : std_logic;
  signal cycles, cycles_core : unsigned(31 downto 0);
  signal dbg_state : std_logic_vector(3 downto 0);

  signal case_sel  : integer range 0 to NCASES - 1 := 0;
  signal rand_mode : std_logic := '0';
  signal feed_go   : std_logic := '0';
  signal dk_active, ct_active : std_logic := '0';
  signal dk_idx    : integer range 0 to DK_WORDS - 1 := 0;
  signal ct_idx    : integer range 0 to CT_WORDS - 1 := 0;
  signal out_clear : std_logic := '0';
  signal out_idx   : integer range 0 to 4 := 0;
  signal mon_errors : integer := 0;
  signal finished  : boolean := false;

begin

  clk <= not clk after CLK_P / 2 when not finished;

  dut : entity work.hqc_decaps
    port map(clk => clk, rst => rst, start => start, ready => ready, done => done,
             dk_valid => dk_valid, dk_ready => dk_ready, dk_data => dk_data,
             ct_valid => ct_valid, ct_ready => ct_ready, ct_data => ct_data,
             out_valid => out_valid, out_ready => out_ready, out_data => out_data, out_last => out_last,
             match => match, err => err, cycles => cycles, cycles_core => cycles_core, dbg_state => dbg_state);

  dk_data <= DKS(case_sel)(dk_idx);
  ct_data <= CTS(case_sel)(ct_idx);

  -- ===== alimentadores de dk y ct (valid/ready, independientes) =====
  feeders : process(clk)
    variable lfsr : unsigned(15 downto 0) := x"BEEF";
    variable rnd1, rnd2 : std_logic;
  begin
    if rising_edge(clk) then
      lfsr := lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
      if rand_mode = '0' or lfsr(0) = '1' or lfsr(3) = '1' then rnd1 := '1'; else rnd1 := '0'; end if;
      if rand_mode = '0' or lfsr(1) = '1' or lfsr(6) = '1' then rnd2 := '1'; else rnd2 := '0'; end if;

      if feed_go = '1' then
        dk_idx <= 0; dk_active <= '1'; dk_valid <= '0';
        ct_idx <= 0; ct_active <= '1'; ct_valid <= '0';
      else
        if dk_active = '1' then
          if dk_valid = '1' and dk_ready = '1' then
            if dk_idx = DK_WORDS - 1 then dk_active <= '0'; dk_valid <= '0';
            else dk_idx <= dk_idx + 1; dk_valid <= rnd1; end if;
          elsif dk_valid = '0' then
            dk_valid <= rnd1;
          end if;
        end if;
        if ct_active = '1' then
          if ct_valid = '1' and ct_ready = '1' then
            if ct_idx = CT_WORDS - 1 then ct_active <= '0'; ct_valid <= '0';
            else ct_idx <= ct_idx + 1; ct_valid <= rnd2; end if;
          elsif ct_valid = '0' then
            ct_valid <= rnd2;
          end if;
        end if;
      end if;
    end if;
  end process;

  -- ===== monitor de la salida (ss) =====
  out_monitor : process(clk)
    variable lfsr : unsigned(15 downto 0) := x"ACE1";
    variable e    : integer;
  begin
    if rising_edge(clk) then
      lfsr := lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
      e := 0;
      if out_clear = '1' then
        out_idx <= 0;
      elsif out_valid = '1' and out_ready = '1' then
        if out_idx < 4 then
          if out_data /= EXP(case_sel)(out_idx) then
            report "caso " & integer'image(case_sel) & " palabra " & integer'image(out_idx) &
                   " de ss: dato distinto" severity error;
            e := e + 1;
          end if;
          if (out_last = '1') /= (out_idx = 3) then
            report "caso " & integer'image(case_sel) & ": out_last incorrecto en la palabra " &
                   integer'image(out_idx) severity error;
            e := e + 1;
          end if;
          out_idx <= out_idx + 1;
        else
          report "salida con mas palabras de las esperadas" severity error;
          e := e + 1;
        end if;
      end if;
      mon_errors <= mon_errors + e;
      if rand_mode = '0' or lfsr(0) = '1' or lfsr(5) = '1' then out_ready <= '1'; else out_ready <= '0'; end if;
    end if;
  end process;

  -- ===== estimulos =====
  stim : process
    variable lerrors : integer := 0;
    procedure tick(n : integer) is
    begin
      for q in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;
  begin
    rst <= '1'; tick(5); rst <= '0'; tick(5);

    for pass in 0 to 1 loop
      if pass = 1 then rand_mode <= '1'; end if;
      for c in 0 to NCASES - 1 loop
        case_sel <= c;
        out_clear <= '1'; tick(2); out_clear <= '0'; tick(1);

        if ready /= '1' then
          wait until ready = '1' for 1 ms;
        end if;
        assert ready = '1' report "ready no esta a 1 antes de start" severity error;

        start <= '1'; feed_go <= '1'; tick(1); start <= '0'; feed_go <= '0';

        wait until done = '1' for 50 ms;
        if done /= '1' then
          report "TIMEOUT pass " & integer'image(pass) & " caso " & integer'image(c) &
                 " (estado " & integer'image(to_integer(unsigned(dbg_state))) & ", palabras ss " &
                 integer'image(out_idx) & ")" severity error;
          finished <= true;
          wait;
        end if;
        tick(4);

        if out_idx /= 4 then
          report "pass " & integer'image(pass) & " caso " & integer'image(c) & ": se recibieron " &
                 integer'image(out_idx) & " palabras de ss, esperadas 4" severity error;
          lerrors := lerrors + 1;
        end if;
        if (match = '1') /= (EXP_MATCH(c) = 1) then
          report "pass " & integer'image(pass) & " caso " & integer'image(c) & ": match = " &
                 std_logic'image(match) & ", esperado " & integer'image(EXP_MATCH(c)) severity error;
          lerrors := lerrors + 1;
        end if;
        report "pass " & integer'image(pass) & " caso " & integer'image(c) &
               ": match = " & std_logic'image(match) & ", err = " & std_logic'image(err) &
               ", cycles = " & integer'image(to_integer(cycles)) &
               ", cycles_core = " & integer'image(to_integer(cycles_core)) severity note;
      end loop;
    end loop;

    if lerrors + mon_errors = 0 then
      report "tb_hqc_decaps: TODAS LAS PRUEBAS OK" severity note;
    else
      report "tb_hqc_decaps: FALLO, errores = " & integer'image(lerrors + mon_errors) severity error;
    end if;
    finished <= true;
    wait;
  end process;

end architecture;
