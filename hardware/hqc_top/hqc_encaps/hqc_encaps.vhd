-- ============================================================================
-- hqc_encaps : HQC-128 Encaps (KEM)
--
--   entrada : pulso start (solo con ready='1'); luego 285 palabras de 64 bits por key_valid/key_ready:
--               palabras   0..3    seed_ek (32 B)         \  ek = 2241 B (palabras 0..280, la 280 solo
--               palabras   4..280  s (2209 B)             /  tiene 1 byte valido)
--               palabras 281..282  m (16 B)
--               palabras 283..284  salt (16 B)
--   salida  : 4 partes, cada una alineada a palabra de 64 bits (la ultima palabra de una parte con
--             bytes sobrantes los lleva a 0). out_last marca la ultima palabra de cada parte.
--             Orden por defecto (constante OUT_SEQ):   ss | u | v | salt
--                out_part "00" ss    (32 B,   4 palabras)
--                out_part "01" u     (2209 B, 277 palabras, la ultima con 1 byte valido)
--                out_part "10" v     (2208 B, 276 palabras)
--                out_part "11" salt  (16 B,   2 palabras)
--             ATENCION: en hqc128.py ct = u || v || salt. Cambiar el orden de entrega = cambiar OUT_SEQ.
--   done    : pulso al terminar de entregar todo
--   cycles      : ciclos desde start hasta tener u y v listos (incluye la ingesta de la clave)
--   cycles_core : igual pero contados desde el fin de la ingesta (no depende de quien alimenta key_*)
--   Bytes en palabras: byte 0 en los bits [7:0] (igual que el sponge).
--
-- Una micro-operacion de sponge a la vez (como el keygen v3):
--   S_KEY    ingesta de ek (seed_ek -> registros, s -> RAM s), m y salt
--   step 1   SHA3-256(ek||01), 2242 B          -> tmp_h
--   step 2   SHA3-512(tmp_h||m||salt||00), 65B -> ss (=kk, 32 B), theta (32 B)
--   step 3   SHAKE256(seed_ek||01), 2216 B     -> sample_vect -> h        (RAM h)
--   step 4   SHAKE256(theta||01), SIN LIMITE   -> sampler mod: r2, e, r1  (3 bancos de posiciones)
--            abort al terminar r1
--   S_JOIN   espera el codificador RS/RM (corre solo, en paralelo con los pasos anteriores)
--   S_MUL    poly_mul2 DUAL: u = r2*h  (RAM u)   y   v = r2*s  (RAM v)
--   S_XOR    sparse_xor: u <- u xor r1  ;  v <- v xor e
--   S_O_*    salida. v sale como  v_ram xor cm  (cm = RM(RS(m)), RAM cm) al vuelo.
--
-- Codificador RS (rs_encoder): se alimenta con m[15]..m[0] y emite los 46 simbolos en el orden inverso
-- del codeword de hqc128.py (cw = paridad(30) || m(16)); se guardan en cw_r(0..45). RM: 6 palabras
-- (y_lo,y_hi)x3 por simbolo -> RAM cm (276 palabras).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.keccak_sponge_pkg.all;
use WORK.RS_TYPES.all;

entity hqc_encaps is
  generic(
    RM_GEN_01         : boolean := false;  -- generator_matrix_01 de rm_encoder/rm_decoder (HQC: false); mismo valor en ambos
    WT_R             : integer := 75;     -- peso de r1 y r2 (HQC-128)
    WT_E             : integer := 75;     -- peso de e
    RS_OUT_REVERSED  : boolean := true;   -- true: el RS emite el simbolo cw[45] primero (orden inverso)
    RS_START_OVERLAP : boolean := true    -- true: i_start_codeword coincide con el 1er simbolo
  );
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;

    start : in  std_logic;        -- pulso, solo con ready='1'
    ready : out std_logic;
    done  : out std_logic;        -- pulso al terminar de entregar ss || ct

    key_valid : in  std_logic;
    key_ready : out std_logic;
    key_data  : in  std_logic_vector(63 downto 0);

    out_valid : out std_logic;
    out_ready : in  std_logic;
    out_data  : out std_logic_vector(63 downto 0);
    out_last  : out std_logic;
    out_part  : out std_logic_vector(1 downto 0);

    cycles      : out unsigned(31 downto 0);
    cycles_core : out unsigned(31 downto 0);
    err         : out std_logic;                       -- pegajoso: error del RS (se limpia con start)
    dbg_state   : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of hqc_encaps is

  -- --------------------------------------------------------------------------
  -- Constantes
  -- --------------------------------------------------------------------------
  constant WORDS      : integer := 277;                 -- palabras de un vector denso (N = 17669)
  constant V_WORDS    : integer := 276;                 -- palabras de v (N1N2 = 17664 bits)
  constant KEY_LAST   : integer := 284;                 -- ultima palabra de la ingesta
  constant EK_MSG_LAST: integer := 280;                 -- ek||01 = 2242 B = 281 palabras
  constant H_BYTES    : integer := WORDS * 8;           -- 2216 B que consume sample_vect

  constant CMD_HASH_EK : std_logic_vector(63 downto 0) := make_cmd(MODE_SHA3_256, 2242, 0);
  constant CMD_G       : std_logic_vector(63 downto 0) := make_cmd(MODE_SHA3_512, 65, 0);
  constant CMD_H       : std_logic_vector(63 downto 0) := make_cmd(MODE_SHAKE256, 33, H_BYTES);
  constant CMD_THETA   : std_logic_vector(63 downto 0) := make_cmd_stream(MODE_SHAKE256, 33);

  constant ZERO64    : std_logic_vector(63 downto 0) := (others => '0');
  constant DOM01     : std_logic_vector(63 downto 0) := x"0000000000000001";
  constant LAST_MASK : std_logic_vector(63 downto 0) := x"000000000000001F";   -- N mod 64 = 5 bits
  constant NPOS_R2   : unsigned(6 downto 0) := to_unsigned(WT_R, 7);
  constant NPOS_R1   : unsigned(6 downto 0) := to_unsigned(WT_R, 7);
  constant NPOS_E    : unsigned(6 downto 0) := to_unsigned(WT_E, 7);

  -- segmentos de salida y orden de entrega (editar OUT_SEQ para cambiar el orden)
  constant SEG_SS   : integer := 0;
  constant SEG_V    : integer := 2;
  constant SEG_U    : integer := 1;
  constant SEG_SALT : integer := 3;
  type seq_t is array (0 to 3) of integer range 0 to 3;
  constant OUT_SEQ : seq_t := (SEG_SS, SEG_U, SEG_V, SEG_SALT);

  function seg_last_word(seg : integer) return integer is
  begin
    case seg is
      when SEG_SS => return 3;
      when SEG_V  => return V_WORDS - 1;       -- 275
      when SEG_U  => return WORDS - 1;         -- 276
      when others => return 1;                 -- salt
    end case;
  end function;

  function byte_of(w : std_logic_vector(63 downto 0); lane : integer) return std_logic_vector is
    variable u : unsigned(63 downto 0);
  begin
    u := shift_right(unsigned(w), 8 * lane);
    return std_logic_vector(u(7 downto 0));
  end function;

  function rm_slice(d : std_logic_vector(383 downto 0); t : integer) return std_logic_vector is
  begin
    case t is
      when 0      => return d(63 downto 0);
      when 1      => return d(127 downto 64);
      when 2      => return d(191 downto 128);
      when 3      => return d(255 downto 192);
      when 4      => return d(319 downto 256);
      when others => return d(383 downto 320);
    end case;
  end function;

  -- --------------------------------------------------------------------------
  -- Tipos y senales de control
  -- --------------------------------------------------------------------------
  type state_t  is (S_IDLE, S_KEY, S_LAUNCH, S_STORE, S_H, S_SAMP, S_JOIN, S_MUL,
                    S_XSTART, S_XOR, S_O_ADDR, S_O_SEND, S_DONE);
  type phase_t  is (PH_NONE, PH_STORE, PH_H, PH_R2, PH_E, PH_R1);
  type fstate_t is (FS_IDLE, FS_CMD, FS_WAIT, FS_SEND);
  type fsrc_t   is (SRC_EK, SRC_G, SRC_SEED_EK, SRC_THETA);
  type rsstate_t is (RS_IDLE, RS_PRE, RS_FEED, RS_CAPT, RM_WR, RM_FLUSH);

  type words4_t is array (0 to 3) of std_logic_vector(63 downto 0);
  type words2_t is array (0 to 1) of std_logic_vector(63 downto 0);
  type bytes46_t is array (0 to 45) of std_logic_vector(7 downto 0);

  signal state  : state_t  := S_IDLE;
  signal phase  : phase_t  := PH_NONE;
  signal fs     : fstate_t := FS_IDLE;
  signal rs_fs  : rsstate_t := RS_IDLE;

  -- valores pequenos con nombre propio (registros)
  signal ek_seed_r : words4_t := (others => (others => '0'));   -- seed_ek  (ek, palabras 0..3)
  signal m_r       : words2_t := (others => (others => '0'));   -- mensaje m (16 B)
  signal salt_r    : words2_t := (others => (others => '0'));   -- salt (16 B)
  signal tmp_h_r   : words4_t := (others => (others => '0'));   -- SHA3-256(ek||01)
  signal ss_r      : words4_t := (others => (others => '0'));   -- kk = secreto compartido
  signal theta_r   : words4_t := (others => (others => '0'));   -- semilla del muestreo
  signal cw_r      : bytes46_t := (others => (others => '0'));  -- codeword RS en el orden de hqc128.py

  signal step      : integer range 0 to 5 := 0;
  signal key_idx   : integer range 0 to 285 := 0;
  signal samp_n    : integer range 0 to 2 := 0;                 -- 0: r2, 1: e, 2: r1
  signal xor_sel   : std_logic := '0';                          -- '0': u xor r1 ; '1': v xor e
  signal store_sel : integer range 0 to 1 := 0;                 -- 0 -> tmp_h ; 1 -> ss, theta
  signal cap_cnt   : integer range 0 to 8 := 0;
  signal cap_total : integer range 0 to 8 := 0;

  -- alimentador del sponge
  signal fidx   : integer range 0 to 280 := 0;
  signal f_last : integer range 0 to 280 := 0;
  signal f_src  : fsrc_t := SRC_EK;
  signal f_cmd  : std_logic_vector(63 downto 0) := (others => '0');
  signal feed_s_addr : unsigned(8 downto 0);

  -- pulsos de un ciclo (registros)
  signal f_go, sv_start, smp_start, mul_start, xor_start, abort_req, rs_go : std_logic := '0';

  -- contadores de ciclos
  signal running, core_running : std_logic := '0';
  signal cyc, cyc_core         : unsigned(31 downto 0) := (others => '0');
  signal cycles_r, cycles_core_r : unsigned(31 downto 0) := (others => '0');

  -- salida
  signal part_i  : integer range 0 to 3 := 0;
  signal ok      : integer range 0 to 276 := 0;
  signal out_mem_addr : unsigned(8 downto 0);

  -- sponge
  signal sp_in_valid, sp_in_ready, sp_out_valid, sp_out_ready : std_logic;
  signal sp_in_data, sp_out_data : std_logic_vector(63 downto 0);

  -- sample_vect
  signal sv_din_valid, sv_din_ready, sv_wr_en, sv_done : std_logic;
  signal sv_wr_addr : unsigned(8 downto 0);
  signal sv_wr_data : std_logic_vector(63 downto 0);

  -- sampler mod
  signal smp_shake_valid, smp_shake_ready, smp_wr_en, smp_done : std_logic;
  signal smp_wr_addr, smp_rd_addr : unsigned(6 downto 0);
  signal smp_wr_data, smp_rd_data : unsigned(14 downto 0);

  -- bancos de posiciones dedicados: r2, e, r1
  signal we_r2, we_e, we_r1 : std_logic;
  signal rd_r2, rd_e, rd_r1 : unsigned(6 downto 0);
  signal bank_r2_dout, bank_e_dout, bank_r1_dout : unsigned(14 downto 0);

  -- memorias densas
  signal s_mem_we    : std_logic;
  signal s_mem_waddr, s_mem_raddr : unsigned(8 downto 0);
  signal s_mem_wdata, s_mem_rdata : std_logic_vector(63 downto 0);
  signal h_mem_raddr : unsigned(8 downto 0);
  signal h_mem_rdata : std_logic_vector(63 downto 0);
  signal u_mem_we, v_mem_we : std_logic;
  signal u_mem_waddr, v_mem_waddr, u_mem_raddr, v_mem_raddr : unsigned(8 downto 0);
  signal u_mem_wdata, v_mem_wdata, u_mem_rdata, v_mem_rdata : std_logic_vector(63 downto 0);
  signal cm_mem_we     : std_logic := '0';
  signal cm_mem_waddr  : unsigned(8 downto 0) := (others => '0');
  signal cm_mem_wdata  : std_logic_vector(63 downto 0) := (others => '0');
  signal cm_mem_rdata  : std_logic_vector(63 downto 0);

  -- poly_mul2
  signal mul_ready, mul_done, res_we : std_logic;
  signal mul_pos_addr : unsigned(6 downto 0);
  signal dense_addr, res_addr : unsigned(8 downto 0);
  signal res_a_data, res_b_data : std_logic_vector(63 downto 0);
  signal acc_addr1, acc_addr2 : unsigned(9 downto 0);
  signal acc_we1, acc_we2 : std_logic;
  signal acc_din1, accA_din2, accB_din2 : std_logic_vector(63 downto 0);
  signal accA_dout1, accA_dout2, accB_dout1, accB_dout2 : std_logic_vector(63 downto 0);

  -- sparse_xor
  signal xor_ready, xor_done, xor_mem_we : std_logic;
  signal xor_pos_addr, xor_npos : unsigned(6 downto 0);
  signal xor_pos_data : unsigned(14 downto 0);
  signal xor_mem_addr : unsigned(8 downto 0);
  signal xor_mem_din, xor_mem_dout : std_logic_vector(63 downto 0);

  -- Reed-Solomon / Reed-Muller
  signal rs_start_cw, rs_i_valid, rs_i_end, rs_consume : std_logic;
  signal rs_i_symbol, rs_o_symbol : std_logic_vector(7 downto 0);
  signal rs_o_end, rs_o_error, rs_o_in_ready, rs_o_start, rs_o_valid : std_logic;
  signal rs_k       : integer range 0 to 15 := 0;
  signal rs_cap_n   : integer range 0 to 46 := 0;
  signal rs_cap_on, rs_cap_fin, rs_fin, rs_err : std_logic := '0';
  signal rm_byte    : std_logic_vector(7 downto 0) := (others => '0');
  signal rm_dout    : std_logic_vector(383 downto 0);
  signal rm_i       : integer range 0 to 45 := 0;
  signal rm_t       : integer range 0 to 5 := 0;
  signal rm_addr    : integer range 0 to 276 := 0;
  signal rm_t_d     : integer range 0 to 5 := 0;
  signal rm_addr_d  : integer range 0 to 276 := 0;
  signal rm_v_d     : std_logic := '0';
  signal rm_fl      : integer range 0 to 3 := 0;

begin

  ---------------------------------------------------------------------------
  -- Instancias
  ---------------------------------------------------------------------------
  u_sponge : entity work.keccak_sponge
    generic map (BIG_ENDIAN_WORDS => false)
    port map (clk => clk, rst => rst, abort => abort_req,
              in_valid => sp_in_valid, in_ready => sp_in_ready, in_data => sp_in_data,
              out_valid => sp_out_valid, out_ready => sp_out_ready, out_data => sp_out_data,
              out_last => open);

  u_vect : entity work.sample_vect
    generic map (N => 17669, N_SZ => 2209, ADDR_W => 9)
    port map (clk => clk, rst => rst, start => sv_start,
              din => sp_out_data, din_valid => sv_din_valid, din_ready => sv_din_ready,
              wr_en => sv_wr_en, wr_addr => sv_wr_addr, wr_data => sv_wr_data,
              sample_done => sv_done);

  u_samp : entity work.samplefxwtmod
    generic map (N => 17669, WT => WT_R, SHAKE_BYTE_SWAP => false)
    port map (clk => clk, rst => rst, start => smp_start,
              shake_din => sp_out_data, shake_valid => smp_shake_valid, shake_ready => smp_shake_ready,
              wr_en => smp_wr_en, wr_addr => smp_wr_addr, wr_data => smp_wr_data,
              rd_addr => smp_rd_addr, rd_data => smp_rd_data,
              sample_done => smp_done);

  u_mul : entity work.poly_mul2
    generic map (N => 17669, DUAL => true, POS_W => 15, PA_W => 7, AW => 9, ACC_AW => 10)
    port map (clk => clk, rst => rst, start => mul_start, n_pos => NPOS_R2,
              ready => mul_ready, done => mul_done,
              pos_addr => mul_pos_addr, pos_data => bank_r2_dout,
              dense_addr => dense_addr, dense_a_data => h_mem_rdata, dense_b_data => s_mem_rdata,
              acc_addr1 => acc_addr1, acc_we1 => acc_we1, acc_din1 => acc_din1,
              acc_addr2 => acc_addr2, acc_we2 => acc_we2,
              accA_din2 => accA_din2, accB_din2 => accB_din2,
              accA_dout1 => accA_dout1, accB_dout1 => accB_dout1,
              accA_dout2 => accA_dout2, accB_dout2 => accB_dout2,
              res_we => res_we, res_addr => res_addr, res_a_data => res_a_data, res_b_data => res_b_data);

  u_xor : entity work.sparse_xor
    generic map (POS_W => 15, PA_W => 7, AW => 9)
    port map (clk => clk, rst => rst, start => xor_start, n_pos => xor_npos,
              ready => xor_ready, done => xor_done,
              pos_addr => xor_pos_addr, pos_data => xor_pos_data,
              mem_we => xor_mem_we, mem_addr => xor_mem_addr, mem_din => xor_mem_din, mem_dout => xor_mem_dout);

  u_rs : entity work.rs_encoder
    generic map (N => 46, K => 16, RS_GF => RS_GF_256, TEST_MODE => false)
    port map (clk => clk, rst => rst,
              i_end_codeword => rs_i_end, i_start_codeword => rs_start_cw,
              i_valid => rs_i_valid, i_consume => rs_consume, i_symbol => rs_i_symbol,
              o_end_codeword => rs_o_end, o_error => rs_o_error, o_in_ready => rs_o_in_ready,
              o_start_codeword => rs_o_start, o_valid => rs_o_valid, o_symbol => rs_o_symbol);

  u_rm : entity work.rm_encoder
    generic map (m => 7, rep => 3, generator_matrix_01 => RM_GEN_01)
    port map (data_in => rm_byte, data_out => rm_dout);

  -- bancos de posiciones
  u_bank_r2 : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => we_r2, wr_addr => smp_wr_addr, din => smp_wr_data,
              rd_addr => rd_r2, dout => bank_r2_dout);
  u_bank_e : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => we_e, wr_addr => smp_wr_addr, din => smp_wr_data,
              rd_addr => rd_e, dout => bank_e_dout);
  u_bank_r1 : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => we_r1, wr_addr => smp_wr_addr, din => smp_wr_data,
              rd_addr => rd_r1, dout => bank_r1_dout);

  -- memorias densas (277 palabras): s (de ek), h (sample_vect), u y v (resultados de poly_mul2)
  u_s_mem : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => s_mem_we, waddr => s_mem_waddr, wdata => s_mem_wdata,
              raddr => s_mem_raddr, rdata => s_mem_rdata);
  u_h_mem : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => sv_wr_en, waddr => sv_wr_addr, wdata => sv_wr_data,
              raddr => h_mem_raddr, rdata => h_mem_rdata);
  u_u_mem : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => u_mem_we, waddr => u_mem_waddr, wdata => u_mem_wdata,
              raddr => u_mem_raddr, rdata => u_mem_rdata);
  u_v_mem : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => v_mem_we, waddr => v_mem_waddr, wdata => v_mem_wdata,
              raddr => v_mem_raddr, rdata => v_mem_rdata);
  -- cm = RM(RS(m)): 276 palabras
  u_cm_mem : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => cm_mem_we, waddr => cm_mem_waddr, wdata => cm_mem_wdata,
              raddr => out_mem_addr, rdata => cm_mem_rdata);

  -- acumuladores de poly_mul2 (uno por canal)
  u_acc_a : entity work.ram64_tdp
    generic map (DEPTH => 554, ADDR_W => 10)
    port map (clk => clk,
              we_1 => acc_we1, addr_1 => acc_addr1, din_1 => acc_din1, dout_1 => accA_dout1,
              we_2 => acc_we2, addr_2 => acc_addr2, din_2 => accA_din2, dout_2 => accA_dout2);
  u_acc_b : entity work.ram64_tdp
    generic map (DEPTH => 554, ADDR_W => 10)
    port map (clk => clk,
              we_1 => acc_we1, addr_1 => acc_addr1, din_1 => acc_din1, dout_1 => accB_dout1,
              we_2 => acc_we2, addr_2 => acc_addr2, din_2 => accB_din2, dout_2 => accB_dout2);

  ---------------------------------------------------------------------------
  -- Salidas simples
  ---------------------------------------------------------------------------
  ready       <= '1' when state = S_IDLE else '0';
  key_ready   <= '1' when state = S_KEY else '0';
  done        <= '1' when state = S_DONE else '0';
  cycles      <= cycles_r;
  cycles_core <= cycles_core_r;
  err         <= rs_err;
  dbg_state   <= std_logic_vector(to_unsigned(state_t'pos(state), 4));

  ---------------------------------------------------------------------------
  -- RUTEO (phase): salida del sponge y bancos de posiciones
  ---------------------------------------------------------------------------
  sp_out_ready <= '1'             when phase = PH_STORE else
                  sv_din_ready    when phase = PH_H     else
                  smp_shake_ready when (phase = PH_R2 or phase = PH_E or phase = PH_R1) else
                  '0';
  sv_din_valid    <= sp_out_valid when phase = PH_H else '0';
  smp_shake_valid <= sp_out_valid when (phase = PH_R2 or phase = PH_E or phase = PH_R1) else '0';

  we_r2 <= smp_wr_en when phase = PH_R2 else '0';
  we_e  <= smp_wr_en when phase = PH_E  else '0';
  we_r1 <= smp_wr_en when phase = PH_R1 else '0';

  rd_r2 <= smp_rd_addr when phase = PH_R2 else mul_pos_addr;      -- r2: sampler (limpieza) o poly_mul2
  rd_e  <= smp_rd_addr when phase = PH_E  else xor_pos_addr;      -- e : sampler (limpieza) o sparse_xor
  rd_r1 <= smp_rd_addr when phase = PH_R1 else xor_pos_addr;      -- r1: sampler (limpieza) o sparse_xor

  smp_rd_data <= bank_r2_dout when phase = PH_R2 else
                 bank_e_dout  when phase = PH_E  else
                 bank_r1_dout;

  xor_pos_data <= bank_r1_dout when xor_sel = '0' else bank_e_dout;
  xor_npos     <= NPOS_R1      when xor_sel = '0' else NPOS_E;
  xor_mem_dout <= u_mem_rdata  when xor_sel = '0' else v_mem_rdata;

  ---------------------------------------------------------------------------
  -- Memorias densas
  --   s : escribe la ingesta (S_KEY) ; lee el alimentador del sponge (hash de ek) o poly_mul2 (canal B)
  --   h : escribe sample_vect ; lee poly_mul2 (canal A)
  --   u : escribe poly_mul2 (canal A) o sparse_xor (r1) ; lee sparse_xor o la salida
  --   v : escribe poly_mul2 (canal B) o sparse_xor (e)  ; lee sparse_xor o la salida
  ---------------------------------------------------------------------------
  s_mem_we    <= '1' when (state = S_KEY and key_valid = '1' and key_idx >= 4 and key_idx <= EK_MSG_LAST) else '0';
  s_mem_waddr <= to_unsigned(key_idx - 4, 9) when key_idx >= 4 else (others => '0');
  s_mem_wdata <= (key_data and LAST_MASK) when key_idx = EK_MSG_LAST else key_data;   -- bits >= N a 0
  s_mem_raddr <= dense_addr when state = S_MUL else feed_s_addr;
  feed_s_addr <= to_unsigned(fidx - 4, 9) when fidx >= 4 else (others => '0');
  h_mem_raddr <= dense_addr;

  u_mem_we    <= res_we when state = S_MUL else
                 xor_mem_we when (state = S_XOR and xor_sel = '0') else '0';
  u_mem_waddr <= res_addr when state = S_MUL else xor_mem_addr;
  u_mem_wdata <= res_a_data when state = S_MUL else xor_mem_din;
  u_mem_raddr <= xor_mem_addr when state = S_XOR else out_mem_addr;

  v_mem_we    <= res_we when state = S_MUL else
                 xor_mem_we when (state = S_XOR and xor_sel = '1') else '0';
  v_mem_waddr <= res_addr when state = S_MUL else xor_mem_addr;
  v_mem_wdata <= res_b_data when state = S_MUL else xor_mem_din;
  v_mem_raddr <= xor_mem_addr when state = S_XOR else out_mem_addr;

  ---------------------------------------------------------------------------
  -- Alimentador del sponge: comando + palabras del mensaje (fidx = 0 .. f_last)
  ---------------------------------------------------------------------------
  sp_in_valid <= '1' when (fs = FS_CMD or fs = FS_SEND) else '0';

  process(fs, f_cmd, f_src, fidx, ek_seed_r, tmp_h_r, m_r, salt_r, theta_r, s_mem_rdata)
  begin
    sp_in_data <= ZERO64;
    if fs = FS_CMD then
      sp_in_data <= f_cmd;
    else
      case f_src is
        when SRC_EK =>                    -- ek || 01 : seed_ek (4) + s (277); el 01 va en el byte 1 de la ultima
          if fidx < 4 then
            sp_in_data <= ek_seed_r(fidx);
          elsif fidx = EK_MSG_LAST then
            sp_in_data <= s_mem_rdata or x"0000000000000100";
          else
            sp_in_data <= s_mem_rdata;
          end if;
        when SRC_G =>                     -- tmp_h || m || salt || 00
          if fidx < 4 then
            sp_in_data <= tmp_h_r(fidx);
          elsif fidx < 6 then
            sp_in_data <= m_r(fidx - 4);
          elsif fidx < 8 then
            sp_in_data <= salt_r(fidx - 6);
          else
            sp_in_data <= ZERO64;         -- byte de dominio 00
          end if;
        when SRC_SEED_EK =>               -- seed_ek || 01
          if fidx < 4 then
            sp_in_data <= ek_seed_r(fidx);
          else
            sp_in_data <= DOM01;
          end if;
        when SRC_THETA =>                 -- theta || 01
          if fidx < 4 then
            sp_in_data <= theta_r(fidx);
          else
            sp_in_data <= DOM01;
          end if;
      end case;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        fs   <= FS_IDLE;
        fidx <= 0;
      else
        case fs is
          when FS_IDLE =>
            if f_go = '1' then
              fs <= FS_CMD;
            end if;
          when FS_CMD =>
            if sp_in_ready = '1' then
              fidx <= 0;
              fs   <= FS_WAIT;
            end if;
          when FS_WAIT =>                         -- 1 ciclo: la RAM s presenta el dato
            fs <= FS_SEND;
          when FS_SEND =>
            if sp_in_ready = '1' then
              if fidx = f_last then
                fs <= FS_IDLE;
              else
                fidx <= fidx + 1;
                fs   <= FS_WAIT;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Codificador RS + RM (motor independiente: rs_go -> rs_fin)
  --   RS : entra m[15] .. m[0] (un simbolo por ciclo), salen los 46 simbolos -> cw_r
  --   RM : por cada simbolo cw_r(i), 6 palabras de 64 bits a la RAM cm (cm[6i+t])
  ---------------------------------------------------------------------------
  rs_consume  <= '1';
  rs_i_valid  <= '1' when rs_fs = RS_FEED else '0';
  rs_i_end    <= '1' when (rs_fs = RS_FEED and rs_k = 15) else '0';
  rs_start_cw <= '1' when ((RS_START_OVERLAP and rs_fs = RS_FEED and rs_k = 0) or
                           ((not RS_START_OVERLAP) and rs_fs = RS_PRE)) else '0';
  rs_i_symbol <= byte_of(m_r((15 - rs_k) / 8), (15 - rs_k) mod 8);   -- m[15 - k]

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rs_fs      <= RS_IDLE;
        rs_k       <= 0;
        rs_cap_n   <= 0;
        rs_cap_on  <= '0';
        rs_cap_fin <= '0';
        rs_fin     <= '0';
        rs_err     <= '0';
        rm_v_d     <= '0';
        cm_mem_we  <= '0';
      else
        -- etapa B del pipeline RM: la salida combinacional del RM (sobre rm_byte) pasa a la RAM
        rm_v_d       <= '0';
        cm_mem_we    <= rm_v_d;
        cm_mem_waddr <= to_unsigned(rm_addr_d, 9);
        cm_mem_wdata <= rm_slice(rm_dout, rm_t_d);

        if start = '1' and state = S_IDLE then
          rs_err <= '0';
        end if;
        if rs_o_error = '1' then
          rs_err <= '1';
        end if;

        -- captura de los 46 simbolos emitidos por el RS
        if rs_o_start = '1' then
          if RS_OUT_REVERSED then
            cw_r(45) <= rs_o_symbol;
          else
            cw_r(0) <= rs_o_symbol;
          end if;
          rs_cap_n  <= 1;
          rs_cap_on <= '1';
        elsif rs_cap_on = '1' and rs_o_valid = '1' then
          if rs_cap_n <= 45 then
            if RS_OUT_REVERSED then
              cw_r(45 - rs_cap_n) <= rs_o_symbol;
            else
              cw_r(rs_cap_n) <= rs_o_symbol;
            end if;
          else
            rs_err <= '1';                          -- mas de 46 simbolos
          end if;
          if rs_o_end = '1' then
            rs_cap_on  <= '0';
            rs_cap_fin <= '1';
            if rs_cap_n /= 45 then
              rs_err <= '1';                        -- el codeword no tuvo 46 simbolos
            end if;
          else
            if rs_cap_n < 46 then
              rs_cap_n <= rs_cap_n + 1;
            end if;
          end if;
        end if;

        case rs_fs is

          when RS_IDLE =>
            if rs_go = '1' then
              rs_fin     <= '0';
              rs_cap_fin <= '0';
              rs_k       <= 0;
              if RS_START_OVERLAP then
                rs_fs <= RS_FEED;
              else
                rs_fs <= RS_PRE;
              end if;
            end if;

          when RS_PRE =>                            -- solo si i_start_codeword va un ciclo antes
            rs_fs <= RS_FEED;

          when RS_FEED =>                           -- rs_i_valid = '1': un simbolo por ciclo
            if rs_k = 15 then
              rs_fs <= RS_CAPT;
            else
              rs_k <= rs_k + 1;
            end if;

          when RS_CAPT =>                           -- esperar o_end_codeword (ultimo simbolo capturado)
            if rs_cap_fin = '1' then
              rs_cap_fin <= '0';
              rm_i       <= 0;
              rm_t       <= 0;
              rm_addr    <= 0;
              rs_fs      <= RM_WR;
            end if;

          when RM_WR =>                             -- etapa A: 1 palabra de cm por ciclo
            rm_byte   <= cw_r(rm_i);
            rm_t_d    <= rm_t;
            rm_addr_d <= rm_addr;
            rm_v_d    <= '1';
            rm_addr   <= rm_addr + 1;
            if rm_t = 5 then
              rm_t <= 0;
              if rm_i = 45 then
                rm_fl <= 0;
                rs_fs <= RM_FLUSH;
              else
                rm_i <= rm_i + 1;
              end if;
            else
              rm_t <= rm_t + 1;
            end if;

          when RM_FLUSH =>                          -- vaciar el pipeline (3 ciclos) y avisar
            if rm_fl = 2 then
              rs_fin <= '1';
              rs_fs  <= RS_IDLE;
            else
              rm_fl <= rm_fl + 1;
            end if;

        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Etapa de salida (segun OUT_SEQ). v sale como v_mem xor cm.
  ---------------------------------------------------------------------------
  out_mem_addr <= to_unsigned(ok, 9);

  process(part_i, ok, ss_r, salt_r, v_mem_rdata, cm_mem_rdata, u_mem_rdata)
  begin
    out_data <= (others => '0');
    case OUT_SEQ(part_i) is
      when SEG_SS =>
        out_data <= ss_r(ok mod 4);
      when SEG_V =>
        out_data <= v_mem_rdata xor cm_mem_rdata;
      when SEG_U =>
        out_data <= u_mem_rdata;
      when others =>
        out_data <= salt_r(ok mod 2);
    end case;
  end process;

  out_valid <= '1' when state = S_O_SEND else '0';
  out_last  <= '1' when (state = S_O_SEND and ok = seg_last_word(OUT_SEQ(part_i))) else '0';
  out_part  <= std_logic_vector(to_unsigned(OUT_SEQ(part_i), 2));

  ---------------------------------------------------------------------------
  -- FSM maestra (state)
  ---------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state        <= S_IDLE;
        phase        <= PH_NONE;
        step         <= 0;
        key_idx      <= 0;
        samp_n       <= 0;
        xor_sel      <= '0';
        cap_cnt      <= 0;
        running      <= '0';
        core_running <= '0';
        part_i       <= 0;
        ok           <= 0;
        f_go         <= '0';
        sv_start     <= '0';
        smp_start    <= '0';
        mul_start    <= '0';
        xor_start    <= '0';
        abort_req    <= '0';
        rs_go        <= '0';
      else
        -- pulsos: por defecto a 0; valen '1' durante UN ciclo cuando se asignan
        f_go      <= '0';
        sv_start  <= '0';
        smp_start <= '0';
        mul_start <= '0';
        xor_start <= '0';
        abort_req <= '0';
        rs_go     <= '0';

        if running = '1' then
          cyc <= cyc + 1;
        end if;
        if core_running = '1' then
          cyc_core <= cyc_core + 1;
        end if;

        -- STORE: captura de la salida del sponge (out_ready = '1' en PH_STORE)
        if state = S_STORE and sp_out_valid = '1' then
          if store_sel = 0 then
            if cap_cnt < 4 then
              tmp_h_r(cap_cnt) <= sp_out_data;
            end if;
          else
            if cap_cnt < 4 then
              ss_r(cap_cnt) <= sp_out_data;
            elsif cap_cnt < 8 then
              theta_r(cap_cnt - 4) <= sp_out_data;
            end if;
          end if;
          cap_cnt <= cap_cnt + 1;
        end if;

        case state is

          when S_IDLE =>
            if start = '1' then
              key_idx <= 0;
              cyc     <= (others => '0');
              running <= '1';
              state   <= S_KEY;
            end if;

          -- ingesta: 0..3 seed_ek | 4..280 s (RAM s, por logica combinacional) | 281..282 m | 283..284 salt
          when S_KEY =>                                     -- key_ready = '1'
            if key_valid = '1' then
              if key_idx < 4 then
                ek_seed_r(key_idx) <= key_data;
              elsif key_idx <= EK_MSG_LAST then
                null;                                       -- escribe la RAM s (s_mem_we)
              elsif key_idx <= 282 then
                m_r(key_idx - 281) <= key_data;
              else
                salt_r(key_idx - 283) <= key_data;
              end if;
              if key_idx = KEY_LAST then
                step         <= 1;
                rs_go        <= '1';                        -- el RS/RM corre en paralelo
                cyc_core     <= (others => '0');
                core_running <= '1';
                state        <= S_LAUNCH;
              else
                key_idx <= key_idx + 1;
              end if;
            end if;

          when S_LAUNCH =>                                  -- lanza el comando 'step'
            f_go <= '1';
            case step is
              when 1 =>                                     -- SHA3-256(ek||01) -> tmp_h
                f_cmd <= CMD_HASH_EK; f_src <= SRC_EK; f_last <= EK_MSG_LAST;
                store_sel <= 0; cap_total <= 4; cap_cnt <= 0;
                phase <= PH_STORE; state <= S_STORE;
              when 2 =>                                     -- SHA3-512(tmp_h||m||salt||00) -> ss, theta
                f_cmd <= CMD_G; f_src <= SRC_G; f_last <= 8;
                store_sel <= 1; cap_total <= 8; cap_cnt <= 0;
                phase <= PH_STORE; state <= S_STORE;
              when 3 =>                                     -- SHAKE256(seed_ek||01), 2216 B -> sample_vect
                f_cmd <= CMD_H; f_src <= SRC_SEED_EK; f_last <= 4;
                sv_start <= '1';
                phase <= PH_H; state <= S_H;
              when others =>                                -- SHAKE256(theta||01) sin limite -> r2, e, r1
                f_cmd <= CMD_THETA; f_src <= SRC_THETA; f_last <= 4;
                smp_start <= '1';
                samp_n <= 0;
                phase <= PH_R2; state <= S_SAMP;
            end case;

          when S_STORE =>
            if cap_cnt = cap_total then
              step  <= step + 1;
              state <= S_LAUNCH;
            end if;

          when S_H =>
            if sv_done = '1' then
              step  <= 4;
              state <= S_LAUNCH;
            end if;

          when S_SAMP =>                                    -- tres llamadas seguidas al sampler: r2, e, r1
            if smp_done = '1' then
              if samp_n = 2 then
                abort_req <= '1';                           -- r1 listo: cortar el flujo del sponge
                phase     <= PH_NONE;
                state     <= S_JOIN;
              else
                samp_n    <= samp_n + 1;
                smp_start <= '1';
                if samp_n = 0 then
                  phase <= PH_E;
                else
                  phase <= PH_R1;
                end if;
              end if;
            end if;

          when S_JOIN =>                                    -- RS/RM listo y poly_mul2 libre
            if rs_fin = '1' and mul_ready = '1' then
              mul_start <= '1';
              state     <= S_MUL;
            end if;

          when S_MUL =>                                     -- u = r2*h  y  v = r2*s
            if mul_done = '1' then
              xor_sel <= '0';
              state   <= S_XSTART;
            end if;

          when S_XSTART =>                                  -- xor_sel '0': u xor r1 ; '1': v xor e
            if xor_ready = '1' then
              xor_start <= '1';
              state     <= S_XOR;
            end if;

          when S_XOR =>
            if xor_done = '1' then
              if xor_sel = '0' then
                xor_sel <= '1';
                state   <= S_XSTART;
              else
                running        <= '0';
                core_running   <= '0';
                cycles_r       <= cyc;
                cycles_core_r  <= cyc_core;
                part_i         <= 0;
                ok             <= 0;
                state          <= S_O_ADDR;
              end if;
            end if;

          when S_O_ADDR =>                                  -- direccion presentada; dato valido en S_O_SEND
            state <= S_O_SEND;

          when S_O_SEND =>                                  -- out_valid = '1'
            if out_ready = '1' then
              if ok = seg_last_word(OUT_SEQ(part_i)) then
                if part_i = 3 then
                  state <= S_DONE;
                else
                  part_i <= part_i + 1;
                  ok     <= 0;
                  state  <= S_O_ADDR;
                end if;
              else
                ok    <= ok + 1;
                state <= S_O_ADDR;
              end if;
            end if;

          when S_DONE =>
            phase <= PH_NONE;
            state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;
