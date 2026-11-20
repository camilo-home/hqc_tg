-- ============================================================================
-- hqc_decaps : HQC-128 KEM.Decaps(dk, ct) -> ss
--
--   entrada dk  (dk_valid/dk_ready/dk_data), 291 palabras de 64 bits = EXACTAMENTE la salida del keygen:
--                 0..280   ek  (seed_ek 32 B || s 2209 B; la palabra 280 solo lleva 1 byte)
--                 281..284 seed_dk (32 B)     285..286 sigma (16 B)     287..290 seed_kem (32 B, se ignora)
--   entrada ct  (ct_valid/ct_ready/ct_data), 555 palabras, partes alineadas a palabra, orden u | v | salt:
--                 0..276   u (2209 B; la palabra 276 solo lleva 1 byte)
--                 277..552 v (2208 B)         553..554 salt (16 B)
--   dk y ct se ingieren a la vez (puertos independientes). start (pulso) solo con ready='1'.
--   salida  : ss (32 B) en 4 palabras por out_valid/out_ready; out_last en la ultima. done = pulso al terminar.
--   Bytes en palabras: byte 0 en los bits [7:0] (igual que el sponge).
--
-- Reparto de trabajo
--   capa KEM (este modulo, un unico sponge propio, una operacion a la vez):
--       tmp_h = SHA3-256(ek||01) | y = rej(SHAKE256(seed_dk||01)) | (kk', theta') = SHA3-512(tmp_h||m'||salt||00)
--       k_rej = SHA3-256(tmp_h||sigma||ct||03)
--   capa PKE (hqc_encrypt, con su propio sponge): (u', v') = Encrypt(ek, m', theta')
--
-- Secuencia
--   ST_INGEST            dk: las 281 palabras de ek se REPARTEN a la vez (tee) al sponge (hash de ek) y a la entrada de
--                        hqc_encrypt, que las guarda; seed_dk y sigma a registros. ct: u -> RAM, v -> RAM, salt -> registros.
--                        La salida del hash (tmp_h) se captura sola cuando el sponge termina.
--   ST_SAMPLE_Y          SHAKE256(seed_dk||01), sin limite -> sampler rej -> y (66 posiciones); abort
--   ST_START/WAIT_POLY_MUL  res = y * u   (poly_mul2, DUAL=false)
--   ST_DECODE_M_PRIME    cm = v xor res (al vuelo), bloques 45..0 -> rm_decoder -> 46 simbolos -> rs_decoder -> m'
--   ST_HASH_G            SHA3-512(tmp_h||m'||salt||00) -> kk' (4 palabras) y theta' (4 palabras)
--   ST_SEND_ENCRYPT_INPUT  m' (2 palabras) y theta' (4) a hqc_encrypt (a continuacion de ek)
--   ST_RE_ENCRYPT        en paralelo: (a) k_rej: hash con realineador de bytes (ct = u||v||salt como bytes continuos)
--                        (b) comparacion de (u', v') con el ct recibido, palabra a palabra y sin salida anticipada.
--                        La comparacion espera a que k_rej termine de leer las RAM de ct (se comparten).
--   ST_OUTPUT_SS         ss = match ? kk' : k_rej
--
-- cycles      : ciclos desde start hasta tener ss listo (incluye la ingesta)
-- cycles_core : igual pero desde el fin de la ingesta
-- match       : '1' si el re-cifrado coincidio
-- err         : pegajoso: error de rs_decoder / rs_encoder (con un ct invalido es normal; ss = k_rej sigue siendo correcto)
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.keccak_sponge_pkg.all;

entity hqc_decaps is
  generic(
    RM_GEN_01                      : boolean := false;  -- generator_matrix_01 de rm_encoder y rm_decoder (HQC: false); mismo valor en ambos
    RS_ENC_OUT_REVERSED            : boolean := true;   -- rs_encoder (dentro de hqc_encrypt)
    RS_ENC_START_OVERLAP           : boolean := true;
    RS_DEC_START_OVERLAP           : boolean := true;   -- rs_decoder: i_start_codeword coincide con el 1er simbolo
    RS_DEC_FIRST_CONSECUTIVE_ROOT  : natural := 1;      -- raices alpha^1 .. alpha^30
    RS_DEC_PRIMITIVE_POLYNOMIAL    : natural := 285     -- 0x11D
  );
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;

    start : in  std_logic;        -- pulso, solo con ready='1'
    ready : out std_logic;
    done  : out std_logic;        -- pulso al terminar de entregar ss

    dk_valid : in  std_logic;
    dk_ready : out std_logic;
    dk_data  : in  std_logic_vector(63 downto 0);

    ct_valid : in  std_logic;
    ct_ready : out std_logic;
    ct_data  : in  std_logic_vector(63 downto 0);

    out_valid : out std_logic;
    out_ready : in  std_logic;
    out_data  : out std_logic_vector(63 downto 0);
    out_last  : out std_logic;

    match       : out std_logic;
    err         : out std_logic;
    cycles      : out unsigned(31 downto 0);
    cycles_core : out unsigned(31 downto 0);
    dbg_state   : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of hqc_decaps is

  -- --------------------------------------------------------------------------
  -- Constantes
  -- --------------------------------------------------------------------------
  constant DK_EK_WORD_COUNT        : integer := 281;
  constant DK_WORD_COUNT           : integer := 291;
  constant DK_INDEX_EK_LAST        : integer := 280;
  constant DK_INDEX_SEED_DK_FIRST  : integer := 281;
  constant DK_INDEX_SIGMA_FIRST    : integer := 285;

  constant CT_WORD_COUNT           : integer := 555;
  constant CT_INDEX_U_LAST         : integer := 276;
  constant CT_INDEX_V_FIRST        : integer := 277;
  constant CT_INDEX_SALT_FIRST     : integer := 553;

  constant COMMAND_SHA3_256_EK       : std_logic_vector(63 downto 0) := make_cmd(MODE_SHA3_256, 2242, 0);
  constant COMMAND_SHAKE_Y_STREAM    : std_logic_vector(63 downto 0) := make_cmd_stream(MODE_SHAKE256, 33);
  constant COMMAND_SHA3_512_G        : std_logic_vector(63 downto 0) := make_cmd(MODE_SHA3_512, 65, 0);
  constant COMMAND_SHA3_256_K_REJECT : std_logic_vector(63 downto 0) := make_cmd(MODE_SHA3_256, 4482, 0);

  constant ZERO_WORD               : std_logic_vector(63 downto 0) := (others => '0');
  constant DOMAIN_BYTE_01_WORD     : std_logic_vector(63 downto 0) := x"0000000000000001";
  constant DOMAIN_BYTE_03_WORD     : std_logic_vector(63 downto 0) := x"0000000000000003";
  constant U_LAST_WORD_MASK        : std_logic_vector(63 downto 0) := x"000000000000001F";   -- N mod 64 = 5 bits
  constant LOW_BYTE_MASK           : std_logic_vector(63 downto 0) := x"00000000000000FF";
  constant EK_HASH_DOMAIN_BYTE_01_IN_LAST_WORD : std_logic_vector(63 downto 0) := x"0000000000000100";
  constant Y_SPARSE_COUNT          : unsigned(6 downto 0) := to_unsigned(66, 7);

  -- --------------------------------------------------------------------------
  -- Tipos
  -- --------------------------------------------------------------------------
  type main_state_t is (ST_IDLE, ST_INGEST, ST_SAMPLE_Y, ST_START_POLY_MUL, ST_WAIT_POLY_MUL, ST_DECODE_M_PRIME,
                        ST_HASH_G, ST_SEND_ENCRYPT_INPUT, ST_RE_ENCRYPT, ST_OUTPUT_SS, ST_DONE);
  type reg_feed_state_t  is (REGFEED_IDLE, REGFEED_COMMAND, REGFEED_WORDS);
  type reg_feed_source_t is (SOURCE_SEED_DK, SOURCE_G_MESSAGE);
  type k_reject_feed_state_t is (KREJ_IDLE, KREJ_COMMAND, KREJ_SET_ADDRESS, KREJ_WAIT_RAM, KREJ_PUSH_CHUNK,
                                 KREJ_SEND_WORD, KREJ_FLUSH);
  type rm_block_state_t  is (RMB_IDLE, RMB_FETCH, RMB_PUSH, RMB_END);
  type rs_decode_state_t is (RSD_IDLE, RSD_WAIT_SYMBOLS, RSD_PRE_START, RSD_FEED, RSD_CAPTURE);

  type words4_t  is array (0 to 3)  of std_logic_vector(63 downto 0);
  type words2_t  is array (0 to 1)  of std_logic_vector(63 downto 0);
  type bytes46_t is array (0 to 45) of std_logic_vector(7 downto 0);
  type bytes16_t is array (0 to 15) of std_logic_vector(7 downto 0);

  -- palabra 0 o 1 de m': bytes 8w .. 8w+7, el byte 8w en los bits [7:0]
  function pack_m_prime_word(bytes_in : bytes16_t; word_index : integer) return std_logic_vector is
    variable packed : std_logic_vector(63 downto 0);
  begin
    for lane in 0 to 7 loop
      packed(8*lane + 7 downto 8*lane) := bytes_in(8*word_index + lane);
    end loop;
    return packed;
  end function;

  function word_of_tmp_h(tmp_h_in : words4_t; word_index : integer) return std_logic_vector is
  begin
    return tmp_h_in(word_index mod 4);
  end function;

  -- trozos del mensaje de k_rej: 0 tmp_h(4)  1 sigma(2)  2 u(277: 276 de 8 B y 1 de 1 B)  3 v(276)  4 salt(2)  5 byte 03 (1)
  function k_reject_segment_length(segment_index : integer) return integer is
  begin
    case segment_index is
      when 0      => return 4;
      when 1      => return 2;
      when 2      => return 277;
      when 3      => return 276;
      when 4      => return 2;
      when others => return 1;
    end case;
  end function;

  -- --------------------------------------------------------------------------
  -- Estado y valores pequenos con nombre propio
  -- --------------------------------------------------------------------------
  signal main_state               : main_state_t := ST_IDLE;
  signal reg_feed_state           : reg_feed_state_t := REGFEED_IDLE;
  signal reg_feed_source          : reg_feed_source_t := SOURCE_SEED_DK;
  signal k_reject_feed_state      : k_reject_feed_state_t := KREJ_IDLE;
  signal rm_block_state           : rm_block_state_t := RMB_IDLE;
  signal rs_decode_state          : rs_decode_state_t := RSD_IDLE;

  signal seed_dk_words            : words4_t := (others => (others => '0'));
  signal sigma_words              : words2_t := (others => (others => '0'));
  signal salt_words               : words2_t := (others => (others => '0'));
  signal tmp_h_words              : words4_t := (others => (others => '0'));   -- SHA3-256(ek||01)
  signal kk_prime_words           : words4_t := (others => (others => '0'));   -- kk' = secreto si el re-cifrado coincide
  signal theta_prime_words        : words4_t := (others => (others => '0'));
  signal k_reject_words           : words4_t := (others => (others => '0'));   -- k_rej = secreto si no coincide
  signal m_prime_bytes            : bytes16_t := (others => (others => '0'));  -- m' (byte j = m'[j])
  signal rs_decoder_input_bytes   : bytes46_t := (others => (others => '0'));  -- simbolos del RM en orden de llegada (cw[45]..cw[0])
  signal u_last_byte_raw          : std_logic_vector(7 downto 0) := (others => '0');   -- byte 2208 de u tal cual llego

  -- contadores
  signal dk_word_index            : integer range 0 to DK_WORD_COUNT := 0;
  signal ct_word_index            : integer range 0 to CT_WORD_COUNT := 0;
  signal inject_word_index        : integer range 0 to 5 := 0;
  signal kem_sponge_capture_count : integer range 0 to 8 := 0;
  signal ss_output_word_index     : integer range 0 to 3 := 0;
  signal ek_hash_command_pending  : std_logic := '0';
  signal encrypt_done_latched     : std_logic := '0';

  -- pulsos de un ciclo
  signal encrypt_start, y_sampler_start, reg_feed_go, k_reject_feed_go, poly_mul_start, kem_sponge_abort, decode_go : std_logic := '0';

  -- contadores de ciclos
  signal cycle_counter_running, core_cycle_counter_running : std_logic := '0';
  signal cycle_counter, core_cycle_counter, cycles_at_ss_ready, core_cycles_at_ss_ready : unsigned(31 downto 0) := (others => '0');

  signal reset_n_for_rm_decoder : std_logic;
  signal dk_ready_internal, ct_ready_internal : std_logic;

  -- --------------------------------------------------------------------------
  -- hqc_encrypt (re-cifrado)
  -- --------------------------------------------------------------------------
  signal encrypt_ready, encrypt_done, encrypt_error : std_logic;
  signal encrypt_in_valid, encrypt_in_ready : std_logic;
  signal encrypt_in_data, encrypt_inject_word : std_logic_vector(63 downto 0);
  signal encrypt_out_valid, encrypt_out_ready_internal, encrypt_out_last, encrypt_out_part : std_logic;
  signal encrypt_out_data : std_logic_vector(63 downto 0);

  -- --------------------------------------------------------------------------
  -- sponge propio de la capa KEM
  -- --------------------------------------------------------------------------
  signal kem_sponge_in_valid, kem_sponge_in_ready, kem_sponge_out_valid, kem_sponge_out_ready : std_logic;
  signal kem_sponge_in_data, kem_sponge_out_data : std_logic_vector(63 downto 0);

  -- tee de ek hacia el sponge y hacia hqc_encrypt
  signal ek_tee_active : std_logic;
  signal ek_word_for_sponge_hash : std_logic_vector(63 downto 0);
  signal ek_hash_sponge_in_valid : std_logic;

  -- alimentador por registros (y: seed_dk||01 ; G: tmp_h||m'||salt||00)
  signal reg_feed_in_valid : std_logic;
  signal reg_feed_in_data  : std_logic_vector(63 downto 0);
  signal reg_feed_word_index : integer range 0 to 8 := 0;
  signal reg_feed_last_index : integer range 0 to 8 := 0;
  signal reg_feed_command    : std_logic_vector(63 downto 0) := (others => '0');

  -- --------------------------------------------------------------------------
  -- sampler rej y banco de posiciones de y
  -- --------------------------------------------------------------------------
  signal y_sampler_shake_valid, y_sampler_shake_ready, y_sampler_write_enable, y_sampler_done : std_logic;
  signal y_sampler_write_address, y_sampler_read_address, y_bank_read_address : unsigned(6 downto 0);
  signal y_sampler_write_data, y_sampler_read_data, y_bank_read_data : unsigned(14 downto 0);

  -- --------------------------------------------------------------------------
  -- Memorias densas: ct_u, ct_v (entrada) y product (y*u)
  -- --------------------------------------------------------------------------
  signal ct_u_ram_write_enable, ct_v_ram_write_enable : std_logic;
  signal ct_u_ram_write_address, ct_v_ram_write_address, ct_u_ram_read_address, ct_v_ram_read_address : unsigned(8 downto 0);
  signal ct_u_ram_write_data, ct_v_ram_write_data, ct_u_ram_read_data, ct_v_ram_read_data : std_logic_vector(63 downto 0);
  signal product_ram_write_enable : std_logic;
  signal product_ram_write_address, product_ram_read_address : unsigned(8 downto 0);
  signal product_ram_write_data, product_ram_read_data : std_logic_vector(63 downto 0);

  -- poly_mul2 (DUAL = false)
  signal poly_mul_ready, poly_mul_done : std_logic;
  signal poly_mul_position_address : unsigned(6 downto 0);
  signal poly_mul_dense_address : unsigned(8 downto 0);
  signal acc_address_port1, acc_address_port2 : unsigned(9 downto 0);
  signal acc_write_enable_port1, acc_write_enable_port2 : std_logic;
  signal acc_data_in_port1, acc_data_in_port2, acc_data_out_port1, acc_data_out_port2 : std_logic_vector(63 downto 0);

  -- --------------------------------------------------------------------------
  -- Decodificacion: bloques RM
  -- --------------------------------------------------------------------------
  signal rm_block_index      : integer range 0 to 45 := 0;
  signal rm_fetch_step       : integer range 0 to 6 := 0;
  signal rm_block_ram_address : unsigned(8 downto 0);
  signal rm_block_word       : std_logic_vector(63 downto 0);
  signal rm_block_bits       : std_logic_vector(383 downto 0) := (others => '0');
  signal rm_decoder_in_valid, rm_decoder_in_ready, rm_decoder_out_valid : std_logic;
  signal rm_decoder_out_data : std_logic_vector(7 downto 0);
  signal rm_symbol_arrival_count : integer range 0 to 46 := 0;
  signal rm_all_symbols_received : std_logic := '0';

  -- Decodificacion: RS
  signal rs_decoder_feed_index   : integer range 0 to 45 := 0;
  signal rs_decoder_output_count : integer range 0 to 16 := 0;
  signal decode_finished, rs_decoder_error_sticky : std_logic := '0';
  signal rs_dec_in_valid, rs_dec_end_codeword, rs_dec_start_codeword, rs_dec_consume : std_logic;
  signal rs_dec_in_symbol, rs_dec_out_symbol : std_logic_vector(7 downto 0);
  signal rs_dec_out_in_ready, rs_dec_out_end, rs_dec_out_start, rs_dec_out_valid, rs_dec_out_error : std_logic;

  -- --------------------------------------------------------------------------
  -- Comparacion de (u', v') con el ct
  -- --------------------------------------------------------------------------
  signal compare_word_index : integer range 0 to 276 := 0;
  signal compare_read_ok    : std_logic := '0';
  signal compare_mismatch   : std_logic := '0';

  -- --------------------------------------------------------------------------
  -- k_rej: alimentador con realineador de bytes
  -- --------------------------------------------------------------------------
  signal k_reject_segment_index : integer range 0 to 5 := 0;
  signal k_reject_word_offset   : integer range 0 to 276 := 0;
  signal k_reject_accumulator   : std_logic_vector(119 downto 0) := (others => '0');
  signal k_reject_byte_count    : integer range 0 to 15 := 0;
  signal k_reject_chunk_word    : std_logic_vector(63 downto 0);
  signal k_reject_chunk_bytes   : integer range 1 to 8;
  signal k_reject_in_valid      : std_logic;
  signal k_reject_feed_busy     : std_logic;

begin

  ---------------------------------------------------------------------------
  -- Instancias
  ---------------------------------------------------------------------------
  reset_n_for_rm_decoder <= not rst;

  u_encrypt : entity work.hqc_encrypt
    generic map (SAMPLE_WEIGHT_R_E => 75, RS_OUT_REVERSED => RS_ENC_OUT_REVERSED,
                 RS_START_OVERLAP => RS_ENC_START_OVERLAP, RM_GEN_01 => RM_GEN_01)
    port map (clk => clk, rst => rst, start => encrypt_start, ready => encrypt_ready, done => encrypt_done,
              in_valid => encrypt_in_valid, in_ready => encrypt_in_ready, in_data => encrypt_in_data,
              out_valid => encrypt_out_valid, out_ready => encrypt_out_ready_internal, out_data => encrypt_out_data,
              out_last => encrypt_out_last, out_part => encrypt_out_part,
              cycles => open, cycles_core => open, err => encrypt_error, dbg_state => open);

  u_kem_sponge : entity work.keccak_sponge
    generic map (BIG_ENDIAN_WORDS => false)
    port map (clk => clk, rst => rst, abort => kem_sponge_abort,
              in_valid => kem_sponge_in_valid, in_ready => kem_sponge_in_ready, in_data => kem_sponge_in_data,
              out_valid => kem_sponge_out_valid, out_ready => kem_sponge_out_ready, out_data => kem_sponge_out_data,
              out_last => open);

  u_y_sampler : entity work.samplefxwtrej
    generic map (N => 17669, N_32 => 243079, WT => 66, SHAKE_BYTE_SWAP => false)
    port map (clk => clk, rst => rst, start => y_sampler_start,
              shake_din => kem_sponge_out_data, shake_valid => y_sampler_shake_valid, shake_ready => y_sampler_shake_ready,
              wr_en => y_sampler_write_enable, wr_addr => y_sampler_write_address, wr_data => y_sampler_write_data,
              rd_addr => y_sampler_read_address, rd_data => y_sampler_read_data,
              sample_done => y_sampler_done);

  u_y_position_bank : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => y_sampler_write_enable, wr_addr => y_sampler_write_address, din => y_sampler_write_data,
              rd_addr => y_bank_read_address, dout => y_bank_read_data);

  u_poly_mul : entity work.poly_mul2
    generic map (N => 17669, DUAL => false, POS_W => 15, PA_W => 7, AW => 9, ACC_AW => 10)
    port map (clk => clk, rst => rst, start => poly_mul_start, n_pos => Y_SPARSE_COUNT,
              ready => poly_mul_ready, done => poly_mul_done,
              pos_addr => poly_mul_position_address, pos_data => y_bank_read_data,
              dense_addr => poly_mul_dense_address, dense_a_data => ct_u_ram_read_data, dense_b_data => ZERO_WORD,
              acc_addr1 => acc_address_port1, acc_we1 => acc_write_enable_port1, acc_din1 => acc_data_in_port1,
              acc_addr2 => acc_address_port2, acc_we2 => acc_write_enable_port2,
              accA_din2 => acc_data_in_port2, accB_din2 => open,
              accA_dout1 => acc_data_out_port1, accB_dout1 => ZERO_WORD,
              accA_dout2 => acc_data_out_port2, accB_dout2 => ZERO_WORD,
              res_we => product_ram_write_enable, res_addr => product_ram_write_address,
              res_a_data => product_ram_write_data, res_b_data => open);

  u_poly_mul_acc : entity work.ram64_tdp
    generic map (DEPTH => 554, ADDR_W => 10)
    port map (clk => clk,
              we_1 => acc_write_enable_port1, addr_1 => acc_address_port1, din_1 => acc_data_in_port1, dout_1 => acc_data_out_port1,
              we_2 => acc_write_enable_port2, addr_2 => acc_address_port2, din_2 => acc_data_in_port2, dout_2 => acc_data_out_port2);

  u_ct_u_ram : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => ct_u_ram_write_enable, waddr => ct_u_ram_write_address, wdata => ct_u_ram_write_data,
              raddr => ct_u_ram_read_address, rdata => ct_u_ram_read_data);
  u_ct_v_ram : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => ct_v_ram_write_enable, waddr => ct_v_ram_write_address, wdata => ct_v_ram_write_data,
              raddr => ct_v_ram_read_address, rdata => ct_v_ram_read_data);
  u_product_ram : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => product_ram_write_enable, waddr => product_ram_write_address, wdata => product_ram_write_data,
              raddr => product_ram_read_address, rdata => product_ram_read_data);

  u_rm_decoder : entity work.rm_decoder
    generic map (m => 7, rep => 3, generator_matrix_01 => RM_GEN_01)
    port map (clock => clk, reset_n => reset_n_for_rm_decoder,
              in_valid => rm_decoder_in_valid, in_ready => rm_decoder_in_ready, data_in => rm_block_bits,
              out_valid => rm_decoder_out_valid, out_ready => '1', data_out => rm_decoder_out_data);

  u_rs_decoder : entity work.rs_decoder
    port map (clk => clk, rst => rst,
              i_end_codeword => rs_dec_end_codeword, i_start_codeword => rs_dec_start_codeword,
              i_valid => rs_dec_in_valid, i_consume => rs_dec_consume, i_symbol => rs_dec_in_symbol,
              o_in_ready => rs_dec_out_in_ready, o_end_codeword => rs_dec_out_end, o_start_codeword => rs_dec_out_start,
              o_valid => rs_dec_out_valid, o_error => rs_dec_out_error, o_symbol => rs_dec_out_symbol);

  ---------------------------------------------------------------------------
  -- Salidas simples
  ---------------------------------------------------------------------------
  ready       <= '1' when (main_state = ST_IDLE and encrypt_ready = '1') else '0';
  done        <= '1' when main_state = ST_DONE else '0';
  match       <= not compare_mismatch;
  err         <= rs_decoder_error_sticky or encrypt_error;
  cycles      <= cycles_at_ss_ready;
  cycles_core <= core_cycles_at_ss_ready;
  dbg_state   <= std_logic_vector(to_unsigned(main_state_t'pos(main_state), 4));

  ---------------------------------------------------------------------------
  -- Ingesta de dk y ct
  --   dk 0..280  : se reparten a la vez (tee) al sponge (hash de ek) y a hqc_encrypt
  --   dk 281..290: seed_dk, sigma a registros; seed_kem se ignora
  --   ct 0..276  : u a su RAM (la ultima palabra enmascarada a 5 bits para poly_mul2; el byte crudo va a u_last_byte_raw)
  --   ct 277..552: v a su RAM ;  ct 553..554: salt a registros
  ---------------------------------------------------------------------------
  ek_tee_active <= '1' when (main_state = ST_INGEST and dk_word_index < DK_EK_WORD_COUNT and
                             ek_hash_command_pending = '0') else '0';

  -- la ultima palabra de ek para el hash: byte 2240 + byte de dominio 01 (mensaje de 2242 B)
  ek_word_for_sponge_hash <= (dk_data and LOW_BYTE_MASK) or EK_HASH_DOMAIN_BYTE_01_IN_LAST_WORD
                               when dk_word_index = DK_INDEX_EK_LAST else dk_data;

  ek_hash_sponge_in_valid <= '1' when (main_state = ST_INGEST and ek_hash_command_pending = '1') else
                             '1' when (ek_tee_active = '1' and dk_valid = '1' and encrypt_in_ready = '1') else '0';

  dk_ready_internal <= (kem_sponge_in_ready and encrypt_in_ready) when ek_tee_active = '1' else
                       '1' when (main_state = ST_INGEST and dk_word_index >= DK_EK_WORD_COUNT and dk_word_index < DK_WORD_COUNT) else
                       '0';
  dk_ready <= dk_ready_internal;

  ct_ready_internal <= '1' when (main_state = ST_INGEST and ct_word_index < CT_WORD_COUNT) else '0';
  ct_ready <= ct_ready_internal;

  ct_u_ram_write_enable  <= '1' when (main_state = ST_INGEST and ct_valid = '1' and ct_word_index <= CT_INDEX_U_LAST) else '0';
  ct_u_ram_write_address <= to_unsigned(ct_word_index, 9) when ct_word_index <= CT_INDEX_U_LAST else (others => '0');
  ct_u_ram_write_data    <= (ct_data and U_LAST_WORD_MASK) when ct_word_index = CT_INDEX_U_LAST else ct_data;

  ct_v_ram_write_enable  <= '1' when (main_state = ST_INGEST and ct_valid = '1' and
                                      ct_word_index >= CT_INDEX_V_FIRST and ct_word_index < CT_INDEX_SALT_FIRST) else '0';
  ct_v_ram_write_address <= to_unsigned(ct_word_index - CT_INDEX_V_FIRST, 9)
                              when (ct_word_index >= CT_INDEX_V_FIRST and ct_word_index < CT_INDEX_SALT_FIRST) else (others => '0');
  ct_v_ram_write_data    <= ct_data;

  -- puerto de entrada de hqc_encrypt: ek repartido (ST_INGEST), luego m' y theta' (ST_SEND_ENCRYPT_INPUT)
  encrypt_in_valid <= '1' when (ek_tee_active = '1' and dk_valid = '1' and kem_sponge_in_ready = '1') else
                      '1' when main_state = ST_SEND_ENCRYPT_INPUT else '0';
  encrypt_in_data  <= dk_data when main_state = ST_INGEST else encrypt_inject_word;

  encrypt_inject_word_proc : process(inject_word_index, m_prime_bytes, theta_prime_words)
  begin
    case inject_word_index is
      when 0      => encrypt_inject_word <= pack_m_prime_word(m_prime_bytes, 0);
      when 1      => encrypt_inject_word <= pack_m_prime_word(m_prime_bytes, 1);
      when 2      => encrypt_inject_word <= theta_prime_words(0);
      when 3      => encrypt_inject_word <= theta_prime_words(1);
      when 4      => encrypt_inject_word <= theta_prime_words(2);
      when others => encrypt_inject_word <= theta_prime_words(3);
    end case;
  end process;

  ---------------------------------------------------------------------------
  -- Ruteo del sponge de la capa KEM segun el estado
  ---------------------------------------------------------------------------
  kem_sponge_in_valid <= ek_hash_sponge_in_valid   when main_state = ST_INGEST else
                         reg_feed_in_valid          when (main_state = ST_SAMPLE_Y or main_state = ST_HASH_G) else
                         k_reject_in_valid          when main_state = ST_RE_ENCRYPT else '0';

  kem_sponge_in_data  <= COMMAND_SHA3_256_EK          when (main_state = ST_INGEST and ek_hash_command_pending = '1') else
                         ek_word_for_sponge_hash      when main_state = ST_INGEST else
                         reg_feed_in_data             when (main_state = ST_SAMPLE_Y or main_state = ST_HASH_G) else
                         COMMAND_SHA3_256_K_REJECT    when (main_state = ST_RE_ENCRYPT and k_reject_feed_state = KREJ_COMMAND) else
                         k_reject_accumulator(63 downto 0);

  y_sampler_shake_valid <= kem_sponge_out_valid when main_state = ST_SAMPLE_Y else '0';
  kem_sponge_out_ready  <= y_sampler_shake_ready when main_state = ST_SAMPLE_Y else
                           '1' when (main_state = ST_INGEST or main_state = ST_HASH_G or main_state = ST_RE_ENCRYPT) else '0';

  -- banco de posiciones de y: sampler (escritura y limpieza del bitmap) y despues poly_mul2
  y_bank_read_address   <= y_sampler_read_address when main_state = ST_SAMPLE_Y else poly_mul_position_address;
  y_sampler_read_data   <= y_bank_read_data;

  -- direcciones de lectura de las RAM de ct y de product
  ct_u_ram_read_address <= poly_mul_dense_address                 when main_state = ST_WAIT_POLY_MUL else
                           to_unsigned(k_reject_word_offset, 9)   when k_reject_feed_busy = '1'      else
                           to_unsigned(compare_word_index, 9);
  ct_v_ram_read_address <= rm_block_ram_address                   when main_state = ST_DECODE_M_PRIME else
                           to_unsigned(k_reject_word_offset, 9)   when k_reject_feed_busy = '1'      else
                           to_unsigned(compare_word_index, 9);
  product_ram_read_address <= rm_block_ram_address;

  ---------------------------------------------------------------------------
  -- Salida ss = match ? kk' : k_rej
  ---------------------------------------------------------------------------
  out_valid <= '1' when main_state = ST_OUTPUT_SS else '0';
  out_last  <= '1' when (main_state = ST_OUTPUT_SS and ss_output_word_index = 3) else '0';
  out_data  <= kk_prime_words(ss_output_word_index) when compare_mismatch = '0' else k_reject_words(ss_output_word_index);

  ---------------------------------------------------------------------------
  -- Alimentador por registros: y (seed_dk || 01) y G (tmp_h || m' || salt || 00)
  ---------------------------------------------------------------------------
  reg_feed_in_valid <= '1' when (reg_feed_state = REGFEED_COMMAND or reg_feed_state = REGFEED_WORDS) else '0';

  reg_feed_data_proc : process(reg_feed_state, reg_feed_command, reg_feed_source, reg_feed_word_index,
                               seed_dk_words, tmp_h_words, m_prime_bytes, salt_words)
  begin
    if reg_feed_state = REGFEED_COMMAND then
      reg_feed_in_data <= reg_feed_command;
    elsif reg_feed_source = SOURCE_SEED_DK then
      if reg_feed_word_index < 4 then
        reg_feed_in_data <= seed_dk_words(reg_feed_word_index);
      else
        reg_feed_in_data <= DOMAIN_BYTE_01_WORD;
      end if;
    else
      if reg_feed_word_index < 4 then
        reg_feed_in_data <= tmp_h_words(reg_feed_word_index);
      elsif reg_feed_word_index < 6 then
        reg_feed_in_data <= pack_m_prime_word(m_prime_bytes, reg_feed_word_index - 4);
      elsif reg_feed_word_index < 8 then
        reg_feed_in_data <= salt_words(reg_feed_word_index - 6);
      else
        reg_feed_in_data <= ZERO_WORD;                       -- byte de dominio 00
      end if;
    end if;
  end process;

  reg_feed_fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        reg_feed_state      <= REGFEED_IDLE;
        reg_feed_word_index <= 0;
      else
        case reg_feed_state is
          when REGFEED_IDLE =>
            if reg_feed_go = '1' then
              reg_feed_state <= REGFEED_COMMAND;
            end if;
          when REGFEED_COMMAND =>
            if kem_sponge_in_ready = '1' then
              reg_feed_word_index <= 0;
              reg_feed_state      <= REGFEED_WORDS;
            end if;
          when REGFEED_WORDS =>
            if kem_sponge_in_ready = '1' then
              if reg_feed_word_index = reg_feed_last_index then
                reg_feed_state <= REGFEED_IDLE;
              else
                reg_feed_word_index <= reg_feed_word_index + 1;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Alimentador de k_rej con realineador de bytes
  --   mensaje = tmp_h(32) || sigma(16) || u(2209) || v(2208) || salt(16) || 03   = 4482 B = 561 palabras
  --   Trozos de 8 B salvo el ultimo byte de u y el 03 (1 B). El acumulador guarda hasta 15 B
  --   (k_reject_byte_count validos); por cada trozo se anade y, si hay >= 8 B, se envia una palabra al sponge.
  ---------------------------------------------------------------------------
  k_reject_in_valid  <= '1' when (k_reject_feed_state = KREJ_COMMAND or
                                  (k_reject_feed_state = KREJ_SEND_WORD and k_reject_byte_count >= 8) or
                                  (k_reject_feed_state = KREJ_FLUSH and k_reject_byte_count > 0)) else '0';
  -- la lectura de las RAM de ct es de k_rej desde que se lanza hasta que termina
  k_reject_feed_busy <= '1' when (k_reject_feed_state /= KREJ_IDLE or k_reject_feed_go = '1') else '0';

  k_reject_chunk_proc : process(k_reject_segment_index, k_reject_word_offset, tmp_h_words, sigma_words, salt_words,
                                ct_u_ram_read_data, ct_v_ram_read_data, u_last_byte_raw)
  begin
    k_reject_chunk_word  <= ZERO_WORD;
    k_reject_chunk_bytes <= 8;
    case k_reject_segment_index is
      when 0 =>
        k_reject_chunk_word <= word_of_tmp_h(tmp_h_words, k_reject_word_offset);
      when 1 =>
        k_reject_chunk_word <= sigma_words(k_reject_word_offset mod 2);
      when 2 =>
        if k_reject_word_offset < CT_INDEX_U_LAST then
          k_reject_chunk_word <= ct_u_ram_read_data;
        else
          k_reject_chunk_word  <= std_logic_vector'(x"00000000000000" & u_last_byte_raw);   -- ultimo byte de u: 1 B
          k_reject_chunk_bytes <= 1;
        end if;
      when 3 =>
        k_reject_chunk_word <= ct_v_ram_read_data;
      when 4 =>
        k_reject_chunk_word <= salt_words(k_reject_word_offset mod 2);
      when others =>
        k_reject_chunk_word  <= DOMAIN_BYTE_03_WORD;                                      -- byte de dominio 03: 1 B
        k_reject_chunk_bytes <= 1;
    end case;
  end process;

  k_reject_feed_fsm : process(clk)
    variable advance_to_next_chunk : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        k_reject_feed_state   <= KREJ_IDLE;
        k_reject_segment_index <= 0;
        k_reject_word_offset  <= 0;
        k_reject_byte_count   <= 0;
        k_reject_accumulator  <= (others => '0');
      else
        case k_reject_feed_state is

          when KREJ_IDLE =>
            if k_reject_feed_go = '1' then
              k_reject_feed_state <= KREJ_COMMAND;
            end if;

          when KREJ_COMMAND =>                              -- comando SHA3-256, 4482 B
            if kem_sponge_in_ready = '1' then
              k_reject_segment_index <= 0;
              k_reject_word_offset   <= 0;
              k_reject_byte_count    <= 0;
              k_reject_accumulator   <= (others => '0');
              k_reject_feed_state    <= KREJ_SET_ADDRESS;
            end if;

          when KREJ_SET_ADDRESS =>                          -- k_reject_word_offset direcciona ct_u y ct_v
            k_reject_feed_state <= KREJ_WAIT_RAM;

          when KREJ_WAIT_RAM =>                             -- latencia de las RAM
            k_reject_feed_state <= KREJ_PUSH_CHUNK;

          when KREJ_PUSH_CHUNK =>                           -- anadir el trozo al acumulador
            k_reject_accumulator <= k_reject_accumulator or
                                    std_logic_vector(shift_left(resize(unsigned(k_reject_chunk_word), 120), 8 * k_reject_byte_count));
            k_reject_byte_count  <= k_reject_byte_count + k_reject_chunk_bytes;
            k_reject_feed_state  <= KREJ_SEND_WORD;

          when KREJ_SEND_WORD =>                            -- con >= 8 B se envia una palabra
            advance_to_next_chunk := false;
            if k_reject_byte_count >= 8 then
              if kem_sponge_in_ready = '1' then
                k_reject_accumulator  <= std_logic_vector(shift_right(unsigned(k_reject_accumulator), 64));
                k_reject_byte_count   <= k_reject_byte_count - 8;
                advance_to_next_chunk := true;
              end if;
            else
              advance_to_next_chunk := true;
            end if;
            if advance_to_next_chunk then
              if k_reject_segment_index = 5 then
                k_reject_feed_state <= KREJ_FLUSH;
              else
                if k_reject_word_offset = k_reject_segment_length(k_reject_segment_index) - 1 then
                  k_reject_segment_index <= k_reject_segment_index + 1;
                  k_reject_word_offset   <= 0;
                else
                  k_reject_word_offset <= k_reject_word_offset + 1;
                end if;
                k_reject_feed_state <= KREJ_SET_ADDRESS;
              end if;
            end if;

          when KREJ_FLUSH =>                                -- resto (4482 mod 8 = 2 B): ultima palabra parcial
            if k_reject_byte_count > 0 then
              if kem_sponge_in_ready = '1' then
                k_reject_byte_count <= 0;
                k_reject_feed_state <= KREJ_IDLE;
              end if;
            else
              k_reject_feed_state <= KREJ_IDLE;
            end if;

        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Decodificacion RM: bloques i = 45 .. 0 (cm[6i .. 6i+5]); cm = v xor (y*u) al vuelo.
  -- data_in = w5 & w4 & w3 & w2 & w1 & w0 (w0 = bits bajos del bloque = copia 0 en los 128 bits bajos).
  -- Los simbolos salen en el mismo orden: cw[45] .. cw[0] (orden de entrada del rs_decoder).
  ---------------------------------------------------------------------------
  rm_block_word        <= ct_v_ram_read_data xor product_ram_read_data;
  rm_block_ram_address <= to_unsigned(6 * rm_block_index + rm_fetch_step, 9) when rm_fetch_step < 6 else (others => '0');
  rm_decoder_in_valid  <= '1' when rm_block_state = RMB_PUSH else '0';

  rm_block_fsm : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rm_block_state          <= RMB_IDLE;
        rm_all_symbols_received <= '0';
        rm_symbol_arrival_count <= 0;
      else
        -- los simbolos que salen del rm_decoder se guardan en orden de llegada
        if rm_decoder_out_valid = '1' then
          if rm_symbol_arrival_count <= 45 then
            rs_decoder_input_bytes(rm_symbol_arrival_count) <= rm_decoder_out_data;
          end if;
          if rm_symbol_arrival_count = 45 then
            rm_all_symbols_received <= '1';
          end if;
          if rm_symbol_arrival_count < 46 then
            rm_symbol_arrival_count <= rm_symbol_arrival_count + 1;
          end if;
        end if;

        case rm_block_state is
          when RMB_IDLE =>
            if decode_go = '1' then
              rm_block_index          <= 45;
              rm_fetch_step           <= 0;
              rm_symbol_arrival_count <= 0;
              rm_all_symbols_received <= '0';
              rm_block_state          <= RMB_FETCH;
            end if;

          when RMB_FETCH =>                                  -- el ciclo t presenta la direccion t; el dato t llega en t+1
            case rm_fetch_step is
              when 1      => rm_block_bits(63 downto 0)     <= rm_block_word;
              when 2      => rm_block_bits(127 downto 64)   <= rm_block_word;
              when 3      => rm_block_bits(191 downto 128)  <= rm_block_word;
              when 4      => rm_block_bits(255 downto 192)  <= rm_block_word;
              when 5      => rm_block_bits(319 downto 256)  <= rm_block_word;
              when 6      => rm_block_bits(383 downto 320)  <= rm_block_word;
              when others => null;
            end case;
            if rm_fetch_step = 6 then
              rm_block_state <= RMB_PUSH;
            else
              rm_fetch_step <= rm_fetch_step + 1;
            end if;

          when RMB_PUSH =>                                   -- rm_decoder_in_valid = '1' hasta que in_ready
            if rm_decoder_in_ready = '1' then
              if rm_block_index = 0 then
                rm_block_state <= RMB_END;
              else
                rm_block_index <= rm_block_index - 1;
                rm_fetch_step  <= 0;
                rm_block_state <= RMB_FETCH;
              end if;
            end if;

          when RMB_END =>
            rm_block_state <= RMB_IDLE;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Decodificacion RS: con los 46 simbolos ya recibidos se envian seguidos (cw[45] .. cw[0]);
  -- el decoder entrega primero los 16 simbolos de informacion b0..b15 = m[15] .. m[0].
  ---------------------------------------------------------------------------
  rs_dec_consume        <= '1';
  rs_dec_in_valid       <= '1' when rs_decode_state = RSD_FEED else '0';
  rs_dec_in_symbol      <= rs_decoder_input_bytes(rs_decoder_feed_index);
  rs_dec_end_codeword   <= '1' when (rs_decode_state = RSD_FEED and rs_decoder_feed_index = 45) else '0';
  rs_dec_start_codeword <= '1' when ((RS_DEC_START_OVERLAP and rs_decode_state = RSD_FEED and rs_decoder_feed_index = 0) or
                                     ((not RS_DEC_START_OVERLAP) and rs_decode_state = RSD_PRE_START)) else '0';

  rs_decode_fsm : process(clk)
    variable output_symbol_index : integer range 0 to 16;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rs_decode_state         <= RSD_IDLE;
        decode_finished         <= '0';
        rs_decoder_error_sticky <= '0';
        rs_decoder_output_count <= 0;
        rs_decoder_feed_index   <= 0;
      else
        if start = '1' and main_state = ST_IDLE then
          rs_decoder_error_sticky <= '0';
        end if;
        if rs_dec_out_error = '1' then
          rs_decoder_error_sticky <= '1';
        end if;

        -- captura de la salida: m'[15 - k] = k-esimo simbolo; termina con o_end_codeword
        if rs_dec_out_valid = '1' and rs_decode_state = RSD_CAPTURE then
          if rs_dec_out_start = '1' then
            output_symbol_index := 0;
          else
            output_symbol_index := rs_decoder_output_count;
          end if;
          if output_symbol_index < 16 then
            m_prime_bytes(15 - output_symbol_index) <= rs_dec_out_symbol;
            rs_decoder_output_count                 <= output_symbol_index + 1;
          end if;
          if rs_dec_out_end = '1' then
            decode_finished <= '1';
            rs_decode_state <= RSD_IDLE;
          end if;
        end if;

        case rs_decode_state is
          when RSD_IDLE =>
            if decode_go = '1' then
              decode_finished         <= '0';
              rs_decoder_output_count <= 0;
              rs_decode_state         <= RSD_WAIT_SYMBOLS;
            end if;
          when RSD_WAIT_SYMBOLS =>                            -- esperar los 46 simbolos del RM
            if rm_all_symbols_received = '1' then
              rs_decoder_feed_index <= 0;
              if RS_DEC_START_OVERLAP then
                rs_decode_state <= RSD_FEED;
              else
                rs_decode_state <= RSD_PRE_START;
              end if;
            end if;
          when RSD_PRE_START =>
            rs_decode_state <= RSD_FEED;
          when RSD_FEED =>
            if rs_decoder_feed_index = 45 then
              rs_decode_state <= RSD_CAPTURE;
            else
              rs_decoder_feed_index <= rs_decoder_feed_index + 1;
            end if;
          when RSD_CAPTURE =>
            null;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Comparacion de (u', v') con el ct recibido (sin salida anticipada):
  --   se acepta una palabra de hqc_encrypt solo cuando las RAM de ct ya presentaron su dato
  --   y k_rej ya no las usa. u[276] compara solo el byte bajo (el resto de la palabra es relleno).
  ---------------------------------------------------------------------------
  encrypt_out_ready_internal <= '1' when (main_state = ST_RE_ENCRYPT and encrypt_out_valid = '1' and
                                          compare_read_ok = '1' and k_reject_feed_busy = '0') else '0';

  compare_fsm : process(clk)
    variable transfer : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        compare_word_index <= 0;
        compare_read_ok    <= '0';
        compare_mismatch   <= '0';
      else
        if main_state = ST_IDLE and start = '1' then
          compare_mismatch <= '0';
        end if;
        if main_state /= ST_RE_ENCRYPT then
          compare_word_index <= 0;
          compare_read_ok    <= '0';
        else
          transfer := (encrypt_out_valid = '1' and encrypt_out_ready_internal = '1');
          if transfer then
            compare_read_ok <= '0';
            if encrypt_out_part = '0' then                     -- u'
              if compare_word_index = CT_INDEX_U_LAST then
                if encrypt_out_data(7 downto 0) /= u_last_byte_raw then
                  compare_mismatch <= '1';
                end if;
              elsif encrypt_out_data /= ct_u_ram_read_data then
                compare_mismatch <= '1';
              end if;
            else                                               -- v'
              if encrypt_out_data /= ct_v_ram_read_data then
                compare_mismatch <= '1';
              end if;
            end if;
            if encrypt_out_last = '1' then
              compare_word_index <= 0;
            else
              compare_word_index <= compare_word_index + 1;
            end if;
          else
            compare_read_ok <= not k_reject_feed_busy;         -- la direccion de la RAM lleva >= 1 ciclo estable
          end if;
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- FSM principal
  ---------------------------------------------------------------------------
  main_fsm : process(clk)
    variable dk_transfer : boolean;
    variable ct_transfer : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        main_state                 <= ST_IDLE;
        dk_word_index              <= 0;
        ct_word_index              <= 0;
        inject_word_index          <= 0;
        kem_sponge_capture_count   <= 0;
        ss_output_word_index       <= 0;
        ek_hash_command_pending    <= '0';
        encrypt_done_latched       <= '0';
        cycle_counter_running      <= '0';
        core_cycle_counter_running <= '0';
        encrypt_start              <= '0';
        y_sampler_start            <= '0';
        reg_feed_go                <= '0';
        k_reject_feed_go           <= '0';
        poly_mul_start             <= '0';
        kem_sponge_abort           <= '0';
        decode_go                  <= '0';
      else
        -- pulsos: valen '1' durante UN ciclo cuando se asignan
        encrypt_start    <= '0';
        y_sampler_start  <= '0';
        reg_feed_go      <= '0';
        k_reject_feed_go <= '0';
        poly_mul_start   <= '0';
        kem_sponge_abort <= '0';
        decode_go        <= '0';

        if cycle_counter_running = '1' then
          cycle_counter <= cycle_counter + 1;
        end if;
        if core_cycle_counter_running = '1' then
          core_cycle_counter <= core_cycle_counter + 1;
        end if;
        if encrypt_done = '1' then
          encrypt_done_latched <= '1';
        end if;

        -- captura de la salida del sponge de la capa KEM
        if kem_sponge_out_valid = '1' and kem_sponge_out_ready = '1' then
          case main_state is
            when ST_INGEST =>                                  -- tmp_h
              if kem_sponge_capture_count < 4 then
                tmp_h_words(kem_sponge_capture_count) <= kem_sponge_out_data;
                kem_sponge_capture_count              <= kem_sponge_capture_count + 1;
              end if;
            when ST_HASH_G =>                                  -- kk' (0..3) y theta' (4..7)
              if kem_sponge_capture_count < 4 then
                kk_prime_words(kem_sponge_capture_count) <= kem_sponge_out_data;
                kem_sponge_capture_count                 <= kem_sponge_capture_count + 1;
              elsif kem_sponge_capture_count < 8 then
                theta_prime_words(kem_sponge_capture_count - 4) <= kem_sponge_out_data;
                kem_sponge_capture_count                        <= kem_sponge_capture_count + 1;
              end if;
            when ST_RE_ENCRYPT =>                              -- k_rej
              if kem_sponge_capture_count < 4 then
                k_reject_words(kem_sponge_capture_count) <= kem_sponge_out_data;
                kem_sponge_capture_count                 <= kem_sponge_capture_count + 1;
              end if;
            when others =>
              null;
          end case;
        end if;

        case main_state is

          when ST_IDLE =>
            if start = '1' and encrypt_ready = '1' then
              encrypt_start            <= '1';                 -- hqc_encrypt entra en su ingesta y espera ek
              dk_word_index            <= 0;
              ct_word_index            <= 0;
              kem_sponge_capture_count <= 0;
              ek_hash_command_pending  <= '1';                 -- primero el comando SHA3-256 del hash de ek
              cycle_counter            <= (others => '0');
              cycle_counter_running    <= '1';
              main_state               <= ST_INGEST;
            end if;

          when ST_INGEST =>
            if ek_hash_command_pending = '1' and kem_sponge_in_ready = '1' then
              ek_hash_command_pending <= '0';
            end if;
            dk_transfer := (dk_valid = '1' and dk_ready_internal = '1');
            if dk_transfer then
              if dk_word_index >= DK_INDEX_SEED_DK_FIRST and dk_word_index < DK_INDEX_SIGMA_FIRST then
                seed_dk_words(dk_word_index - DK_INDEX_SEED_DK_FIRST) <= dk_data;
              elsif dk_word_index >= DK_INDEX_SIGMA_FIRST and dk_word_index < DK_INDEX_SIGMA_FIRST + 2 then
                sigma_words(dk_word_index - DK_INDEX_SIGMA_FIRST) <= dk_data;
              end if;                                          -- 0..280 reenviado ; 287..290 seed_kem, se ignora
              dk_word_index <= dk_word_index + 1;
            end if;
            ct_transfer := (ct_valid = '1' and ct_ready_internal = '1');
            if ct_transfer then
              if ct_word_index = CT_INDEX_U_LAST then
                u_last_byte_raw <= ct_data(7 downto 0);        -- byte 2208 de u tal cual (para comparar y para el hash)
              elsif ct_word_index >= CT_INDEX_SALT_FIRST then
                salt_words(ct_word_index - CT_INDEX_SALT_FIRST) <= ct_data;
              end if;                                          -- u y v los escriben las RAM
              ct_word_index <= ct_word_index + 1;
            end if;
            if dk_word_index = DK_WORD_COUNT and ct_word_index = CT_WORD_COUNT and kem_sponge_capture_count = 4 then
              -- todo recibido y tmp_h capturado: y = rej(SHAKE256(seed_dk||01))
              reg_feed_source            <= SOURCE_SEED_DK;
              reg_feed_command           <= COMMAND_SHAKE_Y_STREAM;
              reg_feed_last_index        <= 4;
              reg_feed_go                <= '1';
              y_sampler_start            <= '1';
              core_cycle_counter         <= (others => '0');
              core_cycle_counter_running <= '1';
              main_state                 <= ST_SAMPLE_Y;
            end if;

          when ST_SAMPLE_Y =>
            if y_sampler_done = '1' then
              kem_sponge_abort <= '1';                         -- y listo: cortar el flujo del sponge
              main_state       <= ST_START_POLY_MUL;
            end if;

          when ST_START_POLY_MUL =>
            if poly_mul_ready = '1' then
              poly_mul_start <= '1';
              main_state     <= ST_WAIT_POLY_MUL;
            end if;

          when ST_WAIT_POLY_MUL =>                             -- res = y * u
            if poly_mul_done = '1' then
              decode_go  <= '1';
              main_state <= ST_DECODE_M_PRIME;
            end if;

          when ST_DECODE_M_PRIME =>                            -- RM + RS -> m'
            if decode_finished = '1' then
              reg_feed_source          <= SOURCE_G_MESSAGE;
              reg_feed_command         <= COMMAND_SHA3_512_G;
              reg_feed_last_index      <= 8;
              reg_feed_go              <= '1';
              kem_sponge_capture_count <= 0;
              main_state               <= ST_HASH_G;
            end if;

          when ST_HASH_G =>                                    -- kk' y theta' capturados (arriba)
            if kem_sponge_capture_count = 8 then
              inject_word_index <= 0;
              main_state        <= ST_SEND_ENCRYPT_INPUT;
            end if;

          when ST_SEND_ENCRYPT_INPUT =>                        -- m' (2 palabras) y theta' (4), encrypt_in_valid = '1'
            if encrypt_in_ready = '1' then
              if inject_word_index = 5 then
                k_reject_feed_go         <= '1';               -- k_rej corre en paralelo con el re-cifrado
                kem_sponge_capture_count <= 0;
                encrypt_done_latched     <= '0';
                main_state               <= ST_RE_ENCRYPT;
              else
                inject_word_index <= inject_word_index + 1;
              end if;
            end if;

          when ST_RE_ENCRYPT =>                                -- compare_fsm consume (u', v'); k_reject_feed_fsm hace el hash
            if encrypt_done_latched = '1' and k_reject_feed_busy = '0' and kem_sponge_capture_count = 4 then
              ss_output_word_index         <= 0;
              cycle_counter_running        <= '0';
              core_cycle_counter_running   <= '0';
              cycles_at_ss_ready           <= cycle_counter;
              core_cycles_at_ss_ready      <= core_cycle_counter;
              main_state                   <= ST_OUTPUT_SS;
            end if;

          when ST_OUTPUT_SS =>                                 -- ss = match ? kk' : k_rej
            if out_ready = '1' then
              if ss_output_word_index = 3 then
                main_state <= ST_DONE;
              else
                ss_output_word_index <= ss_output_word_index + 1;
              end if;
            end if;

          when ST_DONE =>
            main_state <= ST_IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;
