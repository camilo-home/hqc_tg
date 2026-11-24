-- Testbench de @DUT@  (generado por gen_tb.py)
-- @NOTE@
--
-- * Instancia position_mem junto al DUT. El SHAKE se simula presentando palabras de 64 bits en
--   shake_din con handshake valid/ready (pass 0: valid siempre alto; pass 1: valid con huecos aleatorios).
-- * Cada caso es un flujo SHAKE real (SHAKE256(seed || 0x01)). Las posiciones esperadas salen del
--   modelo Python validado contra hqc128.py.
-- * Comprueba: (1) posiciones en pos_mem, (2) palabras consumidas al terminar cada llamada
--   (alineacion del flujo), (3) que no se piden palabras de mas, (4) wr_data < N siempre,
--   (5) que el bitmap queda limpio (las llamadas siguientes sobre el mismo DUT siguen siendo correctas).
-- Casos (en orden, semillas del modelo): @CASENAMES@
-- Orden de compilacion: position_mem.vhd, @DUT@.vhd, tb_@DUT@.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_@DUT@ is
end entity;

architecture sim of tb_@DUT@ is

  constant N      : integer := 17669;
  constant WT     : integer := @WT@;
  constant NCASES : integer := @NCASES@;
  constant NCALLS : integer := @NCALLS@;
  constant NWORDS : integer := @NWORDS@;
  constant CLK_P  : time := 10 ns;

  type word_arr   is array (0 to NWORDS-1) of std_logic_vector(63 downto 0);
  type stream_arr is array (0 to NCASES-1) of word_arr;
  type pos_arr    is array (0 to NCALLS*WT-1) of integer;
  type epos_arr   is array (0 to NCASES-1) of pos_arr;
  type cum_arr    is array (0 to NCALLS-1) of integer;
  type ecum_arr   is array (0 to NCASES-1) of cum_arr;

  -- flujo SHAKE por caso (byte 0 del flujo en bits 7:0 de cada palabra)
  constant STREAM : stream_arr := @STREAM@;

  -- posiciones esperadas: NCALLS bloques de WT (indice = direccion de pos_mem)
  constant EXP_POS : epos_arr := @EXPPOS@;

  -- palabras acumuladas que deben haberse consumido al terminar cada llamada
  constant EXP_WORDS : ecum_arr := @EXPWORDS@;

  signal clk, rst, start : std_logic := '0';
  signal shake_din   : std_logic_vector(63 downto 0);
  signal shake_valid : std_logic := '0';
  signal shake_ready : std_logic;
  signal wr_en       : std_logic;
  signal wr_addr     : unsigned(6 downto 0);
  signal wr_data     : unsigned(14 downto 0);
  signal samp_rd_addr: unsigned(6 downto 0);
  signal tb_rd_addr  : unsigned(6 downto 0) := (others => '0');
  signal mem_rd_addr : unsigned(6 downto 0);
  signal mem_dout    : unsigned(14 downto 0);
  signal sample_done : std_logic;
  signal sampling    : std_logic := '0';

  signal case_sel  : integer range 0 to NCASES-1 := 0;
  signal load      : std_logic := '0';
  signal rand_mode : std_logic := '0';
  signal wp        : integer range 0 to NWORDS := 0;   -- palabras entregadas al DUT
  signal finished  : boolean := false;

begin

  clk <= not clk after CLK_P/2 when not finished;

  -- ===== DUT + memoria =====
  dut : entity work.@DUT@
    port map(
      clk => clk, rst => rst, start => start,
      shake_din => shake_din, shake_valid => shake_valid, shake_ready => shake_ready,
      wr_en => wr_en, wr_addr => wr_addr, wr_data => wr_data,
      rd_addr => samp_rd_addr, rd_data => mem_dout,
      sample_done => sample_done);

  mem : entity work.position_mem
    generic map(DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map(clk => clk, we => wr_en, wr_addr => wr_addr, din => wr_data,
             rd_addr => mem_rd_addr, dout => mem_dout);

  -- mux de lectura: sampler mientras trabaja, testbench (consumidor) despues
  mem_rd_addr <= samp_rd_addr when sampling = '1' else tb_rd_addr;

  -- ===== modelo de SHAKE: palabra actual en shake_din, valid/ready =====
  shake_din <= STREAM(case_sel)(wp) when wp < NWORDS else (others => '0');

  shake_model : process(clk)
    variable lfsr : unsigned(15 downto 0) := x"ACE1";
    variable xfer : boolean;
    variable nxt  : integer;
  begin
    if rising_edge(clk) then
      lfsr := lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
      if load = '1' then
        wp          <= 0;
        shake_valid <= '0';
      else
        xfer := (shake_valid = '1' and shake_ready = '1');
        nxt  := wp;
        if xfer then
          nxt := wp + 1;
          wp  <= nxt;
        end if;
        -- una vez que valid sube, se mantiene hasta la transferencia
        if shake_valid = '0' or xfer then
          if nxt < NWORDS and (rand_mode = '0' or lfsr(0) = '1' or lfsr(1) = '1') then
            shake_valid <= '1';
          else
            shake_valid <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- ===== monitor: ninguna posicion escrita puede ser >= N =====
  monitor : process(clk)
  begin
    if rising_edge(clk) then
      if wr_en = '1' then
        assert wr_data < to_unsigned(N, 15)
          report "wr_data fuera de rango: " & integer'image(to_integer(wr_data)) severity error;
        assert wr_addr < to_unsigned(WT, 7)
          report "wr_addr fuera de rango: " & integer'image(to_integer(wr_addr)) severity error;
      end if;
    end if;
  end process;

  -- ===== estimulos y comprobaciones =====
  stim : process
    variable errors : integer := 0;
    variable v      : integer;
    variable e      : integer;

    procedure tick(n : integer) is
    begin
      for q in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;
  begin
    rst <= '1';
    tick(3);
    rst <= '0';
    tick(2);

    for pass in 0 to 1 loop
      if pass = 1 then
        rand_mode <= '1';           -- valid con huecos aleatorios
        rst <= '1'; tick(2); rst <= '0'; tick(2);   -- reset entre pasadas
      end if;

      for c in 0 to NCASES-1 loop
        case_sel <= c;
        load <= '1'; tick(1); load <= '0'; tick(1);

        for call in 0 to NCALLS-1 loop
          sampling <= '1';
          start <= '1'; tick(1); start <= '0';

          wait until sample_done = '1' for 500 us;
          if sample_done /= '1' then
            report "TIMEOUT pass " & integer'image(pass) & " caso " & integer'image(c) &
                   " llamada " & integer'image(call) severity error;
            finished <= true;
            wait;
          end if;
          sampling <= '0';
          tick(8);

          -- alineacion del flujo SHAKE
          if wp /= EXP_WORDS(c)(call) then
            report "pass " & integer'image(pass) & " caso " & integer'image(c) & " llamada " &
                   integer'image(call) & ": palabras consumidas = " & integer'image(wp) &
                   ", esperadas = " & integer'image(EXP_WORDS(c)(call)) severity error;
            errors := errors + 1;
          end if;

          -- contenido de pos_mem (lectura como consumidor)
          for a in 0 to WT-1 loop
            tb_rd_addr <= to_unsigned(a, 7);
            wait until rising_edge(clk);
            wait for 1 ns;
            v := to_integer(mem_dout);
            e := EXP_POS(c)(call*WT + a);
            if v /= e then
              report "pass " & integer'image(pass) & " caso " & integer'image(c) & " llamada " &
                     integer'image(call) & " pos_mem[" & integer'image(a) & "] = " &
                     integer'image(v) & ", esperado " & integer'image(e) severity error;
              errors := errors + 1;
            end if;
          end loop;
        end loop;
      end loop;
    end loop;

    if errors = 0 then
      report "tb_@DUT@: TODAS LAS PRUEBAS OK" severity note;
    else
      report "tb_@DUT@: FALLO, errores = " & integer'image(errors) severity error;
    end if;
    finished <= true;
    wait;
  end process;

end architecture;
