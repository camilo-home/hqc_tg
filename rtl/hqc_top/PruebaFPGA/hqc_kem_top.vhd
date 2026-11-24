-- ============================================================================
-- hqc_kem_top : top-level para la DE2-115 (EP4CE115F29C7)
--   CLOCK_50 -> hqc_kem_pipeline (50 MHz, sin PLL: keygen 108, encaps 102 y decaps 87 MHz de Fmax por separado)
--   KEY[0]   : reset (pulsador, activo en bajo)
--   LEDG[0]  : DONE (hasta el siguiente start)      LEDG[1] : MATCH (el re-cifrado de decaps coincidio)
--   LEDG[2]  : K_EQUAL (ss de encaps == ss de decaps)   LEDG[3] : ERROR (encaps o protocolo)
--   LEDG[4]  : ocupado (no listo)                    LEDG[5] : err de decaps (esperable con un ct corrupto)
--   LEDR[7:0]: state_code ([3:0] pipeline, [7:4] modulo activo)
-- Desde el PC (quartus_stp, ver hqc_kem_jtag.py) se inyectan seed_kem, m y salt, se lanza y se lee K.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hqc_kem_top is
  port(
    CLOCK_50 : in  std_logic;
    KEY      : in  std_logic_vector(3 downto 0);
    LEDG     : out std_logic_vector(8 downto 0);
    LEDR     : out std_logic_vector(17 downto 0)
  );
end entity;

architecture rtl of hqc_kem_top is

  signal reset_button_sync1, reset_button_sync2 : std_logic := '1';
  signal power_on_reset_counter : integer range 0 to 15 := 0;
  signal power_on_reset : std_logic := '1';
  signal system_reset, bridge_soft_reset : std_logic;

  signal start_pulse, pipeline_ready, pipeline_done : std_logic;
  signal seed_kem_words : std_logic_vector(255 downto 0);
  signal m_words, salt_words : std_logic_vector(127 downto 0);
  signal corrupt_enable : std_logic;
  signal corrupt_word_index : unsigned(9 downto 0);
  signal corrupt_bit_index  : unsigned(5 downto 0);
  signal result_k_words, result_ss_encaps_words : std_logic_vector(255 downto 0);
  signal decaps_reenc_match, result_k_equal, result_error, result_decaps_error : std_logic;
  signal cycles_keygen, cycles_encaps, cycles_decaps, cycles_total : unsigned(31 downto 0);
  signal state_code : std_logic_vector(7 downto 0);
  signal mem_read_request, mem_read_select, mem_read_valid : std_logic;
  signal mem_read_address : unsigned(9 downto 0);
  signal mem_read_data : std_logic_vector(63 downto 0);
  signal done_led : std_logic := '0';

begin

  -- reset: pulsador sincronizado + un reset al arrancar + el reset por software del JTAG
  reset_process : process(CLOCK_50)
  begin
    if rising_edge(CLOCK_50) then
      reset_button_sync1 <= not KEY(0);
      reset_button_sync2 <= reset_button_sync1;
      if power_on_reset_counter < 15 then
        power_on_reset_counter <= power_on_reset_counter + 1;
        power_on_reset         <= '1';
      else
        power_on_reset <= '0';
      end if;
      if start_pulse = '1' then
        done_led <= '0';
      elsif pipeline_done = '1' then
        done_led <= '1';
      end if;
    end if;
  end process;

  system_reset <= reset_button_sync2 or power_on_reset or bridge_soft_reset;

  u_pipeline : entity work.hqc_kem_pipeline
    port map (clk => CLOCK_50, rst => system_reset,
              start => start_pulse, pipeline_ready => pipeline_ready, pipeline_done => pipeline_done,
              seed_kem_words => seed_kem_words, m_words => m_words, salt_words => salt_words,
              corrupt_enable => corrupt_enable, corrupt_word_index => corrupt_word_index, corrupt_bit_index => corrupt_bit_index,
              result_k_words => result_k_words, result_ss_encaps_words => result_ss_encaps_words,
              decaps_reenc_match => decaps_reenc_match, result_k_equal => result_k_equal,
              result_error => result_error, result_decaps_error => result_decaps_error,
              cycles_keygen => cycles_keygen, cycles_encaps => cycles_encaps, cycles_decaps => cycles_decaps,
              cycles_total => cycles_total, state_code => state_code,
              mem_read_request => mem_read_request, mem_read_select => mem_read_select,
              mem_read_address => mem_read_address, mem_read_valid => mem_read_valid, mem_read_data => mem_read_data);

  u_bridge : entity work.jtag_kem_bridge
    port map (clk => CLOCK_50,
              start_pulse => start_pulse, soft_reset => bridge_soft_reset,
              seed_kem_words => seed_kem_words, m_words => m_words, salt_words => salt_words,
              corrupt_enable => corrupt_enable, corrupt_word_index => corrupt_word_index, corrupt_bit_index => corrupt_bit_index,
              mem_read_request => mem_read_request, mem_read_select => mem_read_select, mem_read_address => mem_read_address,
              pipeline_ready => pipeline_ready, pipeline_done => pipeline_done, state_code => state_code,
              result_k_words => result_k_words, result_ss_encaps_words => result_ss_encaps_words,
              decaps_reenc_match => decaps_reenc_match, result_k_equal => result_k_equal,
              result_error => result_error, result_decaps_error => result_decaps_error,
              cycles_keygen => cycles_keygen, cycles_encaps => cycles_encaps, cycles_decaps => cycles_decaps,
              cycles_total => cycles_total,
              mem_read_valid => mem_read_valid, mem_read_data => mem_read_data);

  LEDG(0) <= done_led;
  LEDG(1) <= decaps_reenc_match;
  LEDG(2) <= result_k_equal;
  LEDG(3) <= result_error;
  LEDG(4) <= not pipeline_ready;
  LEDG(5) <= result_decaps_error;
  LEDG(8 downto 6) <= (others => '0');
  LEDR(7 downto 0)  <= state_code;
  LEDR(17 downto 8) <= (others => '0');

end rtl;
