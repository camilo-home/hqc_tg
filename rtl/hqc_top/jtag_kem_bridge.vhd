-- ============================================================================
-- jtag_kem_bridge : puente PC <-> hqc_kem_pipeline por USB-Blaster (IP "Virtual JTAG", sin pines extra)
--
-- Registros (IR de 4 bits; el bit menos significativo entra/sale primero):
--   IR 1 ID       DR 32   lectura : 0x48514332 ("HQC2")
--   IR 2 INPUT    DR 512  escritura: [255:0] seed_kem | [383:256] m | [511:384] salt   (palabra i = bits 64i+63..64i)
--   IR 3 CTRL     DR 16   escritura: bit0 = 1 -> start ; bit1 = 1 -> reset por software (los demas bits se ignoran;
--                                    leer el estado escribiendo 0 es inofensivo)
--                         lectura : [0] DONE  [1] ACK  [2] READY  [3] MATCH  [4] K_EQUAL  [5] ERROR
--                                   [6] MEM_ACK  [7] DECAPS_ERR  [15:8] state_code (sin sincronizar, solo depuracion)
--   IR 4 CORRUPT  DR 17   escritura: [5:0] bit | [15:6] palabra del ct | [16] habilitar (se conserva hasta reescribirlo)
--   IR 5 MEMADDR  DR 11   escritura: [9:0] direccion | [10] seleccion (0 dk_ram 291 palabras, 1 ct_ram 555 palabras);
--                                    dispara la lectura; esperar MEM_ACK
--   IR 6 MEMDATA  DR 64   lectura : palabra leida
--   IR 7 RESULT   DR 640  lectura : [255:0] K (ss de decaps) | [511:256] ss de encaps | [543:512] ciclos keygen |
--                                   [575:544] ciclos encaps | [607:576] ciclos decaps | [639:608] ciclos totales
--                                   (valido cuando DONE = 1)
--
-- Cruce de dominios: TCK <-> clk. INPUT/CORRUPT/MEM* son estaticos cuando se usan; start, reset, done y la lectura de
-- memoria cruzan con sincronizadores de 2 FF (toggle / nivel). Ver SDC al final.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity jtag_kem_bridge is
  port(
    clk : in std_logic;

    -- hacia hqc_kem_pipeline
    start_pulse        : out std_logic;
    soft_reset         : out std_logic;                     -- nivel durante 4 ciclos
    seed_kem_words     : out std_logic_vector(255 downto 0);
    m_words            : out std_logic_vector(127 downto 0);
    salt_words         : out std_logic_vector(127 downto 0);
    corrupt_enable     : out std_logic;
    corrupt_word_index : out unsigned(9 downto 0);
    corrupt_bit_index  : out unsigned(5 downto 0);
    mem_read_request   : out std_logic;
    mem_read_select    : out std_logic;
    mem_read_address   : out unsigned(9 downto 0);

    -- desde hqc_kem_pipeline
    pipeline_ready         : in std_logic;
    pipeline_done          : in std_logic;                  -- pulso
    state_code             : in std_logic_vector(7 downto 0);
    result_k_words         : in std_logic_vector(255 downto 0);
    result_ss_encaps_words : in std_logic_vector(255 downto 0);
    decaps_reenc_match           : in std_logic;
    result_k_equal         : in std_logic;
    result_error           : in std_logic;
    result_decaps_error    : in std_logic;
    cycles_keygen          : in unsigned(31 downto 0);
    cycles_encaps          : in unsigned(31 downto 0);
    cycles_decaps          : in unsigned(31 downto 0);
    cycles_total           : in unsigned(31 downto 0);
    mem_read_valid         : in std_logic;
    mem_read_data          : in std_logic_vector(63 downto 0)
  );
end entity;

architecture rtl of jtag_kem_bridge is

  component sld_virtual_jtag
    generic(
      sld_auto_instance_index : string  := "YES";
      sld_instance_index      : integer := 0;
      sld_ir_width            : integer := 4
    );
    port(
      tdi               : out std_logic;
      tdo               : in  std_logic;
      ir_in             : out std_logic_vector(3 downto 0);
      ir_out            : in  std_logic_vector(3 downto 0);
      virtual_state_cdr : out std_logic;
      virtual_state_sdr : out std_logic;
      virtual_state_udr : out std_logic;
      tck               : out std_logic
    );
  end component;

  constant IR_ID      : std_logic_vector(3 downto 0) := "0001";
  constant IR_INPUT   : std_logic_vector(3 downto 0) := "0010";
  constant IR_CTRL    : std_logic_vector(3 downto 0) := "0011";
  constant IR_CORRUPT : std_logic_vector(3 downto 0) := "0100";
  constant IR_MEMADDR : std_logic_vector(3 downto 0) := "0101";
  constant IR_MEMDATA : std_logic_vector(3 downto 0) := "0110";
  constant IR_RESULT  : std_logic_vector(3 downto 0) := "0111";
  constant ID_CONSTANT : std_logic_vector(31 downto 0) := x"48514332";

  -- ================= dominio TCK =================
  signal tck, tdi, tdo : std_logic;
  signal ir_in, ir_out : std_logic_vector(3 downto 0);
  signal virtual_state_capture, virtual_state_shift, virtual_state_update : std_logic;

  signal shift_id      : std_logic_vector(31 downto 0)  := (others => '0');
  signal shift_input   : std_logic_vector(511 downto 0) := (others => '0');
  signal shift_ctrl    : std_logic_vector(15 downto 0)  := (others => '0');
  signal shift_corrupt : std_logic_vector(16 downto 0)  := (others => '0');
  signal shift_memaddr : std_logic_vector(10 downto 0)  := (others => '0');
  signal shift_memdata : std_logic_vector(63 downto 0)  := (others => '0');
  signal shift_result  : std_logic_vector(639 downto 0) := (others => '0');

  signal input_tck        : std_logic_vector(511 downto 0) := (others => '0');
  signal corrupt_tck      : std_logic_vector(16 downto 0)  := (others => '0');
  signal start_toggle_tck : std_logic := '0';
  signal reset_toggle_tck : std_logic := '0';
  signal mem_request_toggle_tck : std_logic := '0';
  signal mem_select_tck   : std_logic := '0';
  signal mem_address_tck  : std_logic_vector(9 downto 0) := (others => '0');

  signal done_sync1, done_sync2, ack_sync1, ack_sync2, ready_sync1, ready_sync2 : std_logic := '0';
  signal match_sync1, match_sync2, kequal_sync1, kequal_sync2, error_sync1, error_sync2 : std_logic := '0';
  signal decaps_error_sync1, decaps_error_sync2, mem_ack_sync1, mem_ack_sync2 : std_logic := '0';
  signal ack_ok, done_ok, mem_ack_ok : std_logic;

  -- ================= dominio clk =================
  signal start_sync1, start_sync2, start_previous : std_logic := '0';
  signal reset_sync1, reset_sync2, reset_previous : std_logic := '0';
  signal mem_request_sync1, mem_request_sync2, mem_request_previous : std_logic := '0';
  signal ack_toggle_clk       : std_logic := '0';
  signal done_level_clk       : std_logic := '0';
  signal start_pending        : std_logic := '0';
  signal start_pulse_register : std_logic := '0';
  signal soft_reset_counter   : integer range 0 to 4 := 0;
  signal mem_request_pulse    : std_logic := '0';
  signal mem_ack_toggle_clk   : std_logic := '0';
  signal mem_data_clk         : std_logic_vector(63 downto 0) := (others => '0');

begin

  vjtag : sld_virtual_jtag
    generic map(sld_auto_instance_index => "YES", sld_instance_index => 0, sld_ir_width => 4)
    port map(tdi => tdi, tdo => tdo, ir_in => ir_in, ir_out => ir_out,
             virtual_state_cdr => virtual_state_capture, virtual_state_sdr => virtual_state_shift,
             virtual_state_udr => virtual_state_update, tck => tck);

  ir_out <= ir_in;

  tdo <= shift_id(0)      when ir_in = IR_ID      else
         shift_input(0)   when ir_in = IR_INPUT   else
         shift_ctrl(0)    when ir_in = IR_CTRL    else
         shift_corrupt(0) when ir_in = IR_CORRUPT else
         shift_memaddr(0) when ir_in = IR_MEMADDR else
         shift_memdata(0) when ir_in = IR_MEMDATA else
         shift_result(0)  when ir_in = IR_RESULT  else
         '0';

  ack_ok     <= '1' when ack_sync2 = start_toggle_tck else '0';        -- el start ya fue visto por clk
  done_ok    <= done_sync2 and ack_ok;
  mem_ack_ok <= '1' when mem_ack_sync2 = mem_request_toggle_tck else '0';

  -- ===================== TCK =====================
  tck_process : process(tck)
  begin
    if rising_edge(tck) then
      done_sync1 <= done_level_clk;     done_sync2 <= done_sync1;
      ack_sync1  <= ack_toggle_clk;     ack_sync2  <= ack_sync1;
      ready_sync1 <= pipeline_ready;    ready_sync2 <= ready_sync1;
      match_sync1 <= decaps_reenc_match;      match_sync2 <= match_sync1;
      kequal_sync1 <= result_k_equal;   kequal_sync2 <= kequal_sync1;
      error_sync1 <= result_error;      error_sync2 <= error_sync1;
      decaps_error_sync1 <= result_decaps_error;  decaps_error_sync2 <= decaps_error_sync1;
      mem_ack_sync1 <= mem_ack_toggle_clk;        mem_ack_sync2 <= mem_ack_sync1;

      if virtual_state_capture = '1' then
        case ir_in is
          when IR_ID      => shift_id <= ID_CONSTANT;
          when IR_CTRL    => shift_ctrl <= state_code & decaps_error_sync2 & mem_ack_ok & error_sync2 & kequal_sync2 &
                                           match_sync2 & ready_sync2 & ack_ok & done_ok;
          when IR_MEMDATA => shift_memdata <= mem_data_clk;
          when IR_RESULT  => shift_result  <= std_logic_vector(cycles_total) & std_logic_vector(cycles_decaps) &
                                              std_logic_vector(cycles_encaps) & std_logic_vector(cycles_keygen) &
                                              result_ss_encaps_words & result_k_words;
          when others     => null;
        end case;

      elsif virtual_state_shift = '1' then
        case ir_in is
          when IR_ID      => shift_id      <= tdi & shift_id(31 downto 1);
          when IR_INPUT   => shift_input   <= tdi & shift_input(511 downto 1);
          when IR_CTRL    => shift_ctrl    <= tdi & shift_ctrl(15 downto 1);
          when IR_CORRUPT => shift_corrupt <= tdi & shift_corrupt(16 downto 1);
          when IR_MEMADDR => shift_memaddr <= tdi & shift_memaddr(10 downto 1);
          when IR_MEMDATA => shift_memdata <= tdi & shift_memdata(63 downto 1);
          when IR_RESULT  => shift_result  <= tdi & shift_result(639 downto 1);
          when others     => null;
        end case;

      elsif virtual_state_update = '1' then
        case ir_in is
          when IR_INPUT   => input_tck   <= shift_input;
          when IR_CORRUPT => corrupt_tck <= shift_corrupt;
          when IR_CTRL    =>
            if shift_ctrl(0) = '1' then start_toggle_tck <= not start_toggle_tck; end if;
            if shift_ctrl(1) = '1' then reset_toggle_tck <= not reset_toggle_tck; end if;
          when IR_MEMADDR =>
            mem_select_tck         <= shift_memaddr(10);
            mem_address_tck        <= shift_memaddr(9 downto 0);
            mem_request_toggle_tck <= not mem_request_toggle_tck;
          when others     => null;
        end case;
      end if;
    end if;
  end process;

  -- ===================== clk =====================
  seed_kem_words     <= input_tck(255 downto 0);
  m_words            <= input_tck(383 downto 256);
  salt_words         <= input_tck(511 downto 384);
  corrupt_bit_index  <= unsigned(corrupt_tck(5 downto 0));
  corrupt_word_index <= unsigned(corrupt_tck(15 downto 6));
  corrupt_enable     <= corrupt_tck(16);
  mem_read_select    <= mem_select_tck;
  mem_read_address   <= unsigned(mem_address_tck);

  start_pulse      <= start_pulse_register;
  soft_reset       <= '1' when soft_reset_counter /= 0 else '0';
  mem_read_request <= mem_request_pulse;

  clk_process : process(clk)
  begin
    if rising_edge(clk) then
      start_sync1   <= start_toggle_tck;        start_sync2   <= start_sync1;
      reset_sync1   <= reset_toggle_tck;        reset_sync2   <= reset_sync1;
      mem_request_sync1 <= mem_request_toggle_tck;  mem_request_sync2 <= mem_request_sync1;

      start_pulse_register <= '0';
      mem_request_pulse    <= '0';

      -- el pipeline termino
      if pipeline_done = '1' then
        done_level_clk <= '1';
      end if;

      -- peticion de lectura de memoria: se atiende con un pulso; el pipeline contesta con mem_read_valid
      if mem_request_sync2 /= mem_request_previous then
        mem_request_previous <= mem_request_sync2;
        mem_request_pulse    <= '1';
      end if;
      if mem_read_valid = '1' then
        mem_data_clk       <= mem_read_data;
        mem_ack_toggle_clk <= not mem_ack_toggle_clk;
      end if;

      -- reset por software: nivel de 4 ciclos hacia todo el diseno
      if soft_reset_counter /= 0 then
        soft_reset_counter <= soft_reset_counter - 1;
      end if;
      if reset_sync2 /= reset_previous then
        reset_previous     <= reset_sync2;
        soft_reset_counter <= 4;
        start_pending      <= '0';
      end if;

      -- start pedido por el PC: se mantiene pendiente hasta que el pipeline esta listo
      if start_pending = '1' and pipeline_ready = '1' and soft_reset_counter = 0 then
        start_pulse_register <= '1';
        start_pending        <= '0';
      end if;
      if start_sync2 /= start_previous then
        start_previous <= start_sync2;
        ack_toggle_clk <= start_sync2;
        done_level_clk <= '0';
        start_pending  <= '1';
      end if;
    end if;
  end process;

end rtl;

-- ---------------------------------------------------------------------------------------------
-- SDC (ver hqc_kem.sdc): TCK y clk son asincronos; INPUT/CORRUPT/MEM* y los resultados son estaticos al leerse
--   set_clock_groups -asynchronous -group [get_clocks {CLOCK_50}] -group [get_clocks {altera_reserved_tck}]
-- ---------------------------------------------------------------------------------------------
