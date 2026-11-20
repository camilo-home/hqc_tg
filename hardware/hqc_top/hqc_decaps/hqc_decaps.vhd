-- ============================================================================
-- hqc_decaps : HQC-128 Decaps (KEM)  -  ss = (re-cifrado coincide) ? kk' : k_rej
--
--   entrada dk  (dk_valid/dk_ready/dk_data), 291 palabras de 64 bits = EXACTAMENTE la salida del keygen:
--                 0..280   ek  (seed_ek 32 B || s 2209 B, relleno a 0)
--                 281..284 seed_dk (32 B)      285..286 sigma (16 B)      287..290 seed_kem (32 B, se ignora)
--   entrada ct  (ct_valid/ct_ready/ct_data), 555 palabras, partes alineadas a palabra, orden u | v | salt:
--                 0..276   u (2209 B; la palabra 276 solo lleva 1 byte, relleno a 0)
--                 277..552 v (2208 B)          553..554 salt (16 B)
--   dk y ct se ingieren a la vez (dos puertos independientes). start (pulso) solo con ready='1'.
--   salida  : ss (32 B) en 4 palabras por out_valid/out_ready; out_last en la ultima. done = pulso al terminar.
--   Bytes en palabras: byte 0 en los bits [7:0] (igual que el sponge).
--
-- Una micro-operacion a la vez (como keygen/encaps), con las ESPERAS solapadas con la ingesta:
--   S_INGEST  dk: las 281 palabras de ek se REENVIAN al puerto key_* de hqc_encaps (que las guarda y espera
--             m' y salt); seed_dk y sigma a registros. ct: u -> RAM ct_u, v -> RAM ct_v, salt -> registros.
--   S_Y       SHAKE256(seed_dk||01), sin limite -> sampler rej -> y (66 posiciones); abort al terminar
--   S_MUL     poly_mul2 (DUAL=false): res = y*u
--   S_DEC     cm = v xor res (al vuelo, 6 palabras por bloque, bloques 45..0) -> rm_decoder -> 46 simbolos
--             -> rs_decoder (entra cw[45]..cw[0]) -> m' (los 16 primeros simbolos son m[15]..m[0])
--   S_INJ     m' (2 palabras) y salt (2) al puerto key_* de hqc_encaps: re-cifrado completo (tmp_h, SHA3-512,
--             h, r2/e/r1, poly_mul2, sparse_xor, RS/RM)
--   S_REENC   se consume la salida de hqc_encaps (ss'|u'|v'|salt' en el orden de su OUT_SEQ, identificado por
--             out_part) y se compara palabra a palabra con el ct recibido (sin salida anticipada).
--             u[276] solo compara el byte bajo (el resto de la palabra es relleno).
--   S_KREJ    k_rej = SHA3-256(tmp_h || sigma || ct || 03), 4482 B. ct = u||v||salt como BYTES continuos:
--             un realineador de bytes (acumulador de 15 B) une los trozos (u acaba en el byte 2208).
--   S_OUT     ss = match ? kk' : k_rej
--
-- cycles      : ciclos desde start hasta tener ss listo (incluye la ingesta)
-- cycles_core : igual pero desde el fin de la ingesta
-- match       : '1' si el re-cifrado coincidio (valido desde S_KREJ)
-- err         : pegajoso, error del RS (decoder o encoder del re-cifrado); con ct corrupto puede ser '1' y
--               aun asi ss = k_rej es el resultado correcto
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.keccak_sponge_pkg.all;

entity hqc_decaps is
  generic(
    RM_GEN_01         : boolean := false;  -- generator_matrix_01 de rm_encoder/rm_decoder (HQC: false); mismo valor en ambos
    RS_OUT_REVERSED   : boolean := true;   -- rs_encoder del re-cifrado (ver hqc_encaps)
    RS_START_OVERLAP  : boolean := true;   -- rs_encoder: i_start_codeword coincide con el 1er simbolo
    RSD_START_OVERLAP : boolean := true;   -- rs_decoder: idem
    RSD_FCR           : natural := 1;      -- primera raiz consecutiva (HQC: alpha^1 .. alpha^30)
    RSD_PRIM_POLY     : natural := 285     -- 0x11D
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
  constant DK_EK_WORDS  : integer := 281;
  constant DK_WORDS     : integer := 291;
  constant CT_V_BASE    : integer := 277;
  constant CT_SALT_BASE : integer := 553;
  constant CT_WORDS     : integer := 555;
  constant U_LAST       : integer := 276;

  constant CMD_SEED_DK : std_logic_vector(63 downto 0) := make_cmd_stream(MODE_SHAKE256, 33);
  constant CMD_KREJ    : std_logic_vector(63 downto 0) := make_cmd(MODE_SHA3_256, 4482, 0);

  constant ZERO64    : std_logic_vector(63 downto 0) := (others => '0');
  constant DOM01     : std_logic_vector(63 downto 0) := x"0000000000000001";
  constant DOM03     : std_logic_vector(63 downto 0) := x"0000000000000003";
  constant LAST_MASK : std_logic_vector(63 downto 0) := x"000000000000001F";   -- N mod 64 = 5 bits
  constant NPOS_Y    : unsigned(6 downto 0) := to_unsigned(66, 7);

  -- --------------------------------------------------------------------------
  -- Tipos
  -- --------------------------------------------------------------------------
  type state_t is (S_IDLE, S_INGEST, S_Y, S_MULW, S_MUL, S_DEC, S_INJ, S_REENC, S_KREJ, S_OUT, S_DONE);
  type fs_t    is (FS_IDLE, FS_CMD, FS_SEND);
  type kf_t    is (KF_IDLE, KF_CMD, KF_ADDR, KF_WAIT, KF_PUSH, KF_SEND, KF_FLUSH);
  type dm_t    is (DM_IDLE, DM_FETCH, DM_PUSH, DM_END);
  type rf_t    is (RF_IDLE, RF_WAIT, RF_PRE, RF_FEED, RF_CAPT);

  type words4_t  is array (0 to 3)  of std_logic_vector(63 downto 0);
  type words2_t  is array (0 to 1)  of std_logic_vector(63 downto 0);
  type bytes46_t is array (0 to 45) of std_logic_vector(7 downto 0);
  type bytes16_t is array (0 to 15) of std_logic_vector(7 downto 0);

  -- palabra w (0 o 1) de m': bytes 8w .. 8w+7, el byte 8w en los bits [7:0]
  function pack_word(b : bytes16_t; w : integer) return std_logic_vector is
    variable r : std_logic_vector(63 downto 0);
  begin
    for j in 0 to 7 loop
      r(8*j + 7 downto 8*j) := b(8*w + j);
    end loop;
    return r;
  end function;

  function tmp_h_word(t : std_logic_vector(255 downto 0); i : integer) return std_logic_vector is
  begin
    case i is
      when 0      => return t(63 downto 0);
      when 1      => return t(127 downto 64);
      when 2      => return t(191 downto 128);
      when others => return t(255 downto 192);
    end case;
  end function;

  -- trozos del mensaje de k_rej: 0 tmp_h(4) 1 sigma(2) 2 u(277: 276 de 8 B + 1 de 1 B) 3 v(276) 4 salt(2) 5 dom 03 (1)
  function seg_len(s : integer) return integer is
  begin
    case s is
      when 0      => return 4;
      when 1      => return 2;
      when 2      => return 277;
      when 3      => return 276;
      when 4      => return 2;
      when others => return 1;
    end case;
  end function;

  -- --------------------------------------------------------------------------
  -- Senales
  -- --------------------------------------------------------------------------
  signal state : state_t := S_IDLE;
  signal fs    : fs_t := FS_IDLE;
  signal kf    : kf_t := KF_IDLE;
  signal dm_s  : dm_t := DM_IDLE;
  signal rf    : rf_t := RF_IDLE;

  -- valores pequenos con nombre propio
  signal seed_dk_r : words4_t := (others => (others => '0'));
  signal sigma_r   : words2_t := (others => (others => '0'));
  signal salt_r    : words2_t := (others => (others => '0'));
  signal kkp_r     : words4_t := (others => (others => '0'));   -- kk' (ss' del re-cifrado)
  signal krej_r    : words4_t := (others => (others => '0'));   -- k_rej
  signal mp_r      : bytes16_t := (others => (others => '0'));  -- m' (byte j = m'[j])
  signal rs_buf    : bytes46_t := (others => (others => '0'));  -- simbolos del RM en orden de llegada (cw[45]..cw[0])
  signal u_last_raw: std_logic_vector(7 downto 0) := (others => '0');   -- byte 2208 de u tal cual llego

  -- contadores
  signal dk_idx    : integer range 0 to DK_WORDS := 0;
  signal ct_idx    : integer range 0 to CT_WORDS := 0;
  signal inj_idx   : integer range 0 to 3 := 0;
  signal cap_cnt   : integer range 0 to 4 := 0;
  signal out_i     : integer range 0 to 3 := 0;
  signal cmp_idx   : integer range 0 to 276 := 0;
  signal cmp_rd_ok : std_logic := '0';
  signal cmp_bad   : std_logic := '0';

  -- pulsos de un ciclo
  signal enc_start, smp_start, f_go, kf_go, mul_start, abort_req, dec_go : std_logic := '0';

  -- contadores de ciclos
  signal running, core_running : std_logic := '0';
  signal cyc, cyc_core, cycles_r, cycles_core_r : unsigned(31 downto 0) := (others => '0');

  signal rst_n : std_logic;
  signal ready_i, dk_ready_i, ct_ready_i, out_valid_i : std_logic;

  -- hqc_encaps (re-cifrado)
  signal enc_ready, enc_done, enc_err : std_logic;
  signal enc_key_valid, enc_key_ready : std_logic;
  signal enc_key_data, inj_word : std_logic_vector(63 downto 0);
  signal enc_out_valid, enc_out_ready, enc_out_last : std_logic;
  signal enc_out_data : std_logic_vector(63 downto 0);
  signal enc_out_part : std_logic_vector(1 downto 0);
  signal enc_tmp_h : std_logic_vector(255 downto 0);

  -- sponge propio (y, k_rej)
  signal sp_in_valid, sp_in_ready, sp_out_valid, sp_out_ready : std_logic;
  signal sp_in_data, sp_out_data : std_logic_vector(63 downto 0);

  -- alimentador de y: SHAKE256(seed_dk||01)
  signal fs_valid : std_logic;
  signal fs_data  : std_logic_vector(63 downto 0);
  signal fidx     : integer range 0 to 4 := 0;

  -- sampler rej + banco de posiciones de y
  signal rej_shake_valid, rej_shake_ready, smp_wr_en, smp_done : std_logic;
  signal smp_wr_addr, smp_rd_addr, rd_y : unsigned(6 downto 0);
  signal smp_wr_data, smp_rd_data, bank_y_dout : unsigned(14 downto 0);

  -- memorias densas: ct_u, ct_v (entrada), res (y*u)
  signal ctu_we, ctv_we : std_logic;
  signal ctu_waddr, ctv_waddr, ctu_raddr, ctv_raddr : unsigned(8 downto 0);
  signal ctu_wdata, ctv_wdata, ctu_rdata, ctv_rdata : std_logic_vector(63 downto 0);
  signal res_we : std_logic;
  signal res_addr, res_raddr : unsigned(8 downto 0);
  signal res_a_data, res_rdata : std_logic_vector(63 downto 0);

  -- poly_mul2 (DUAL = false)
  signal mul_ready, mul_done : std_logic;
  signal mul_pos_addr : unsigned(6 downto 0);
  signal dense_addr : unsigned(8 downto 0);
  signal acc_addr1, acc_addr2 : unsigned(9 downto 0);
  signal acc_we1, acc_we2 : std_logic;
  signal acc_din1, accA_din2, accA_dout1, accA_dout2 : std_logic_vector(63 downto 0);

  -- decodificacion: motor de bloques RM
  signal dm_i      : integer range 0 to 45 := 0;
  signal dm_t      : integer range 0 to 6 := 0;
  signal dm_addr   : unsigned(8 downto 0);
  signal dm_word   : std_logic_vector(63 downto 0);
  signal dm_blk    : std_logic_vector(383 downto 0) := (others => '0');
  signal rm_in_valid, rm_in_ready, rm_out_valid : std_logic;
  signal rm_out_data : std_logic_vector(7 downto 0);
  signal rm_n      : integer range 0 to 46 := 0;
  signal rm_all    : std_logic := '0';

  -- decodificacion: RS
  signal rf_k      : integer range 0 to 45 := 0;
  signal rsd_k     : integer range 0 to 16 := 0;
  signal dec_fin, err_dec : std_logic := '0';
  signal rsd_i_valid, rsd_i_end, rsd_i_start, rsd_i_consume : std_logic;
  signal rsd_i_symbol, rsd_o_symbol : std_logic_vector(7 downto 0);
  signal rsd_o_in_ready, rsd_o_end, rsd_o_start, rsd_o_valid, rsd_o_error : std_logic;

  -- k_rej: alimentador con realineador de bytes
  signal kseg    : integer range 0 to 5 := 0;
  signal koff    : integer range 0 to 276 := 0;
  signal k_acc   : std_logic_vector(119 downto 0) := (others => '0');
  signal k_cnt   : integer range 0 to 15 := 0;
  signal k_chunk : std_logic_vector(63 downto 0);
  signal k_chunk_n : integer range 1 to 8;
  signal kf_valid : std_logic;

begin

  ---------------------------------------------------------------------------
  -- Instancias
  ---------------------------------------------------------------------------
  rst_n <= not rst;

  u_enc : entity work.hqc_encaps
    generic map (RS_OUT_REVERSED => RS_OUT_REVERSED, RS_START_OVERLAP => RS_START_OVERLAP, RM_GEN_01 => RM_GEN_01)
    port map (clk => clk, rst => rst, start => enc_start, ready => enc_ready, done => enc_done,
              key_valid => enc_key_valid, key_ready => enc_key_ready, key_data => enc_key_data,
              out_valid => enc_out_valid, out_ready => enc_out_ready, out_data => enc_out_data,
              out_last => enc_out_last, out_part => enc_out_part,
              cycles => open, cycles_core => open, err => enc_err, dbg_state => open,
              tmp_h => enc_tmp_h);

  u_sponge : entity work.keccak_sponge
    generic map (BIG_ENDIAN_WORDS => false)
    port map (clk => clk, rst => rst, abort => abort_req,
              in_valid => sp_in_valid, in_ready => sp_in_ready, in_data => sp_in_data,
              out_valid => sp_out_valid, out_ready => sp_out_ready, out_data => sp_out_data,
              out_last => open);

  u_rej : entity work.samplefxwtrej
    generic map (N => 17669, N_32 => 243079, WT => 66, SHAKE_BYTE_SWAP => false)
    port map (clk => clk, rst => rst, start => smp_start,
              shake_din => sp_out_data, shake_valid => rej_shake_valid, shake_ready => rej_shake_ready,
              wr_en => smp_wr_en, wr_addr => smp_wr_addr, wr_data => smp_wr_data,
              rd_addr => smp_rd_addr, rd_data => smp_rd_data,
              sample_done => smp_done);

  u_bank_y : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => smp_wr_en, wr_addr => smp_wr_addr, din => smp_wr_data,
              rd_addr => rd_y, dout => bank_y_dout);

  u_mul : entity work.poly_mul2
    generic map (N => 17669, DUAL => false, POS_W => 15, PA_W => 7, AW => 9, ACC_AW => 10)
    port map (clk => clk, rst => rst, start => mul_start, n_pos => NPOS_Y,
              ready => mul_ready, done => mul_done,
              pos_addr => mul_pos_addr, pos_data => bank_y_dout,
              dense_addr => dense_addr, dense_a_data => ctu_rdata, dense_b_data => ZERO64,
              acc_addr1 => acc_addr1, acc_we1 => acc_we1, acc_din1 => acc_din1,
              acc_addr2 => acc_addr2, acc_we2 => acc_we2,
              accA_din2 => accA_din2, accB_din2 => open,
              accA_dout1 => accA_dout1, accB_dout1 => ZERO64,
              accA_dout2 => accA_dout2, accB_dout2 => ZERO64,
              res_we => res_we, res_addr => res_addr, res_a_data => res_a_data, res_b_data => open);

  u_acc : entity work.ram64_tdp
    generic map (DEPTH => 554, ADDR_W => 10)
    port map (clk => clk,
              we_1 => acc_we1, addr_1 => acc_addr1, din_1 => acc_din1, dout_1 => accA_dout1,
              we_2 => acc_we2, addr_2 => acc_addr2, din_2 => accA_din2, dout_2 => accA_dout2);

  u_ctu_mem : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => ctu_we, waddr => ctu_waddr, wdata => ctu_wdata,
              raddr => ctu_raddr, rdata => ctu_rdata);
  u_ctv_mem : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => ctv_we, waddr => ctv_waddr, wdata => ctv_wdata,
              raddr => ctv_raddr, rdata => ctv_rdata);
  u_res_mem : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => res_we, waddr => res_addr, wdata => res_a_data,
              raddr => res_raddr, rdata => res_rdata);

  u_rmdec : entity work.rm_decoder
    generic map (m => 7, rep => 3, generator_matrix_01 => RM_GEN_01)
    port map (clock => clk, reset_n => rst_n,
              in_valid => rm_in_valid, in_ready => rm_in_ready, data_in => dm_blk,
              out_valid => rm_out_valid, out_ready => '1', data_out => rm_out_data);

  u_rsd : entity work.rs_decoder
    generic map (N => 46, K => 16, OUTPUT_PARITY_SYMBOLS => false, FCR => RSD_FCR, PRIMITIVE_POLYNOMIAL => RSD_PRIM_POLY)
    port map (clk => clk, rst => rst,
              i_end_codeword => rsd_i_end, i_start_codeword => rsd_i_start,
              i_valid => rsd_i_valid, i_consume => rsd_i_consume, i_symbol => rsd_i_symbol,
              o_in_ready => rsd_o_in_ready, o_end_codeword => rsd_o_end, o_start_codeword => rsd_o_start,
              o_valid => rsd_o_valid, o_error => rsd_o_error, o_symbol => rsd_o_symbol);

  ---------------------------------------------------------------------------
  -- Salidas simples
  ---------------------------------------------------------------------------
  ready_i      <= '1' when (state = S_IDLE and enc_ready = '1') else '0';
  ready        <= ready_i;
  done         <= '1' when state = S_DONE else '0';
  match        <= not cmp_bad;
  err          <= err_dec or enc_err;
  cycles       <= cycles_r;
  cycles_core  <= cycles_core_r;
  dbg_state    <= std_logic_vector(to_unsigned(state_t'pos(state), 4));

  ---------------------------------------------------------------------------
  -- Ingesta
  --   dk: palabras 0..280 (ek) -> puerto key_* de hqc_encaps ; 281..290 -> registros / se ignoran
  --   ct: 0..276 u (RAM, la ultima enmascarada a 5 bits para poly_mul2) ; 277..552 v ; 553..554 salt
  ---------------------------------------------------------------------------
  dk_ready_i <= enc_key_ready when (state = S_INGEST and dk_idx < DK_EK_WORDS) else
                '1'           when (state = S_INGEST and dk_idx < DK_WORDS)    else '0';
  dk_ready   <= dk_ready_i;
  ct_ready_i <= '1' when (state = S_INGEST and ct_idx < CT_WORDS) else '0';
  ct_ready   <= ct_ready_i;

  ctu_we    <= '1' when (state = S_INGEST and ct_valid = '1' and ct_idx < CT_V_BASE) else '0';
  ctu_waddr <= to_unsigned(ct_idx, 9) when ct_idx < CT_V_BASE else (others => '0');
  ctu_wdata <= (ct_data and LAST_MASK) when ct_idx = U_LAST else ct_data;

  ctv_we    <= '1' when (state = S_INGEST and ct_valid = '1' and ct_idx >= CT_V_BASE and ct_idx < CT_SALT_BASE) else '0';
  ctv_waddr <= to_unsigned(ct_idx - CT_V_BASE, 9) when (ct_idx >= CT_V_BASE and ct_idx < CT_SALT_BASE) else (others => '0');
  ctv_wdata <= ct_data;

  -- puerto key_* de hqc_encaps: ek reenviado (S_INGEST), luego m' y salt (S_INJ)
  enc_key_valid <= dk_valid when (state = S_INGEST and dk_idx < DK_EK_WORDS) else
                   '1'      when state = S_INJ else '0';
  enc_key_data  <= dk_data when state = S_INGEST else inj_word;

  process(inj_idx, mp_r, salt_r)
  begin
    case inj_idx is
      when 0      => inj_word <= pack_word(mp_r, 0);
      when 1      => inj_word <= pack_word(mp_r, 1);
      when 2      => inj_word <= salt_r(0);
      when others => inj_word <= salt_r(1);
    end case;
  end process;

  ---------------------------------------------------------------------------
  -- Ruteo
  ---------------------------------------------------------------------------
  -- banco de posiciones de y: sampler (escritura y limpieza) o poly_mul2
  rd_y        <= smp_rd_addr when state = S_Y else mul_pos_addr;
  smp_rd_data <= bank_y_dout;

  -- sponge propio: S_Y (y) y S_KREJ (hash de k_rej)
  rej_shake_valid <= sp_out_valid when state = S_Y else '0';
  sp_out_ready    <= rej_shake_ready when state = S_Y else
                     '1'             when state = S_KREJ else '0';
  sp_in_valid <= fs_valid when state = S_Y else
                 kf_valid when state = S_KREJ else '0';
  sp_in_data  <= fs_data  when state = S_Y else
                 CMD_KREJ when (state = S_KREJ and kf = KF_CMD) else
                 k_acc(63 downto 0);

  -- direcciones de las RAM de ct y res
  ctu_raddr <= dense_addr                 when state = S_MUL   else
               to_unsigned(cmp_idx, 9)    when state = S_REENC else
               to_unsigned(koff, 9);
  ctv_raddr <= dm_addr                    when state = S_DEC   else
               to_unsigned(cmp_idx, 9)    when state = S_REENC else
               to_unsigned(koff, 9);
  res_raddr <= dm_addr;

  -- comparacion con la salida del re-cifrado: se acepta una palabra cuando la RAM ya presento su dato
  enc_out_ready <= '1' when (state = S_REENC and enc_out_valid = '1' and cmp_rd_ok = '1') else '0';

  -- salida ss
  out_valid_i <= '1' when state = S_OUT else '0';
  out_valid   <= out_valid_i;
  out_last    <= '1' when (state = S_OUT and out_i = 3) else '0';
  out_data    <= kkp_r(out_i) when cmp_bad = '0' else krej_r(out_i);

  ---------------------------------------------------------------------------
  -- Alimentador de y: SHAKE256(seed_dk || 01), sin limite
  ---------------------------------------------------------------------------
  fs_valid <= '1' when (fs = FS_CMD or fs = FS_SEND) else '0';
  process(fs, fidx, seed_dk_r)
  begin
    if fs = FS_CMD then
      fs_data <= CMD_SEED_DK;
    elsif fidx < 4 then
      fs_data <= seed_dk_r(fidx);
    else
      fs_data <= DOM01;
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
              fidx <= 0;
              fs   <= FS_CMD;
            end if;
          when FS_CMD =>
            if sp_in_ready = '1' then
              fs <= FS_SEND;
            end if;
          when FS_SEND =>
            if sp_in_ready = '1' then
              if fidx = 4 then
                fs <= FS_IDLE;
              else
                fidx <= fidx + 1;
              end if;
            end if;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Alimentador de k_rej con realineador de bytes
  --   mensaje = tmp_h(32) || sigma(16) || u(2209) || v(2208) || salt(16) || 03   = 4482 B = 561 palabras
  --   trozos de 8 B salvo el ultimo byte de u y el 03 (1 B). El acumulador k_acc guarda hasta 15 B
  --   (k_cnt valido); por cada trozo se anade y, si hay >= 8 B, se envia una palabra al sponge.
  ---------------------------------------------------------------------------
  kf_valid <= '1' when (kf = KF_CMD or (kf = KF_SEND and k_cnt >= 8) or (kf = KF_FLUSH and k_cnt > 0)) else '0';

  process(kseg, koff, enc_tmp_h, sigma_r, salt_r, ctu_rdata, ctv_rdata, u_last_raw)
  begin
    k_chunk   <= ZERO64;
    k_chunk_n <= 8;
    case kseg is
      when 0 =>
        k_chunk <= tmp_h_word(enc_tmp_h, koff);
      when 1 =>
        k_chunk <= sigma_r(koff mod 2);
      when 2 =>
        if koff < U_LAST then
          k_chunk <= ctu_rdata;
        else
          k_chunk   <= std_logic_vector'(x"00000000000000" & u_last_raw);   -- ultimo byte de u: 1 B
          k_chunk_n <= 1;
        end if;
      when 3 =>
        k_chunk <= ctv_rdata;
      when 4 =>
        k_chunk <= salt_r(koff mod 2);
      when others =>
        k_chunk   <= DOM03;                                -- byte de dominio 03: 1 B
        k_chunk_n <= 1;
    end case;
  end process;

  process(clk)
    variable advance : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        kf    <= KF_IDLE;
        kseg  <= 0;
        koff  <= 0;
        k_cnt <= 0;
        k_acc <= (others => '0');
      else
        case kf is

          when KF_IDLE =>
            if kf_go = '1' then
              kf <= KF_CMD;
            end if;

          when KF_CMD =>                                   -- comando SHA3-256, 4482 B
            if sp_in_ready = '1' then
              kseg  <= 0;
              koff  <= 0;
              k_cnt <= 0;
              k_acc <= (others => '0');
              kf    <= KF_ADDR;
            end if;

          when KF_ADDR =>                                  -- koff direcciona ct_u y ct_v
            kf <= KF_WAIT;

          when KF_WAIT =>                                  -- latencia de las RAM
            kf <= KF_PUSH;

          when KF_PUSH =>                                  -- anadir el trozo al acumulador
            k_acc <= k_acc or std_logic_vector(shift_left(resize(unsigned(k_chunk), 120), 8 * k_cnt));
            k_cnt <= k_cnt + k_chunk_n;
            kf    <= KF_SEND;

          when KF_SEND =>                                  -- con >= 8 B se envia una palabra
            advance := false;
            if k_cnt >= 8 then
              if sp_in_ready = '1' then
                k_acc   <= std_logic_vector(shift_right(unsigned(k_acc), 64));
                k_cnt   <= k_cnt - 8;
                advance := true;
              end if;
            else
              advance := true;
            end if;
            if advance then
              if kseg = 5 then
                kf <= KF_FLUSH;
              else
                if koff = seg_len(kseg) - 1 then
                  kseg <= kseg + 1;
                  koff <= 0;
                else
                  koff <= koff + 1;
                end if;
                kf <= KF_ADDR;
              end if;
            end if;

          when KF_FLUSH =>                                 -- resto (4482 mod 8 = 2 B): ultima palabra parcial
            if k_cnt > 0 then
              if sp_in_ready = '1' then
                k_cnt <= 0;
                kf    <= KF_IDLE;
              end if;
            else
              kf <= KF_IDLE;
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
  dm_word     <= ctv_rdata xor res_rdata;
  dm_addr     <= to_unsigned(6 * dm_i + dm_t, 9) when dm_t < 6 else (others => '0');
  rm_in_valid <= '1' when dm_s = DM_PUSH else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        dm_s   <= DM_IDLE;
        rm_all <= '0';
        rm_n   <= 0;
      else
        -- los simbolos que salen del rm_decoder se guardan en orden de llegada
        if rm_out_valid = '1' then
          if rm_n <= 45 then
            rs_buf(rm_n) <= rm_out_data;
          end if;
          if rm_n = 45 then
            rm_all <= '1';
          end if;
          if rm_n < 46 then
            rm_n <= rm_n + 1;
          end if;
        end if;

        case dm_s is
          when DM_IDLE =>
            if dec_go = '1' then
              dm_i   <= 45;
              dm_t   <= 0;
              rm_n   <= 0;
              rm_all <= '0';
              dm_s   <= DM_FETCH;
            end if;

          when DM_FETCH =>                               -- ciclo t presenta la direccion t; el dato t llega en t+1
            case dm_t is
              when 1      => dm_blk(63 downto 0)     <= dm_word;
              when 2      => dm_blk(127 downto 64)   <= dm_word;
              when 3      => dm_blk(191 downto 128)  <= dm_word;
              when 4      => dm_blk(255 downto 192)  <= dm_word;
              when 5      => dm_blk(319 downto 256)  <= dm_word;
              when 6      => dm_blk(383 downto 320)  <= dm_word;
              when others => null;
            end case;
            if dm_t = 6 then
              dm_s <= DM_PUSH;
            else
              dm_t <= dm_t + 1;
            end if;

          when DM_PUSH =>                                -- rm_in_valid = '1' hasta que in_ready
            if rm_in_ready = '1' then
              if dm_i = 0 then
                dm_s <= DM_END;
              else
                dm_i <= dm_i - 1;
                dm_t <= 0;
                dm_s <= DM_FETCH;
              end if;
            end if;

          when DM_END =>
            dm_s <= DM_IDLE;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Decodificacion RS: cuando estan los 46 simbolos se envian seguidos (cw[45] .. cw[0]);
  -- el decoder entrega primero los 16 simbolos de informacion b0..b15 = m[15] .. m[0].
  ---------------------------------------------------------------------------
  rsd_i_consume <= '1';
  rsd_i_valid   <= '1' when rf = RF_FEED else '0';
  rsd_i_symbol  <= rs_buf(rf_k);
  rsd_i_end     <= '1' when (rf = RF_FEED and rf_k = 45) else '0';
  rsd_i_start   <= '1' when ((RSD_START_OVERLAP and rf = RF_FEED and rf_k = 0) or
                             ((not RSD_START_OVERLAP) and rf = RF_PRE)) else '0';

  process(clk)
    variable idx : integer range 0 to 16;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rf      <= RF_IDLE;
        dec_fin <= '0';
        err_dec <= '0';
        rsd_k   <= 0;
        rf_k    <= 0;
      else
        if start = '1' and state = S_IDLE then
          err_dec <= '0';
        end if;
        if rsd_o_error = '1' then
          err_dec <= '1';
        end if;

        -- captura de la salida: m'[15 - k] = k-esimo simbolo; termina con o_end_codeword
        if rsd_o_valid = '1' and rf = RF_CAPT then
          if rsd_o_start = '1' then
            idx := 0;
          else
            idx := rsd_k;
          end if;
          if idx < 16 then
            mp_r(15 - idx) <= rsd_o_symbol;
            rsd_k          <= idx + 1;
          end if;
          if rsd_o_end = '1' then
            dec_fin <= '1';
            rf      <= RF_IDLE;
          end if;
        end if;

        case rf is
          when RF_IDLE =>
            if dec_go = '1' then
              dec_fin <= '0';
              rsd_k   <= 0;
              rf      <= RF_WAIT;
            end if;
          when RF_WAIT =>                                 -- esperar los 46 simbolos del RM
            if rm_all = '1' then
              rf_k <= 0;
              if RSD_START_OVERLAP then
                rf <= RF_FEED;
              else
                rf <= RF_PRE;
              end if;
            end if;
          when RF_PRE =>
            rf <= RF_FEED;
          when RF_FEED =>
            if rf_k = 45 then
              rf <= RF_CAPT;
            else
              rf_k <= rf_k + 1;
            end if;
          when RF_CAPT =>
            null;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- FSM maestra (state)
  ---------------------------------------------------------------------------
  process(clk)
    variable xfer : boolean;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state        <= S_IDLE;
        dk_idx       <= 0;
        ct_idx       <= 0;
        inj_idx      <= 0;
        cap_cnt      <= 0;
        out_i        <= 0;
        cmp_idx      <= 0;
        cmp_rd_ok    <= '0';
        cmp_bad      <= '0';
        running      <= '0';
        core_running <= '0';
        enc_start    <= '0';
        smp_start    <= '0';
        f_go         <= '0';
        kf_go        <= '0';
        mul_start    <= '0';
        abort_req    <= '0';
        dec_go       <= '0';
      else
        -- pulsos: valen '1' durante UN ciclo cuando se asignan
        enc_start <= '0';
        smp_start <= '0';
        f_go      <= '0';
        kf_go     <= '0';
        mul_start <= '0';
        abort_req <= '0';
        dec_go    <= '0';

        if running = '1' then
          cyc <= cyc + 1;
        end if;
        if core_running = '1' then
          cyc_core <= cyc_core + 1;
        end if;

        case state is

          when S_IDLE =>
            if start = '1' and enc_ready = '1' then
              enc_start <= '1';                       -- hqc_encaps entra en su S_KEY y espera ek
              dk_idx    <= 0;
              ct_idx    <= 0;
              cmp_bad   <= '0';
              cyc       <= (others => '0');
              running   <= '1';
              state     <= S_INGEST;
            end if;

          when S_INGEST =>                            -- dk_ready_i / ct_ready_i segun contadores
            if dk_valid = '1' and dk_ready_i = '1' then
              if dk_idx >= 281 and dk_idx <= 284 then
                seed_dk_r(dk_idx - 281) <= dk_data;
              elsif dk_idx >= 285 and dk_idx <= 286 then
                sigma_r(dk_idx - 285) <= dk_data;
              end if;                                  -- 0..280: reenviado a hqc_encaps ; 287..290: seed_kem, se ignora
              dk_idx <= dk_idx + 1;
            end if;
            if ct_valid = '1' and ct_ready_i = '1' then
              if ct_idx = U_LAST then
                u_last_raw <= ct_data(7 downto 0);     -- byte 2208 de u tal cual (para comparar y para el hash)
              elsif ct_idx >= CT_SALT_BASE then
                salt_r(ct_idx - CT_SALT_BASE) <= ct_data;
              end if;                                  -- u y v los escribe la RAM (ctu_we / ctv_we)
              ct_idx <= ct_idx + 1;
            end if;
            if dk_idx = DK_WORDS and ct_idx = CT_WORDS then
              f_go         <= '1';                     -- SHAKE256(seed_dk||01) sin limite
              smp_start    <= '1';                     -- y = rej(66)
              cyc_core     <= (others => '0');
              core_running <= '1';
              state        <= S_Y;
            end if;

          when S_Y =>
            if smp_done = '1' then
              abort_req <= '1';                        -- y listo: cortar el flujo del sponge
              state     <= S_MULW;
            end if;

          when S_MULW =>
            if mul_ready = '1' then
              mul_start <= '1';
              state     <= S_MUL;
            end if;

          when S_MUL =>                                -- res = y * u
            if mul_done = '1' then
              dec_go <= '1';
              state  <= S_DEC;
            end if;

          when S_DEC =>                                -- RM + RS -> m'
            if dec_fin = '1' then
              inj_idx <= 0;
              state   <= S_INJ;
            end if;

          when S_INJ =>                                -- m' (2 palabras) y salt (2) a hqc_encaps
            if enc_key_ready = '1' then                -- enc_key_valid = '1' en este estado
              if inj_idx = 3 then
                cmp_idx   <= 0;
                cmp_rd_ok <= '0';
                state     <= S_REENC;
              else
                inj_idx <= inj_idx + 1;
              end if;
            end if;

          when S_REENC =>
            xfer := (enc_out_valid = '1' and enc_out_ready = '1');
            if xfer then
              cmp_rd_ok <= '0';
              case enc_out_part is
                when "00" =>                           -- ss' = kk'
                  if cmp_idx < 4 then
                    kkp_r(cmp_idx) <= enc_out_data;
                  end if;
                when "01" =>                           -- v'
                  if enc_out_data /= ctv_rdata then
                    cmp_bad <= '1';
                  end if;
                when "10" =>                           -- u' (la ultima palabra: solo el byte bajo)
                  if cmp_idx = U_LAST then
                    if enc_out_data(7 downto 0) /= u_last_raw then
                      cmp_bad <= '1';
                    end if;
                  elsif enc_out_data /= ctu_rdata then
                    cmp_bad <= '1';
                  end if;
                when others =>                         -- salt'
                  if enc_out_data /= salt_r(cmp_idx mod 2) then
                    cmp_bad <= '1';
                  end if;
              end case;
              if enc_out_last = '1' then
                cmp_idx <= 0;
              else
                cmp_idx <= cmp_idx + 1;
              end if;
            else
              cmp_rd_ok <= '1';                        -- la direccion de la RAM lleva >= 1 ciclo estable
            end if;
            if enc_done = '1' then
              kf_go   <= '1';
              cap_cnt <= 0;
              state   <= S_KREJ;
            end if;

          when S_KREJ =>                               -- hash de k_rej (kf) y captura de su salida
            if sp_out_valid = '1' then
              if cap_cnt < 4 then
                krej_r(cap_cnt) <= sp_out_data;
              end if;
              if cap_cnt < 4 then
                cap_cnt <= cap_cnt + 1;
              end if;
            end if;
            if cap_cnt = 4 then
              out_i          <= 0;
              running        <= '0';
              core_running   <= '0';
              cycles_r       <= cyc;
              cycles_core_r  <= cyc_core;
              state          <= S_OUT;
            end if;

          when S_OUT =>                                -- ss = match ? kk' : k_rej
            if out_ready = '1' then
              if out_i = 3 then
                state <= S_DONE;
              else
                out_i <= out_i + 1;
              end if;
            end if;

          when S_DONE =>
            state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;
