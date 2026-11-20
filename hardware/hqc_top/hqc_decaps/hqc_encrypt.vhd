-- ============================================================================
-- hqc_encrypt : HQC-128 PKE.Encrypt(ek, m, theta) -> (u, v)
--
--   NO calcula ningun hash de la capa KEM: tmp_h, SHA3-512 (kk, theta) y salt los resuelve quien lo instancie
--   (decaps hoy, encaps manana). Solo usa SHAKE256 para h (a partir de seed_ek) y para r2, e, r1 (a partir de theta).
--
--   entrada : pulso start (solo con ready='1'); luego 287 palabras de 64 bits por in_valid/in_ready:
--               palabras   0..3    seed_ek (32 B)           \  ek = 2241 B (la palabra 280 solo lleva 1 byte)
--               palabras   4..280  s (2209 B)               /
--               palabras 281..282  m (16 B)
--               palabras 283..286  theta (32 B)
--             Los bytes van en las palabras con el byte 0 en los bits [7:0] (igual que el sponge).
--             Pueden llegar con huecos: el modulo espera m y theta sin hacer nada mas.
--   salida  : u y v por out_valid/out_ready, en este orden (c_pke = u || v):
--               out_part = '0'  u : 277 palabras (2209 B; la ultima palabra solo tiene 5 bits distintos de 0)
--               out_part = '1'  v : 276 palabras (2208 B)
--             out_last marca la ultima palabra de cada parte. done = pulso al terminar de entregar v.
--   cycles      : ciclos desde start hasta tener u y v listos (incluye la ingesta)
--   cycles_core : igual pero desde el fin de la ingesta (no depende de quien alimenta in_*)
--
-- Una micro-operacion de sponge a la vez, con el codificador RS/RM en paralelo:
--   1) SHAKE256(seed_ek||01), 2216 B -> sample_vect -> RAM h
--   2) SHAKE256(theta||01), SIN LIMITE -> sampler mod: r2, e, r1 (tres bancos de posiciones); abort al terminar
--   3) poly_mul2 DUAL: u = r2*h (RAM u) y v = r2*s (RAM v)
--   4) sparse_xor: u <- u xor r1 ; v <- v xor e
--   5) salida: u, y v xor cm al vuelo (cm = RM(RS(m)), RAM cm, ya calculada en paralelo)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.keccak_sponge_pkg.all;

entity hqc_encrypt is
  generic(
    SAMPLE_WEIGHT_R_E : integer := 75;     -- peso de r1, r2 y e (HQC-128)
    RS_OUT_REVERSED   : boolean := true;   -- true: el rs_encoder emite el simbolo cw[45] primero (orden inverso)
    RS_START_OVERLAP  : boolean := true;   -- true: i_start_codeword coincide con el primer simbolo
    RM_GEN_01         : boolean := false   -- generator_matrix_01 del RMEncoder (HQC: tabla HQC_RM_TAB -> false)
  );
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;

    start : in  std_logic;        -- pulso, solo con ready='1'
    ready : out std_logic;
    done  : out std_logic;        -- pulso al terminar de entregar u y v

    in_valid : in  std_logic;
    in_ready : out std_logic;
    in_data  : in  std_logic_vector(63 downto 0);

    out_valid : out std_logic;
    out_ready : in  std_logic;
    out_data  : out std_logic_vector(63 downto 0);
    out_last  : out std_logic;
    out_part  : out std_logic;    -- '0' = u, '1' = v

    cycles      : out unsigned(31 downto 0);
    cycles_core : out unsigned(31 downto 0);
    err         : out std_logic;   -- pegajoso: error del rs_encoder (se limpia con start)
    dbg_state   : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of hqc_encrypt is

  -- --------------------------------------------------------------------------
  -- Constantes
  -- --------------------------------------------------------------------------
  constant VECTOR_WORDS       : integer := 277;               -- palabras de un vector denso (N = 17669)
  constant V_OUTPUT_WORDS     : integer := 276;               -- palabras de v (N1N2 = 17664 bits)
  constant H_STREAM_BYTES     : integer := VECTOR_WORDS * 8;  -- 2216 B que consume sample_vect

  constant INPUT_INDEX_EK_S_FIRST    : integer := 4;
  constant INPUT_INDEX_EK_S_LAST     : integer := 280;
  constant INPUT_INDEX_MESSAGE_FIRST : integer := 281;
  constant INPUT_INDEX_THETA_FIRST   : integer := 283;
  constant INPUT_INDEX_LAST          : integer := 286;

  constant COMMAND_SHAKE_H_VECTOR     : std_logic_vector(63 downto 0) := make_cmd(MODE_SHAKE256, 33, H_STREAM_BYTES);
  constant COMMAND_SHAKE_THETA_STREAM : std_logic_vector(63 downto 0) := make_cmd_stream(MODE_SHAKE256, 33);

  constant ZERO_WORD            : std_logic_vector(63 downto 0) := (others => '0');
  constant DOMAIN_BYTE_01_WORD  : std_logic_vector(63 downto 0) := x"0000000000000001";
  constant S_LAST_WORD_MASK     : std_logic_vector(63 downto 0) := x"000000000000001F";   -- N mod 64 = 5 bits
  constant SPARSE_COUNT         : unsigned(6 downto 0) := to_unsigned(SAMPLE_WEIGHT_R_E, 7);

  function byte_of_word(word : std_logic_vector(63 downto 0); lane : integer) return std_logic_vector is
    variable shifted : unsigned(63 downto 0);
  begin
    shifted := shift_right(unsigned(word), 8 * lane);
    return std_logic_vector(shifted(7 downto 0));
  end function;

  function rm_word_slice(block_bits : std_logic_vector(383 downto 0); word_in_block : integer) return std_logic_vector is
  begin
    case word_in_block is
      when 0      => return block_bits(63 downto 0);
      when 1      => return block_bits(127 downto 64);
      when 2      => return block_bits(191 downto 128);
      when 3      => return block_bits(255 downto 192);
      when 4      => return block_bits(319 downto 256);
      when others => return block_bits(383 downto 320);
    end case;
  end function;

  -- --------------------------------------------------------------------------
  -- Tipos
  -- --------------------------------------------------------------------------
  type main_state_t is (ST_IDLE, ST_LOAD_INPUT, ST_WAIT_H_VECTOR, ST_WAIT_SAMPLING, ST_WAIT_RS_RM_JOIN,
                        ST_WAIT_POLY_MUL, ST_START_SPARSE_XOR, ST_WAIT_SPARSE_XOR,
                        ST_OUTPUT_ADDRESS, ST_OUTPUT_SEND, ST_DONE);
  type sponge_phase_t       is (PHASE_NONE, PHASE_H_VECTOR, PHASE_R2, PHASE_E, PHASE_R1);
  type sponge_feed_state_t  is (FEED_IDLE, FEED_COMMAND, FEED_WORDS);
  type sponge_feed_source_t is (SOURCE_SEED_EK, SOURCE_THETA);
  type rs_rm_state_t        is (RSRM_IDLE, RSRM_PRE_START, RSRM_FEED_MESSAGE, RSRM_CAPTURE_CODEWORD,
                                RSRM_WRITE_CM, RSRM_FLUSH);

  type words4_t  is array (0 to 3)  of std_logic_vector(63 downto 0);
  type words2_t  is array (0 to 1)  of std_logic_vector(63 downto 0);
  type bytes46_t is array (0 to 45) of std_logic_vector(7 downto 0);

  -- --------------------------------------------------------------------------
  -- Estado y valores pequenos con nombre propio
  -- --------------------------------------------------------------------------
  signal main_state           : main_state_t := ST_IDLE;
  signal sponge_output_phase  : sponge_phase_t := PHASE_NONE;
  signal sponge_feed_state    : sponge_feed_state_t := FEED_IDLE;
  signal sponge_feed_source   : sponge_feed_source_t := SOURCE_SEED_EK;
  signal rs_rm_state          : rs_rm_state_t := RSRM_IDLE;

  signal seed_ek_words        : words4_t := (others => (others => '0'));   -- ek, palabras 0..3
  signal message_words        : words2_t := (others => (others => '0'));   -- m (16 B)
  signal theta_words          : words4_t := (others => (others => '0'));   -- theta (32 B)
  signal rs_codeword_bytes    : bytes46_t := (others => (others => '0'));  -- cw en el orden de hqc128.py

  signal input_word_index     : integer range 0 to 287 := 0;
  signal sampler_call_index   : integer range 0 to 2 := 0;                 -- 0: r2, 1: e, 2: r1
  signal sparse_xor_select    : std_logic := '0';                          -- '0': u xor r1 ; '1': v xor e

  -- pulsos de un ciclo
  signal sponge_feed_go, sample_vect_start, sampler_start, poly_mul_start, sparse_xor_start : std_logic := '0';
  signal sponge_abort, rs_rm_encode_go : std_logic := '0';

  -- contadores de ciclos
  signal cycle_counter_running, core_cycle_counter_running : std_logic := '0';
  signal cycle_counter, core_cycle_counter                 : unsigned(31 downto 0) := (others => '0');
  signal cycles_at_results_ready, core_cycles_at_results_ready : unsigned(31 downto 0) := (others => '0');

  -- salida
  signal output_part_index    : integer range 0 to 1 := 0;
  signal output_word_index    : integer range 0 to 276 := 0;
  signal output_ram_address   : unsigned(8 downto 0);
  signal output_last_word_index : integer range 0 to 276;
  signal out_valid_internal   : std_logic;

  -- --------------------------------------------------------------------------
  -- Sponge y alimentador
  -- --------------------------------------------------------------------------
  signal sponge_in_valid, sponge_in_ready, sponge_out_valid, sponge_out_ready : std_logic;
  signal sponge_in_data, sponge_out_data : std_logic_vector(63 downto 0);
  signal sponge_feed_word_index : integer range 0 to 4 := 0;
  signal sponge_feed_command    : std_logic_vector(63 downto 0) := (others => '0');

  -- --------------------------------------------------------------------------
  -- sample_vect, sampler mod y bancos de posiciones (r2, e, r1)
  -- --------------------------------------------------------------------------
  signal sample_vect_din_valid, sample_vect_din_ready, sample_vect_write_enable, sample_vect_done : std_logic;
  signal sample_vect_write_address : unsigned(8 downto 0);
  signal sample_vect_write_data    : std_logic_vector(63 downto 0);

  signal sampler_shake_valid, sampler_shake_ready, sampler_write_enable, sampler_done : std_logic;
  signal sampler_write_address, sampler_read_address : unsigned(6 downto 0);
  signal sampler_write_data, sampler_read_data       : unsigned(14 downto 0);

  signal bank_r2_write_enable, bank_e_write_enable, bank_r1_write_enable : std_logic;
  signal bank_r2_read_address, bank_e_read_address, bank_r1_read_address : unsigned(6 downto 0);
  signal bank_r2_read_data, bank_e_read_data, bank_r1_read_data          : unsigned(14 downto 0);

  -- --------------------------------------------------------------------------
  -- Memorias densas de 64 bits
  -- --------------------------------------------------------------------------
  signal ek_s_ram_write_enable : std_logic;
  signal ek_s_ram_write_address, ek_s_ram_read_address : unsigned(8 downto 0);
  signal ek_s_ram_write_data, ek_s_ram_read_data       : std_logic_vector(63 downto 0);
  signal h_ram_read_address : unsigned(8 downto 0);
  signal h_ram_read_data    : std_logic_vector(63 downto 0);
  signal u_ram_write_enable, v_ram_write_enable : std_logic;
  signal u_ram_write_address, v_ram_write_address, u_ram_read_address, v_ram_read_address : unsigned(8 downto 0);
  signal u_ram_write_data, v_ram_write_data, u_ram_read_data, v_ram_read_data : std_logic_vector(63 downto 0);
  signal cm_ram_write_enable : std_logic := '0';
  signal cm_ram_write_address : unsigned(8 downto 0) := (others => '0');
  signal cm_ram_write_data    : std_logic_vector(63 downto 0) := (others => '0');
  signal cm_ram_read_data     : std_logic_vector(63 downto 0);

  -- --------------------------------------------------------------------------
  -- poly_mul2 (DUAL) y sparse_xor
  -- --------------------------------------------------------------------------
  signal poly_mul_ready, poly_mul_done, poly_mul_result_write_enable : std_logic;
  signal poly_mul_position_address : unsigned(6 downto 0);
  signal poly_mul_dense_address, poly_mul_result_address : unsigned(8 downto 0);
  signal poly_mul_result_a_data, poly_mul_result_b_data : std_logic_vector(63 downto 0);
  signal acc_address_port1, acc_address_port2 : unsigned(9 downto 0);
  signal acc_write_enable_port1, acc_write_enable_port2 : std_logic;
  signal acc_data_in_port1, acc_a_data_in_port2, acc_b_data_in_port2 : std_logic_vector(63 downto 0);
  signal acc_a_data_out_port1, acc_a_data_out_port2, acc_b_data_out_port1, acc_b_data_out_port2 : std_logic_vector(63 downto 0);

  signal sparse_xor_ready, sparse_xor_done, sparse_xor_memory_write_enable : std_logic;
  signal sparse_xor_position_address, sparse_xor_count : unsigned(6 downto 0);
  signal sparse_xor_position_data : unsigned(14 downto 0);
  signal sparse_xor_memory_address : unsigned(8 downto 0);
  signal sparse_xor_memory_data_in, sparse_xor_memory_data_out : std_logic_vector(63 downto 0);

  -- --------------------------------------------------------------------------
  -- Reed-Solomon / Reed-Muller (codificacion de m en paralelo)
  -- --------------------------------------------------------------------------
  signal rs_enc_start_codeword, rs_enc_in_valid, rs_enc_end_codeword, rs_enc_consume : std_logic;
  signal rs_enc_in_symbol, rs_enc_out_symbol : std_logic_vector(7 downto 0);
  signal rs_enc_out_end, rs_enc_error, rs_enc_in_ready, rs_enc_out_start, rs_enc_out_valid : std_logic;
  signal rs_message_index         : integer range 0 to 15 := 0;
  signal rs_capture_symbol_count  : integer range 0 to 46 := 0;
  signal rs_capture_active, rs_capture_finished, rs_rm_finished, rs_error_sticky : std_logic := '0';

  signal rm_enc_data_in      : std_logic_vector(7 downto 0) := (others => '0');
  signal rm_enc_data_out     : std_logic_vector(383 downto 0);
  signal rm_symbol_index     : integer range 0 to 45 := 0;
  signal rm_word_in_symbol   : integer range 0 to 5 := 0;
  signal rm_cm_word_index    : integer range 0 to 276 := 0;
  signal rm_stage_valid_delayed : std_logic := '0';
  signal rm_stage_word_in_symbol_delayed : integer range 0 to 5 := 0;
  signal rm_stage_cm_index_delayed       : integer range 0 to 276 := 0;
  signal rm_flush_counter    : integer range 0 to 3 := 0;

begin

  ---------------------------------------------------------------------------
  -- Instancias
  ---------------------------------------------------------------------------
  u_sponge : entity work.keccak_sponge
    generic map (BIG_ENDIAN_WORDS => false)
    port map (clk => clk, rst => rst, abort => sponge_abort,
              in_valid => sponge_in_valid, in_ready => sponge_in_ready, in_data => sponge_in_data,
              out_valid => sponge_out_valid, out_ready => sponge_out_ready, out_data => sponge_out_data,
              out_last => open);

  u_sample_vect : entity work.sample_vect
    generic map (N => 17669, N_SZ => 2209, ADDR_W => 9)
    port map (clk => clk, rst => rst, start => sample_vect_start,
              din => sponge_out_data, din_valid => sample_vect_din_valid, din_ready => sample_vect_din_ready,
              wr_en => sample_vect_write_enable, wr_addr => sample_vect_write_address, wr_data => sample_vect_write_data,
              sample_done => sample_vect_done);

  u_sampler_mod : entity work.samplefxwtmod
    generic map (N => 17669, WT => SAMPLE_WEIGHT_R_E, SHAKE_BYTE_SWAP => false)
    port map (clk => clk, rst => rst, start => sampler_start,
              shake_din => sponge_out_data, shake_valid => sampler_shake_valid, shake_ready => sampler_shake_ready,
              wr_en => sampler_write_enable, wr_addr => sampler_write_address, wr_data => sampler_write_data,
              rd_addr => sampler_read_address, rd_data => sampler_read_data,
              sample_done => sampler_done);

  u_poly_mul : entity work.poly_mul2
    generic map (N => 17669, DUAL => true, POS_W => 15, PA_W => 7, AW => 9, ACC_AW => 10)
    port map (clk => clk, rst => rst, start => poly_mul_start, n_pos => SPARSE_COUNT,
              ready => poly_mul_ready, done => poly_mul_done,
              pos_addr => poly_mul_position_address, pos_data => bank_r2_read_data,
              dense_addr => poly_mul_dense_address, dense_a_data => h_ram_read_data, dense_b_data => ek_s_ram_read_data,
              acc_addr1 => acc_address_port1, acc_we1 => acc_write_enable_port1, acc_din1 => acc_data_in_port1,
              acc_addr2 => acc_address_port2, acc_we2 => acc_write_enable_port2,
              accA_din2 => acc_a_data_in_port2, accB_din2 => acc_b_data_in_port2,
              accA_dout1 => acc_a_data_out_port1, accB_dout1 => acc_b_data_out_port1,
              accA_dout2 => acc_a_data_out_port2, accB_dout2 => acc_b_data_out_port2,
              res_we => poly_mul_result_write_enable, res_addr => poly_mul_result_address,
              res_a_data => poly_mul_result_a_data, res_b_data => poly_mul_result_b_data);

  u_sparse_xor : entity work.sparse_xor
    generic map (POS_W => 15, PA_W => 7, AW => 9)
    port map (clk => clk, rst => rst, start => sparse_xor_start, n_pos => sparse_xor_count,
              ready => sparse_xor_ready, done => sparse_xor_done,
              pos_addr => sparse_xor_position_address, pos_data => sparse_xor_position_data,
              mem_we => sparse_xor_memory_write_enable, mem_addr => sparse_xor_memory_address,
              mem_din => sparse_xor_memory_data_in, mem_dout => sparse_xor_memory_data_out);

  u_rs_encoder : entity work.rs_encoder
    port map (clk => clk, rst => rst,
              i_end_codeword => rs_enc_end_codeword, i_start_codeword => rs_enc_start_codeword,
              i_valid => rs_enc_in_valid, i_consume => rs_enc_consume, i_symbol => rs_enc_in_symbol,
              o_end_codeword => rs_enc_out_end, o_error => rs_enc_error, o_in_ready => rs_enc_in_ready,
              o_start_codeword => rs_enc_out_start, o_valid => rs_enc_out_valid, o_symbol => rs_enc_out_symbol);

  u_rm_encoder : entity work.rm_encoder
    generic map (m => 7, rep => 3, generator_matrix_01 => RM_GEN_01)
    port map (data_in => rm_enc_data_in, data_out => rm_enc_data_out);

  -- bancos de posiciones
  u_bank_r2 : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => bank_r2_write_enable, wr_addr => sampler_write_address, din => sampler_write_data,
              rd_addr => bank_r2_read_address, dout => bank_r2_read_data);
  u_bank_e : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => bank_e_write_enable, wr_addr => sampler_write_address, din => sampler_write_data,
              rd_addr => bank_e_read_address, dout => bank_e_read_data);
  u_bank_r1 : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => bank_r1_write_enable, wr_addr => sampler_write_address, din => sampler_write_data,
              rd_addr => bank_r1_read_address, dout => bank_r1_read_data);

  -- memorias densas (277 palabras): s (de ek), h (sample_vect), u y v (resultados de poly_mul2)
  u_ek_s_ram : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => ek_s_ram_write_enable, waddr => ek_s_ram_write_address, wdata => ek_s_ram_write_data,
              raddr => ek_s_ram_read_address, rdata => ek_s_ram_read_data);
  u_h_ram : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => sample_vect_write_enable, waddr => sample_vect_write_address, wdata => sample_vect_write_data,
              raddr => h_ram_read_address, rdata => h_ram_read_data);
  u_u_ram : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => u_ram_write_enable, waddr => u_ram_write_address, wdata => u_ram_write_data,
              raddr => u_ram_read_address, rdata => u_ram_read_data);
  u_v_ram : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => v_ram_write_enable, waddr => v_ram_write_address, wdata => v_ram_write_data,
              raddr => v_ram_read_address, rdata => v_ram_read_data);
  u_cm_ram : entity work.ram64_sdp                       -- cm = RM(RS(m)): 276 palabras
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => cm_ram_write_enable, waddr => cm_ram_write_address, wdata => cm_ram_write_data,
              raddr => output_ram_address, rdata => cm_ram_read_data);

  -- acumuladores de poly_mul2 (uno por canal)
  u_acc_a : entity work.ram64_tdp
    generic map (DEPTH => 554, ADDR_W => 10)
    port map (clk => clk,
              we_1 => acc_write_enable_port1, addr_1 => acc_address_port1, din_1 => acc_data_in_port1, dout_1 => acc_a_data_out_port1,
              we_2 => acc_write_enable_port2, addr_2 => acc_address_port2, din_2 => acc_a_data_in_port2, dout_2 => acc_a_data_out_port2);
  u_acc_b : entity work.ram64_tdp
    generic map (DEPTH => 554, ADDR_W => 10)
    port map (clk => clk,
              we_1 => acc_write_enable_port1, addr_1 => acc_address_port1, din_1 => acc_data_in_port1, dout_1 => acc_b_data_out_port1,
              we_2 => acc_write_enable_port2, addr_2 => acc_address_port2, din_2 => acc_b_data_in_port2, dout_2 => acc_b_data_out_port2);

  ---------------------------------------------------------------------------
  -- Salidas simples
  ---------------------------------------------------------------------------
  ready       <= '1' when main_state = ST_IDLE else '0';
  in_ready    <= '1' when main_state = ST_LOAD_INPUT else '0';
  done        <= '1' when main_state = ST_DONE else '0';
  cycles      <= cycles_at_results_ready;
  cycles_core <= core_cycles_at_results_ready;
  err         <= rs_error_sticky;
  dbg_state   <= std_logic_vector(to_unsigned(main_state_t'pos(main_state), 4));

  ---------------------------------------------------------------------------
  -- Ruteo segun la fase de la salida del sponge y bancos de posiciones
  ---------------------------------------------------------------------------
  sponge_out_ready <= sample_vect_din_ready when sponge_output_phase = PHASE_H_VECTOR else
                      sampler_shake_ready   when (sponge_output_phase = PHASE_R2 or
                                                  sponge_output_phase = PHASE_E  or
                                                  sponge_output_phase = PHASE_R1) else
                      '0';
  sample_vect_din_valid <= sponge_out_valid when sponge_output_phase = PHASE_H_VECTOR else '0';
  sampler_shake_valid   <= sponge_out_valid when (sponge_output_phase = PHASE_R2 or
                                                  sponge_output_phase = PHASE_E  or
                                                  sponge_output_phase = PHASE_R1) else '0';

  bank_r2_write_enable <= sampler_write_enable when sponge_output_phase = PHASE_R2 else '0';
  bank_e_write_enable  <= sampler_write_enable when sponge_output_phase = PHASE_E  else '0';
  bank_r1_write_enable <= sampler_write_enable when sponge_output_phase = PHASE_R1 else '0';

  -- cada banco lo lee el sampler (limpieza del bitmap) mientras lo escribe, y despues poly_mul2 / sparse_xor
  bank_r2_read_address <= sampler_read_address when sponge_output_phase = PHASE_R2 else poly_mul_position_address;
  bank_e_read_address  <= sampler_read_address when sponge_output_phase = PHASE_E  else sparse_xor_position_address;
  bank_r1_read_address <= sampler_read_address when sponge_output_phase = PHASE_R1 else sparse_xor_position_address;

  sampler_read_data <= bank_r2_read_data when sponge_output_phase = PHASE_R2 else
                       bank_e_read_data  when sponge_output_phase = PHASE_E  else
                       bank_r1_read_data;

  sparse_xor_position_data   <= bank_r1_read_data when sparse_xor_select = '0' else bank_e_read_data;
  sparse_xor_memory_data_out <= u_ram_read_data    when sparse_xor_select = '0' else v_ram_read_data;

  ---------------------------------------------------------------------------
  -- Memorias densas
  --   s : escribe la ingesta ; lee poly_mul2 (canal B)
  --   h : escribe sample_vect ; lee poly_mul2 (canal A)
  --   u : escribe poly_mul2 (canal A) o sparse_xor (r1) ; lee sparse_xor o la salida
  --   v : escribe poly_mul2 (canal B) o sparse_xor (e)  ; lee sparse_xor o la salida
  ---------------------------------------------------------------------------
  ek_s_ram_write_enable  <= '1' when (main_state = ST_LOAD_INPUT and in_valid = '1' and
                                      input_word_index >= INPUT_INDEX_EK_S_FIRST and
                                      input_word_index <= INPUT_INDEX_EK_S_LAST) else '0';
  ek_s_ram_write_address <= to_unsigned(input_word_index - INPUT_INDEX_EK_S_FIRST, 9)
                              when (input_word_index >= INPUT_INDEX_EK_S_FIRST and
                                    input_word_index <= INPUT_INDEX_EK_S_LAST) else (others => '0');
  ek_s_ram_write_data    <= (in_data and S_LAST_WORD_MASK) when input_word_index = INPUT_INDEX_EK_S_LAST else in_data;
  ek_s_ram_read_address  <= poly_mul_dense_address;
  h_ram_read_address     <= poly_mul_dense_address;

  u_ram_write_enable  <= poly_mul_result_write_enable when main_state = ST_WAIT_POLY_MUL else
                         sparse_xor_memory_write_enable when (main_state = ST_WAIT_SPARSE_XOR and sparse_xor_select = '0') else '0';
  u_ram_write_address <= poly_mul_result_address when main_state = ST_WAIT_POLY_MUL else sparse_xor_memory_address;
  u_ram_write_data    <= poly_mul_result_a_data  when main_state = ST_WAIT_POLY_MUL else sparse_xor_memory_data_in;
  u_ram_read_address  <= sparse_xor_memory_address when main_state = ST_WAIT_SPARSE_XOR else output_ram_address;

  v_ram_write_enable  <= poly_mul_result_write_enable when main_state = ST_WAIT_POLY_MUL else
                         sparse_xor_memory_write_enable when (main_state = ST_WAIT_SPARSE_XOR and sparse_xor_select = '1') else '0';
  v_ram_write_address <= poly_mul_result_address when main_state = ST_WAIT_POLY_MUL else sparse_xor_memory_address;
  v_ram_write_data    <= poly_mul_result_b_data  when main_state = ST_WAIT_POLY_MUL else sparse_xor_memory_data_in;
  v_ram_read_address  <= sparse_xor_memory_address when main_state = ST_WAIT_SPARSE_XOR else output_ram_address;

  sparse_xor_count <= SPARSE_COUNT;

  ---------------------------------------------------------------------------
  -- Alimentador del sponge: comando + 5 palabras (seed || 01)  o  (theta || 01)
  ---------------------------------------------------------------------------
  sponge_in_valid <= '1' when (sponge_feed_state = FEED_COMMAND or sponge_feed_state = FEED_WORDS) else '0';

  sponge_feed_data_proc : process(sponge_feed_state, sponge_feed_command, sponge_feed_source,
                                  sponge_feed_word_index, seed_ek_words, theta_words)
  begin
    if sponge_feed_state = FEED_COMMAND then
      sponge_in_data <= sponge_feed_command;
    elsif sponge_feed_word_index = 4 then
      sponge_in_data <= DOMAIN_BYTE_01_WORD;
    elsif sponge_feed_source = SOURCE_SEED_EK then
      sponge_in_data <= seed_ek_words(sponge_feed_word_index);
    else
      sponge_in_data <= theta_words(sponge_feed_word_index);
    end if;
  end process;

  sponge_feed_fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        sponge_feed_state      <= FEED_IDLE;
        sponge_feed_word_index <= 0;
      else
        case sponge_feed_state is
          when FEED_IDLE =>
            if sponge_feed_go = '1' then
              sponge_feed_state <= FEED_COMMAND;
            end if;
          when FEED_COMMAND =>
            if sponge_in_ready = '1' then
              sponge_feed_word_index <= 0;
              sponge_feed_state      <= FEED_WORDS;
            end if;
          when FEED_WORDS =>
            if sponge_in_ready = '1' then
              if sponge_feed_word_index = 4 then
                sponge_feed_state <= FEED_IDLE;
              else
                sponge_feed_word_index <= sponge_feed_word_index + 1;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Codificador RS + RM (motor independiente: rs_rm_encode_go -> rs_rm_finished)
  --   RS : entra m[15] .. m[0] (un simbolo por ciclo); salen los 46 simbolos -> rs_codeword_bytes
  --   RM : por cada simbolo, 6 palabras de 64 bits a la RAM cm (cm[6*i + t])
  ---------------------------------------------------------------------------
  rs_enc_consume        <= '1';
  rs_enc_in_valid       <= '1' when rs_rm_state = RSRM_FEED_MESSAGE else '0';
  rs_enc_end_codeword   <= '1' when (rs_rm_state = RSRM_FEED_MESSAGE and rs_message_index = 15) else '0';
  rs_enc_start_codeword <= '1' when ((RS_START_OVERLAP and rs_rm_state = RSRM_FEED_MESSAGE and rs_message_index = 0) or
                                     ((not RS_START_OVERLAP) and rs_rm_state = RSRM_PRE_START)) else '0';
  rs_enc_in_symbol      <= byte_of_word(message_words((15 - rs_message_index) / 8), (15 - rs_message_index) mod 8);   -- m[15 - k]

  rs_rm_encode_fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rs_rm_state          <= RSRM_IDLE;
        rs_message_index     <= 0;
        rs_capture_symbol_count <= 0;
        rs_capture_active    <= '0';
        rs_capture_finished  <= '0';
        rs_rm_finished       <= '0';
        rs_error_sticky      <= '0';
        rm_stage_valid_delayed <= '0';
        cm_ram_write_enable  <= '0';
      else
        -- etapa B del pipeline RM: la salida combinacional del RM (sobre rm_enc_data_in) pasa a la RAM cm
        rm_stage_valid_delayed <= '0';
        cm_ram_write_enable    <= rm_stage_valid_delayed;
        cm_ram_write_address   <= to_unsigned(rm_stage_cm_index_delayed, 9);
        cm_ram_write_data      <= rm_word_slice(rm_enc_data_out, rm_stage_word_in_symbol_delayed);

        if start = '1' and main_state = ST_IDLE then
          rs_error_sticky <= '0';
        end if;
        if rs_enc_error = '1' then
          rs_error_sticky <= '1';
        end if;

        -- captura de los 46 simbolos emitidos por el rs_encoder
        if rs_enc_out_start = '1' then
          if RS_OUT_REVERSED then
            rs_codeword_bytes(45) <= rs_enc_out_symbol;
          else
            rs_codeword_bytes(0) <= rs_enc_out_symbol;
          end if;
          rs_capture_symbol_count <= 1;
          rs_capture_active       <= '1';
        elsif rs_capture_active = '1' and rs_enc_out_valid = '1' then
          if rs_capture_symbol_count <= 45 then
            if RS_OUT_REVERSED then
              rs_codeword_bytes(45 - rs_capture_symbol_count) <= rs_enc_out_symbol;
            else
              rs_codeword_bytes(rs_capture_symbol_count) <= rs_enc_out_symbol;
            end if;
          else
            rs_error_sticky <= '1';                       -- mas de 46 simbolos
          end if;
          if rs_enc_out_end = '1' then
            rs_capture_active   <= '0';
            rs_capture_finished <= '1';
            if rs_capture_symbol_count /= 45 then
              rs_error_sticky <= '1';                     -- el codeword no tuvo 46 simbolos
            end if;
          elsif rs_capture_symbol_count < 46 then
            rs_capture_symbol_count <= rs_capture_symbol_count + 1;
          end if;
        end if;

        case rs_rm_state is

          when RSRM_IDLE =>
            if rs_rm_encode_go = '1' then
              rs_rm_finished      <= '0';
              rs_capture_finished <= '0';
              rs_message_index    <= 0;
              if RS_START_OVERLAP then
                rs_rm_state <= RSRM_FEED_MESSAGE;
              else
                rs_rm_state <= RSRM_PRE_START;
              end if;
            end if;

          when RSRM_PRE_START =>                          -- solo si i_start_codeword va un ciclo antes
            rs_rm_state <= RSRM_FEED_MESSAGE;

          when RSRM_FEED_MESSAGE =>                       -- rs_enc_in_valid = '1': un simbolo por ciclo
            if rs_message_index = 15 then
              rs_rm_state <= RSRM_CAPTURE_CODEWORD;
            else
              rs_message_index <= rs_message_index + 1;
            end if;

          when RSRM_CAPTURE_CODEWORD =>                   -- esperar o_end_codeword (ultimo simbolo capturado)
            if rs_capture_finished = '1' then
              rs_capture_finished <= '0';
              rm_symbol_index     <= 0;
              rm_word_in_symbol   <= 0;
              rm_cm_word_index    <= 0;
              rs_rm_state         <= RSRM_WRITE_CM;
            end if;

          when RSRM_WRITE_CM =>                           -- etapa A: 1 palabra de cm por ciclo
            rm_enc_data_in                  <= rs_codeword_bytes(rm_symbol_index);
            rm_stage_word_in_symbol_delayed <= rm_word_in_symbol;
            rm_stage_cm_index_delayed       <= rm_cm_word_index;
            rm_stage_valid_delayed          <= '1';
            rm_cm_word_index                <= rm_cm_word_index + 1;
            if rm_word_in_symbol = 5 then
              rm_word_in_symbol <= 0;
              if rm_symbol_index = 45 then
                rm_flush_counter <= 0;
                rs_rm_state      <= RSRM_FLUSH;
              else
                rm_symbol_index <= rm_symbol_index + 1;
              end if;
            else
              rm_word_in_symbol <= rm_word_in_symbol + 1;
            end if;

          when RSRM_FLUSH =>                              -- vaciar el pipeline (3 ciclos) y avisar
            if rm_flush_counter = 2 then
              rs_rm_finished <= '1';
              rs_rm_state    <= RSRM_IDLE;
            else
              rm_flush_counter <= rm_flush_counter + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Etapa de salida: parte 0 = u (277 palabras), parte 1 = v xor cm (276 palabras)
  ---------------------------------------------------------------------------
  output_ram_address     <= to_unsigned(output_word_index, 9);
  output_last_word_index <= VECTOR_WORDS - 1 when output_part_index = 0 else V_OUTPUT_WORDS - 1;

  out_data <= u_ram_read_data when output_part_index = 0 else (v_ram_read_data xor cm_ram_read_data);

  out_valid_internal <= '1' when main_state = ST_OUTPUT_SEND else '0';
  out_valid          <= out_valid_internal;
  out_last           <= '1' when (main_state = ST_OUTPUT_SEND and output_word_index = output_last_word_index) else '0';
  out_part           <= '0' when output_part_index = 0 else '1';

  ---------------------------------------------------------------------------
  -- FSM principal
  ---------------------------------------------------------------------------
  main_fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        main_state          <= ST_IDLE;
        sponge_output_phase <= PHASE_NONE;
        input_word_index    <= 0;
        sampler_call_index  <= 0;
        sparse_xor_select   <= '0';
        output_part_index   <= 0;
        output_word_index   <= 0;
        cycle_counter_running      <= '0';
        core_cycle_counter_running <= '0';
        sponge_feed_go      <= '0';
        sample_vect_start   <= '0';
        sampler_start       <= '0';
        poly_mul_start      <= '0';
        sparse_xor_start    <= '0';
        sponge_abort        <= '0';
        rs_rm_encode_go     <= '0';
      else
        -- pulsos: por defecto a 0; valen '1' durante UN ciclo cuando se asignan
        sponge_feed_go    <= '0';
        sample_vect_start <= '0';
        sampler_start     <= '0';
        poly_mul_start    <= '0';
        sparse_xor_start  <= '0';
        sponge_abort      <= '0';
        rs_rm_encode_go   <= '0';

        if cycle_counter_running = '1' then
          cycle_counter <= cycle_counter + 1;
        end if;
        if core_cycle_counter_running = '1' then
          core_cycle_counter <= core_cycle_counter + 1;
        end if;

        case main_state is

          when ST_IDLE =>
            if start = '1' then
              input_word_index      <= 0;
              cycle_counter         <= (others => '0');
              cycle_counter_running <= '1';
              main_state            <= ST_LOAD_INPUT;
            end if;

          -- ingesta: 0..3 seed_ek | 4..280 s (RAM s, combinacional) | 281..282 m | 283..286 theta
          when ST_LOAD_INPUT =>                                -- in_ready = '1'
            if in_valid = '1' then
              if input_word_index < INPUT_INDEX_EK_S_FIRST then
                seed_ek_words(input_word_index) <= in_data;
              elsif input_word_index <= INPUT_INDEX_EK_S_LAST then
                null;                                          -- la escribe la RAM s (ek_s_ram_write_enable)
              elsif input_word_index < INPUT_INDEX_THETA_FIRST then
                message_words(input_word_index - INPUT_INDEX_MESSAGE_FIRST) <= in_data;
              else
                theta_words(input_word_index - INPUT_INDEX_THETA_FIRST) <= in_data;
              end if;
              if input_word_index = INPUT_INDEX_LAST then
                -- todo recibido: RS/RM en paralelo y SHAKE256(seed_ek||01) -> h
                rs_rm_encode_go            <= '1';
                sponge_feed_source         <= SOURCE_SEED_EK;
                sponge_feed_command        <= COMMAND_SHAKE_H_VECTOR;
                sponge_feed_go             <= '1';
                sample_vect_start          <= '1';
                sponge_output_phase        <= PHASE_H_VECTOR;
                core_cycle_counter         <= (others => '0');
                core_cycle_counter_running <= '1';
                main_state                 <= ST_WAIT_H_VECTOR;
              else
                input_word_index <= input_word_index + 1;
              end if;
            end if;

          when ST_WAIT_H_VECTOR =>
            if sample_vect_done = '1' then
              -- h listo (consumio exactamente 277 palabras): SHAKE256(theta||01) sin limite -> r2, e, r1
              sponge_feed_source  <= SOURCE_THETA;
              sponge_feed_command <= COMMAND_SHAKE_THETA_STREAM;
              sponge_feed_go      <= '1';
              sampler_start       <= '1';
              sampler_call_index  <= 0;
              sponge_output_phase <= PHASE_R2;
              main_state          <= ST_WAIT_SAMPLING;
            end if;

          when ST_WAIT_SAMPLING =>                             -- tres llamadas seguidas al sampler: r2, e, r1
            if sampler_done = '1' then
              if sampler_call_index = 2 then
                sponge_abort        <= '1';                    -- r1 listo: cortar el flujo del sponge
                sponge_output_phase <= PHASE_NONE;
                main_state          <= ST_WAIT_RS_RM_JOIN;
              else
                sampler_call_index <= sampler_call_index + 1;
                sampler_start      <= '1';
                if sampler_call_index = 0 then
                  sponge_output_phase <= PHASE_E;
                else
                  sponge_output_phase <= PHASE_R1;
                end if;
              end if;
            end if;

          when ST_WAIT_RS_RM_JOIN =>                           -- RS/RM listo y poly_mul2 libre
            if rs_rm_finished = '1' and poly_mul_ready = '1' then
              poly_mul_start <= '1';
              main_state     <= ST_WAIT_POLY_MUL;
            end if;

          when ST_WAIT_POLY_MUL =>                             -- u = r2*h  y  v = r2*s
            if poly_mul_done = '1' then
              sparse_xor_select <= '0';
              main_state        <= ST_START_SPARSE_XOR;
            end if;

          when ST_START_SPARSE_XOR =>                          -- select '0': u xor r1 ; '1': v xor e
            if sparse_xor_ready = '1' then
              sparse_xor_start <= '1';
              main_state       <= ST_WAIT_SPARSE_XOR;
            end if;

          when ST_WAIT_SPARSE_XOR =>
            if sparse_xor_done = '1' then
              if sparse_xor_select = '0' then
                sparse_xor_select <= '1';
                main_state        <= ST_START_SPARSE_XOR;
              else
                cycle_counter_running        <= '0';
                core_cycle_counter_running   <= '0';
                cycles_at_results_ready      <= cycle_counter;
                core_cycles_at_results_ready <= core_cycle_counter;
                output_part_index            <= 0;
                output_word_index            <= 0;
                main_state                   <= ST_OUTPUT_ADDRESS;
              end if;
            end if;

          when ST_OUTPUT_ADDRESS =>                            -- direccion presentada; dato valido en ST_OUTPUT_SEND
            main_state <= ST_OUTPUT_SEND;

          when ST_OUTPUT_SEND =>                               -- out_valid = '1'
            if out_ready = '1' then
              if output_word_index = output_last_word_index then
                if output_part_index = 1 then
                  main_state <= ST_DONE;
                else
                  output_part_index <= 1;
                  output_word_index <= 0;
                  main_state        <= ST_OUTPUT_ADDRESS;
                end if;
              else
                output_word_index <= output_word_index + 1;
                main_state        <= ST_OUTPUT_ADDRESS;
              end if;
            end if;

          when ST_DONE =>
            sponge_output_phase <= PHASE_NONE;
            main_state          <= ST_IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;
