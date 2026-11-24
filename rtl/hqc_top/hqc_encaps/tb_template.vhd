-- Testbench de hqc_encaps  (generado por gen_tb_encaps.py)
--
-- * Inyecta ek (281 palabras) + m (2) + salt (2) por key_valid/key_ready y comprueba TODA la salida
--   (ss | v | u | salt segun OUT_SEQ del DUT): dato, out_part y out_last de cada palabra, y el pulso done.
-- * Los vectores salen de hqc128.py (kem_encaps) con el flujo de datos exacto del hardware.
-- * Pasada 0: key_valid y out_ready siempre a 1.  Pasada 1: ambos con huecos aleatorios (handshake).
-- * Imprime cycles y cycles_core de cada ejecucion.
-- Orden de compilacion: todo el proyecto (sponge, sample_vect, samplefxwtmod, poly_mul2, sparse_xor,
-- rs_encoder, RMEncoder, memorias) y por ultimo hqc_encaps.vhd y este archivo.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_hqc_encaps is
end entity;

architecture sim of tb_hqc_encaps is

  constant NCASES    : integer := @NCASES@;
  constant KEY_WORDS : integer := 285;
  constant OUT_WORDS : integer := 559;
  constant CLK_P     : time := 10 ns;

  type key_arr   is array (0 to KEY_WORDS - 1) of std_logic_vector(63 downto 0);
  type key_cases is array (0 to NCASES - 1) of key_arr;
  type out_arr   is array (0 to OUT_WORDS - 1) of std_logic_vector(63 downto 0);
  type out_cases is array (0 to NCASES - 1) of out_arr;
  type flag_arr  is array (0 to OUT_WORDS - 1) of integer;

  -- entrada: ek (281 palabras) || m (2) || salt (2)
  constant KEYS : key_cases := @KEYS@;

  -- salida esperada: @ORDER@
  constant EXP : out_cases := @EXP@;

  -- por palabra de salida: 2*out_part + out_last (igual para todos los casos)
  constant FLAGS : flag_arr := @FLAGS@;

  signal clk, rst, start : std_logic := '0';
  signal ready, done : std_logic;
  signal key_valid : std_logic := '0';
  signal key_ready : std_logic;
  signal key_data  : std_logic_vector(63 downto 0);
  signal out_valid : std_logic;
  signal out_ready : std_logic := '0';
  signal out_data  : std_logic_vector(63 downto 0);
  signal out_last  : std_logic;
  signal out_part  : std_logic_vector(1 downto 0);
  signal cycles, cycles_core : unsigned(31 downto 0);
  signal err : std_logic;
  signal dbg_state : std_logic_vector(3 downto 0);

  signal case_sel  : integer range 0 to NCASES - 1 := 0;
  signal rand_mode : std_logic := '0';
  signal kf_go, kf_active : std_logic := '0';
  signal kf_idx    : integer range 0 to KEY_WORDS - 1 := 0;
  signal out_clear : std_logic := '0';
  signal out_idx   : integer range 0 to OUT_WORDS := 0;
  signal mon_errors : integer := 0;
  signal finished  : boolean := false;

begin

  clk <= not clk after CLK_P / 2 when not finished;

  dut : entity work.hqc_encaps
    port map(clk => clk, rst => rst, start => start, ready => ready, done => done,
             key_valid => key_valid, key_ready => key_ready, key_data => key_data,
             out_valid => out_valid, out_ready => out_ready, out_data => out_data,
             out_last => out_last, out_part => out_part,
             cycles => cycles, cycles_core => cycles_core, err => err, dbg_state => dbg_state);

  key_data <= KEYS(case_sel)(kf_idx);

  -- ===== alimentador de la clave (valid/ready) =====
  key_feeder : process(clk)
    variable lfsr : unsigned(15 downto 0) := x"BEEF";
    variable rnd  : std_logic;
    variable xfer : boolean;
  begin
    if rising_edge(clk) then
      lfsr := lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
      if rand_mode = '0' or lfsr(0) = '1' or lfsr(3) = '1' then rnd := '1'; else rnd := '0'; end if;
      if kf_go = '1' then
        kf_idx <= 0; kf_active <= '1'; key_valid <= '0';
      elsif kf_active = '1' then
        xfer := (key_valid = '1' and key_ready = '1');
        if xfer then
          if kf_idx = KEY_WORDS - 1 then
            kf_active <= '0'; key_valid <= '0';
          else
            kf_idx <= kf_idx + 1; key_valid <= rnd;
          end if;
        elsif key_valid = '0' then
          key_valid <= rnd;
        end if;
      end if;
    end if;
  end process;

  -- ===== monitor de la salida =====
  out_monitor : process(clk)
    variable lfsr : unsigned(15 downto 0) := x"ACE1";
    variable e    : integer;
    variable flag : integer;
  begin
    if rising_edge(clk) then
      lfsr := lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
      e := 0;
      if out_clear = '1' then
        out_idx <= 0;
      elsif out_valid = '1' and out_ready = '1' then
        if out_idx < OUT_WORDS then
          if out_data /= EXP(case_sel)(out_idx) then
            report "caso " & integer'image(case_sel) & " palabra " & integer'image(out_idx) &
                   ": dato distinto" severity error;
            e := e + 1;
          end if;
          flag := 2 * to_integer(unsigned(out_part));
          if out_last = '1' then flag := flag + 1; end if;
          if flag /= FLAGS(out_idx) then
            report "caso " & integer'image(case_sel) & " palabra " & integer'image(out_idx) &
                   ": out_part/out_last = " & integer'image(flag) & ", esperado " &
                   integer'image(FLAGS(out_idx)) severity error;
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

        start <= '1'; kf_go <= '1'; tick(1); start <= '0'; kf_go <= '0';

        wait until done = '1' for 20 ms;
        if done /= '1' then
          report "TIMEOUT pass " & integer'image(pass) & " caso " & integer'image(c) &
                 " (estado " & integer'image(to_integer(unsigned(dbg_state))) & ", palabras " &
                 integer'image(out_idx) & ")" severity error;
          finished <= true;
          wait;
        end if;
        tick(4);

        if out_idx /= OUT_WORDS then
          report "pass " & integer'image(pass) & " caso " & integer'image(c) & ": se recibieron " &
                 integer'image(out_idx) & " palabras, esperadas " & integer'image(OUT_WORDS) severity error;
          lerrors := lerrors + 1;
        end if;
        if err = '1' then
          report "el RS reporta error (err = 1)" severity error;
          lerrors := lerrors + 1;
        end if;
        report "pass " & integer'image(pass) & " caso " & integer'image(c) &
               ": cycles = " & integer'image(to_integer(cycles)) &
               ", cycles_core = " & integer'image(to_integer(cycles_core)) severity note;
      end loop;
    end loop;

    if lerrors + mon_errors = 0 then
      report "tb_hqc_encaps: TODAS LAS PRUEBAS OK" severity note;
    else
      report "tb_hqc_encaps: FALLO, errores = " & integer'image(lerrors + mon_errors) severity error;
    end if;
    finished <= true;
    wait;
  end process;

end architecture;
