-- Testbench de hqc_kem_pipeline  (generado por gen_tb_kem_pipeline.py)
--
-- * Entra (seed_kem, m, salt) -> keygen -> encaps -> decaps, y se comprueba: K (ss de decaps), ss de encaps, match,
--   k_equal, error, y el CONTENIDO de dk_ram (291 palabras) y ct_ram (555 palabras) leidas por la interfaz mem_read_*,
--   exactamente lo que usara el JTAG.
-- * Casos: @NAMES@
--   Los esperados salen de hqc128.py (verificado contra el KAT oficial al generar si se paso --rsp).
-- * Imprime los ciclos de cada etapa.
-- Orden de compilacion: todo el proyecto (keygen, encaps, decaps y sus submodulos, memorias) y por ultimo
-- hqc_kem_pipeline.vhd y este archivo.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_hqc_kem_pipeline is
end entity;

architecture sim of tb_hqc_kem_pipeline is

  constant NCASES  : integer := @NCASES@;
  constant CLK_P   : time := 10 ns;

  type slv256_arr is array (0 to NCASES - 1) of std_logic_vector(255 downto 0);
  type slv128_arr is array (0 to NCASES - 1) of std_logic_vector(127 downto 0);
  type int_arr    is array (0 to NCASES - 1) of integer;
  type dk_arr     is array (0 to 290) of std_logic_vector(63 downto 0);
  type dk_cases   is array (0 to NCASES - 1) of dk_arr;
  type ct_arr     is array (0 to 554) of std_logic_vector(63 downto 0);
  type ct_cases   is array (0 to NCASES - 1) of ct_arr;

  constant SEEDS        : slv256_arr := @SEEDS@;
  constant MS           : slv128_arr := @MS@;
  constant SALTS        : slv128_arr := @SALTS@;
  constant CORRUPT_EN   : int_arr := @CEN@;
  constant CORRUPT_WORD : int_arr := @CWORD@;
  constant CORRUPT_BIT  : int_arr := @CBIT@;
  constant EXP_K        : slv256_arr := @EXPK@;     -- ss de decaps esperado
  constant EXP_SS_ENC   : slv256_arr := @EXPSS@;    -- ss de encaps esperado
  constant EXP_MATCH    : int_arr := @EXPMATCH@;    -- 1: ct valido ; 0: ct corrupto (K = k_rej)
  constant EXP_DK       : dk_cases := @DKS@;
  constant EXP_CT       : ct_cases := @CTS@;

  signal clk, rst, start : std_logic := '0';
  signal pipeline_ready, pipeline_done : std_logic;
  signal seed_kem_words : std_logic_vector(255 downto 0) := (others => '0');
  signal m_words, salt_words : std_logic_vector(127 downto 0) := (others => '0');
  signal corrupt_enable : std_logic := '0';
  signal corrupt_word_index : unsigned(9 downto 0) := (others => '0');
  signal corrupt_bit_index  : unsigned(5 downto 0) := (others => '0');
  signal result_k_words, result_ss_encaps_words : std_logic_vector(255 downto 0);
  signal result_match, result_k_equal, result_error, result_decaps_error : std_logic;
  signal cycles_keygen, cycles_encaps, cycles_decaps, cycles_total : unsigned(31 downto 0);
  signal state_code : std_logic_vector(7 downto 0);
  signal mem_read_request : std_logic := '0';
  signal mem_read_select  : std_logic := '0';
  signal mem_read_address : unsigned(9 downto 0) := (others => '0');
  signal mem_read_valid   : std_logic;
  signal mem_read_data    : std_logic_vector(63 downto 0);
  signal finished : boolean := false;

begin

  clk <= not clk after CLK_P / 2 when not finished;

  dut : entity work.hqc_kem_pipeline
    port map(clk => clk, rst => rst, start => start, pipeline_ready => pipeline_ready, pipeline_done => pipeline_done,
             seed_kem_words => seed_kem_words, m_words => m_words, salt_words => salt_words,
             corrupt_enable => corrupt_enable, corrupt_word_index => corrupt_word_index, corrupt_bit_index => corrupt_bit_index,
             result_k_words => result_k_words, result_ss_encaps_words => result_ss_encaps_words,
             result_match => result_match, result_k_equal => result_k_equal,
             result_error => result_error, result_decaps_error => result_decaps_error,
             cycles_keygen => cycles_keygen, cycles_encaps => cycles_encaps, cycles_decaps => cycles_decaps,
             cycles_total => cycles_total, state_code => state_code,
             mem_read_request => mem_read_request, mem_read_select => mem_read_select,
             mem_read_address => mem_read_address, mem_read_valid => mem_read_valid, mem_read_data => mem_read_data);

  stim : process
    variable errors : integer := 0;
    variable word   : std_logic_vector(63 downto 0);

    procedure tick(n : integer) is
    begin
      for q in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;

    -- lectura por la interfaz mem_read_* (la misma que usa el puente JTAG)
    procedure read_memory(sel : std_logic; addr : integer; variable data : out std_logic_vector(63 downto 0)) is
    begin
      mem_read_select  <= sel;
      mem_read_address <= to_unsigned(addr, 10);
      mem_read_request <= '1';
      tick(1);
      mem_read_request <= '0';
      wait until mem_read_valid = '1' for 1 us;
      data := mem_read_data;
      tick(1);
    end procedure;
  begin
    rst <= '1'; tick(5); rst <= '0'; tick(5);

    for c in 0 to NCASES - 1 loop
      seed_kem_words    <= SEEDS(c);
      m_words           <= MS(c);
      salt_words        <= SALTS(c);
      corrupt_enable    <= '1' when CORRUPT_EN(c) = 1 else '0';
      corrupt_word_index <= to_unsigned(CORRUPT_WORD(c), 10);
      corrupt_bit_index  <= to_unsigned(CORRUPT_BIT(c), 6);
      tick(2);

      if pipeline_ready /= '1' then
        wait until pipeline_ready = '1' for 1 ms;
      end if;
      assert pipeline_ready = '1' report "pipeline_ready no esta a 1 antes de start" severity error;

      start <= '1'; tick(1); start <= '0';

      wait until pipeline_done = '1' for 100 ms;
      if pipeline_done /= '1' then
        report "TIMEOUT caso " & integer'image(c) & " (state_code " &
               integer'image(to_integer(unsigned(state_code))) & ")" severity error;
        finished <= true;
        wait;
      end if;
      tick(3);

      if result_k_words /= EXP_K(c) then
        report "caso " & integer'image(c) & ": K distinta de la esperada" severity error;
        errors := errors + 1;
      end if;
      if result_ss_encaps_words /= EXP_SS_ENC(c) then
        report "caso " & integer'image(c) & ": ss de encaps distinto del esperado" severity error;
        errors := errors + 1;
      end if;
      if (result_match = '1') /= (EXP_MATCH(c) = 1) then
        report "caso " & integer'image(c) & ": match = " & std_logic'image(result_match) &
               ", esperado " & integer'image(EXP_MATCH(c)) severity error;
        errors := errors + 1;
      end if;
      if (result_k_equal = '1') /= (EXP_K(c) = EXP_SS_ENC(c)) then
        report "caso " & integer'image(c) & ": k_equal inconsistente" severity error;
        errors := errors + 1;
      end if;
      if result_error = '1' then
        report "caso " & integer'image(c) & ": result_error = 1 (encaps o conteo de palabras)" severity error;
        errors := errors + 1;
      end if;

      -- dk_ram y ct_ram leidas como lo hara el JTAG
      for a in 0 to 290 loop
        read_memory('0', a, word);
        if word /= EXP_DK(c)(a) then
          report "caso " & integer'image(c) & ": dk_ram[" & integer'image(a) & "] distinta" severity error;
          errors := errors + 1;
        end if;
      end loop;
      for a in 0 to 554 loop
        read_memory('1', a, word);
        if word /= EXP_CT(c)(a) then
          report "caso " & integer'image(c) & ": ct_ram[" & integer'image(a) & "] distinta" severity error;
          errors := errors + 1;
        end if;
      end loop;

      report "caso " & integer'image(c) & ": match = " & std_logic'image(result_match) &
             ", k_equal = " & std_logic'image(result_k_equal) &
             ", decaps_err = " & std_logic'image(result_decaps_error) &
             ", ciclos keygen/encaps/decaps/total = " & integer'image(to_integer(cycles_keygen)) & " / " &
             integer'image(to_integer(cycles_encaps)) & " / " & integer'image(to_integer(cycles_decaps)) & " / " &
             integer'image(to_integer(cycles_total)) severity note;
    end loop;

    if errors = 0 then
      report "tb_hqc_kem_pipeline: TODAS LAS PRUEBAS OK" severity note;
    else
      report "tb_hqc_kem_pipeline: FALLO, errores = " & integer'image(errors) severity error;
    end if;
    finished <= true;
    wait;
  end process;

end architecture;
