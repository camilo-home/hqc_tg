library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wrapper_kat0 is
  port(
    CLOCK_50 : in  std_logic;
    KEY      : in  std_logic_vector(3 downto 0);   -- KEY(0): reset (activo en bajo)
    SW       : in  std_logic_vector(17 downto 0);  -- SW(0): start, SW(1): corrupt_enable
    LEDR     : out std_logic_vector(17 downto 0)
  );
end entity;

architecture rtl of wrapper_kat0 is

  -- Vectores KAT en palabras de 64 bits little-endian
  constant SEED_W0 : std_logic_vector(63 downto 0) := x"C3040E05600DFCCE";
  constant SEED_W1 : std_logic_vector(63 downto 0) := x"D288A84BE5591817";
  constant SEED_W2 : std_logic_vector(63 downto 0) := x"0B6B92BE2EE270F6";
  constant SEED_W3 : std_logic_vector(63 downto 0) := x"F808BC4F26657A30";

  constant M_W0    : std_logic_vector(63 downto 0) := x"8F9163892FA1EC3D";
  constant M_W1    : std_logic_vector(63 downto 0) := x"DEFF1F57F2677C53";

  constant SALT_W0 : std_logic_vector(63 downto 0) := x"0C8626D88406B84B";
  constant SALT_W1 : std_logic_vector(63 downto 0) := x"F57155E386CE1575";

  constant SEED_KEM_CONST : std_logic_vector(255 downto 0) := SEED_W3 & SEED_W2 & SEED_W1 & SEED_W0;
  constant M_CONST        : std_logic_vector(127 downto 0) := M_W1 & M_W0;
  constant SALT_CONST     : std_logic_vector(127 downto 0) := SALT_W1 & SALT_W0;

  -- Control y sincronización
  signal rst             : std_logic;
  signal sw0_sync        : std_logic_vector(1 downto 0) := (others => '0');
  signal sw1_sync        : std_logic_vector(1 downto 0) := (others => '0');
  signal start_pulse     : std_logic := '0';
  signal done_latched    : std_logic := '0';

  -- Señales del núcleo hqc_kem_pipeline
  signal pipeline_ready         : std_logic;
  signal pipeline_done          : std_logic;
  signal result_k_words         : std_logic_vector(255 downto 0);
  signal result_ss_encaps_words : std_logic_vector(255 downto 0);
  signal decaps_reenc_match     : std_logic;
  signal result_k_equal         : std_logic;
  signal result_error           : std_logic;
  signal result_decaps_error    : std_logic;
  signal cycles_keygen          : unsigned(31 downto 0);
  signal cycles_encaps          : unsigned(31 downto 0);
  signal cycles_decaps          : unsigned(31 downto 0);
  signal cycles_total           : unsigned(31 downto 0);
  signal state_code             : std_logic_vector(7 downto 0);

  -- Evita que Quartus pode las señales observadas en SignalTap
  attribute keep : boolean;
  attribute keep of start_pulse            : signal is true;
  attribute keep of pipeline_ready         : signal is true;
  attribute keep of pipeline_done          : signal is true;
  attribute keep of result_k_words         : signal is true;
  attribute keep of result_ss_encaps_words : signal is true;
  attribute keep of decaps_reenc_match     : signal is true;
  attribute keep of result_k_equal         : signal is true;
  attribute keep of result_error           : signal is true;
  attribute keep of result_decaps_error    : signal is true;
  attribute keep of cycles_keygen          : signal is true;
  attribute keep of cycles_encaps          : signal is true;
  attribute keep of cycles_decaps          : signal is true;
  attribute keep of cycles_total           : signal is true;
  attribute keep of state_code             : signal is true;
  attribute preserve : boolean;
  attribute noprune  : boolean;
  attribute preserve of result_k_words         : signal is true;
  attribute noprune  of result_k_words         : signal is true;
  attribute preserve of result_ss_encaps_words : signal is true;
  attribute noprune  of result_ss_encaps_words : signal is true;
  attribute preserve of cycles_total           : signal is true;
  attribute noprune  of cycles_total           : signal is true;

  function xor_reduce(v : std_logic_vector) return std_logic is
  variable r : std_logic := '0';
begin
  for i in v'range loop
    r := r xor v(i);
  end loop;
  return r;
end function;
begin

  rst <= not KEY(0);

  -- Sincronizadores de interruptores y generador de pulso start (1 ciclo)
  process(CLOCK_50)
  begin
    if rising_edge(CLOCK_50) then
      if rst = '1' then
        sw0_sync     <= (others => '0');
        sw1_sync     <= (others => '0');
        start_pulse  <= '0';
        done_latched <= '0';
      else
        sw0_sync <= sw0_sync(0) & SW(0);
        sw1_sync <= sw1_sync(0) & SW(1);

        start_pulse <= '0';
        if sw0_sync = "01" and pipeline_ready = '1' then
          start_pulse  <= '1';
          done_latched <= '0';
        elsif pipeline_done = '1' then
          done_latched <= '1';
        end if;
      end if;
    end if;
  end process;

  u_hqc_kem_pipeline : entity work.hqc_kem_pipeline
    port map (
      clk                    => CLOCK_50,
      rst                    => rst,
      start                  => start_pulse,
      pipeline_ready         => pipeline_ready,
      pipeline_done          => pipeline_done,
      seed_kem_words         => SEED_KEM_CONST,
      m_words                => M_CONST,
      salt_words             => SALT_CONST,
      corrupt_enable         => sw1_sync(1),
      corrupt_word_index     => to_unsigned(0, 10),
      corrupt_bit_index      => to_unsigned(0, 6),
      result_k_words         => result_k_words,
      result_ss_encaps_words => result_ss_encaps_words,
      decaps_reenc_match     => decaps_reenc_match,
      result_k_equal         => result_k_equal,
      result_error           => result_error,
      result_decaps_error    => result_decaps_error,
      cycles_keygen          => cycles_keygen,
      cycles_encaps          => cycles_encaps,
      cycles_decaps          => cycles_decaps,
      cycles_total           => cycles_total,
      state_code             => state_code,
      mem_read_request       => '0',
      mem_read_select        => '0',
      mem_read_address       => (others => '0'),
      mem_read_valid         => open,
      mem_read_data          => open
    );

    
  -- Indicadores físicos en LEDs rojos
  LEDR(0)           <= pipeline_ready;
  LEDR(1)           <= done_latched;
  LEDR(2)           <= decaps_reenc_match;
  LEDR(3)           <= result_k_equal;
  LEDR(4)           <= result_error;
  LEDR(5)           <= result_decaps_error;
  LEDR(6) <= xor_reduce(result_k_words) xor
           xor_reduce(result_ss_encaps_words) xor
           xor_reduce(std_logic_vector(cycles_keygen)) xor
           xor_reduce(std_logic_vector(cycles_encaps)) xor
           xor_reduce(std_logic_vector(cycles_decaps)) xor
           xor_reduce(std_logic_vector(cycles_total));
  LEDR(9 downto 7)  <= (others => '0');
  
  LEDR(17 downto 10) <= state_code;

end architecture;