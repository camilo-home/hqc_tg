-- ============================================================================
-- hqc_keygen (v2, simplificado y secuencial)
--
--   entrada : pulso start, y luego seed_kem (4 palabras de 64 bits, valid/ready)
--   salida  : parte 0 (out_part='0'): ek = seed_ek(32 B) || s(2209 B)            -> 281 palabras
--             parte 1 (out_part='1'): seed_dk(32 B) || sigma(16 B) || seed_kem(32 B) -> 10 palabras
--             dk = ek || parte 1.  out_last marca la ultima palabra de cada parte.
--   cycles  : ciclos desde start hasta tener s listo (antes de sacar datos)
--   Bytes en palabras: byte 0 en los bits [7:0] (igual que el sponge).
--
-- UNA micro-operacion a la vez, sin solapes (cada estado espera el done del motor que lanzo):
--   S_C1  SHAKE256(seed_kem||01), 48 B   -> seed_pke, sigma          (se capturan en el banco de registros sw)
--   S_C2  SHA3-512(seed_pke||02), 64 B   -> seed_dk, seed_ek         (se capturan en sw)
--   S_C3  SHAKE256(seed_ek||01), 2216 B  -> sample_vect -> h         (RAM densa)
--   S_Y   SHAKE256(seed_dk||01), SIN LIMITE: sampler rej -> y        (banco de posiciones)
--   S_MUL poly_mul2: y*h -> RAM de resultado
--   S_X   mismo flujo (sigue abierto): sampler rej -> x              (el mismo banco, y ya no hace falta)
--         abort al terminar x
--   S_XOR sparse_xor: s = y*h xor x                                   (sobre la RAM de resultado)
--   S_O_* salida
--
-- Mapa de sw (palabras de 64 bits, registros, lectura inmediata):
--   0..3 seed_kem | 4..7 seed_pke | 8..9 sigma | 10..13 seed_dk | 14..17 seed_ek
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.keccak_sponge_pkg.all;

entity hqc_keygen is
  generic(
    WT : integer := 66            -- peso de x e y (HQC-128)
  );
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;

    start : in  std_logic;        -- pulso, solo con ready='1'
    ready : out std_logic;
    done  : out std_logic;        -- pulso al terminar de sacar toda la salida

    seed_valid : in  std_logic;
    seed_ready : out std_logic;
    seed_data  : in  std_logic_vector(63 downto 0);

    out_valid : out std_logic;
    out_ready : in  std_logic;
    out_data  : out std_logic_vector(63 downto 0);
    out_last  : out std_logic;
    out_part  : out std_logic;

    cycles    : out unsigned(31 downto 0);
    dbg_state : out std_logic_vector(3 downto 0)    -- estado de la FSM (para depurar)
  );
end entity;

architecture rtl of hqc_keygen is

  constant WORDS     : integer := 277;
  constant H_BYTES   : integer := WORDS * 8;              -- 2216 B que consume sample_vect
  constant OUT0_LAST : integer := 4 + WORDS - 1;          -- ultima palabra de ek (indice 280)

  constant CMD1 : std_logic_vector(63 downto 0) := make_cmd(MODE_SHAKE256, 33, 48);
  constant CMD2 : std_logic_vector(63 downto 0) := make_cmd(MODE_SHA3_512, 33, 0);
  constant CMD3 : std_logic_vector(63 downto 0) := make_cmd(MODE_SHAKE256, 33, H_BYTES);
  constant CMD4 : std_logic_vector(63 downto 0) := make_cmd_stream(MODE_SHAKE256, 33);

  constant ZERO64 : std_logic_vector(63 downto 0) := (others => '0');
  constant NPOS_C : unsigned(6 downto 0) := to_unsigned(WT, 7);

  type state_t is (S_IDLE, S_SEED, S_C1, S_C2, S_C3, S_Y, S_MUL, S_X, S_XOR,
                   S_O_ADDR, S_O_SEND, S_DONE);
  type fstate_t is (FS_IDLE, FS_CMD, FS_SEND, FS_DOM);
  type sw_t is array (0 to 17) of std_logic_vector(63 downto 0);

  signal state : state_t := S_IDLE;
  signal fs    : fstate_t := FS_IDLE;
  signal sw    : sw_t := (others => (others => '0'));

  signal k         : integer range 0 to 3 := 0;
  signal fk        : integer range 0 to 3 := 0;
  signal cap_base  : integer range 0 to 17 := 0;
  signal cap_cnt   : integer range 0 to 8 := 0;
  signal cap_total : integer range 0 to 8 := 0;
  signal f_cmd     : std_logic_vector(63 downto 0) := (others => '0');
  signal f_base    : integer range 0 to 17 := 0;
  signal f_dom     : std_logic_vector(7 downto 0) := (others => '0');
  signal dom_word  : std_logic_vector(63 downto 0);

  -- pulsos de un ciclo (registros)
  signal f_go, sv_start, smp_start, mul_start, xor_start, abort_req : std_logic := '0';

  signal running  : std_logic := '0';
  signal cyc      : unsigned(31 downto 0) := (others => '0');
  signal cycles_r : unsigned(31 downto 0) := (others => '0');
  signal part     : std_logic := '0';
  signal ok       : integer range 0 to OUT0_LAST := 0;

  -- sponge
  signal sp_in_valid, sp_in_ready, sp_out_valid, sp_out_ready : std_logic;
  signal sp_in_data, sp_out_data : std_logic_vector(63 downto 0);

  -- sample_vect
  signal sv_din_valid, sv_din_ready, sv_wr_en, sv_done : std_logic;
  signal sv_wr_addr : unsigned(8 downto 0);
  signal sv_wr_data : std_logic_vector(63 downto 0);

  -- sampler rej
  signal smp_shake_valid, smp_shake_ready, smp_wr_en, smp_done : std_logic;
  signal smp_wr_addr, smp_rd_addr : unsigned(6 downto 0);
  signal smp_wr_data, smp_rd_data : unsigned(14 downto 0);

  -- banco de posiciones (uno solo)
  signal we_bank : std_logic;
  signal rd_pos, mul_pos_addr, xor_pos_addr : unsigned(6 downto 0);
  signal bank_dout : unsigned(14 downto 0);

  -- memoria densa h y acumulador
  signal dense_addr : unsigned(8 downto 0);
  signal dense_a_data : std_logic_vector(63 downto 0);
  signal acc_addr1, acc_addr2 : unsigned(9 downto 0);
  signal acc_we1, acc_we2 : std_logic;
  signal acc_din1, accA_din2, accA_dout1, accA_dout2 : std_logic_vector(63 downto 0);

  -- poly_mul2
  signal mul_done, res_we : std_logic;
  signal res_addr : unsigned(8 downto 0);
  signal res_a_data : std_logic_vector(63 downto 0);

  -- sparse_xor
  signal xor_done, xor_mem_we : std_logic;
  signal xor_mem_addr : unsigned(8 downto 0);
  signal xor_mem_din : std_logic_vector(63 downto 0);

  -- RAM de resultado
  signal r_we : std_logic;
  signal r_waddr, r_raddr, out_res_addr : unsigned(8 downto 0);
  signal r_wdata, r_rdata : std_logic_vector(63 downto 0);

  signal out_sw_idx : integer range 0 to 17;

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

  u_samp : entity work.samplefxwtrej
    generic map (N => 17669, N_32 => 243079, WT => WT, SHAKE_BYTE_SWAP => false)
    port map (clk => clk, rst => rst, start => smp_start,
              shake_din => sp_out_data, shake_valid => smp_shake_valid, shake_ready => smp_shake_ready,
              wr_en => smp_wr_en, wr_addr => smp_wr_addr, wr_data => smp_wr_data,
              rd_addr => smp_rd_addr, rd_data => smp_rd_data,
              sample_done => smp_done);

  u_vect : entity work.sample_vect
    generic map (N => 17669, N_SZ => 2209, ADDR_W => 9)
    port map (clk => clk, rst => rst, start => sv_start,
              din => sp_out_data, din_valid => sv_din_valid, din_ready => sv_din_ready,
              wr_en => sv_wr_en, wr_addr => sv_wr_addr, wr_data => sv_wr_data,
              sample_done => sv_done);

  u_mul : entity work.poly_mul2
    generic map (N => 17669, DUAL => false, POS_W => 15, PA_W => 7, AW => 9, ACC_AW => 10)
    port map (clk => clk, rst => rst, start => mul_start, n_pos => NPOS_C,
              ready => open, done => mul_done,
              pos_addr => mul_pos_addr, pos_data => bank_dout,
              dense_addr => dense_addr, dense_a_data => dense_a_data, dense_b_data => ZERO64,
              acc_addr1 => acc_addr1, acc_we1 => acc_we1, acc_din1 => acc_din1,
              acc_addr2 => acc_addr2, acc_we2 => acc_we2,
              accA_din2 => accA_din2, accB_din2 => open,
              accA_dout1 => accA_dout1, accB_dout1 => ZERO64,
              accA_dout2 => accA_dout2, accB_dout2 => ZERO64,
              res_we => res_we, res_addr => res_addr, res_a_data => res_a_data, res_b_data => open);

  u_xor : entity work.sparse_xor
    generic map (POS_W => 15, PA_W => 7, AW => 9)
    port map (clk => clk, rst => rst, start => xor_start, n_pos => NPOS_C,
              ready => open, done => xor_done,
              pos_addr => xor_pos_addr, pos_data => bank_dout,
              mem_we => xor_mem_we, mem_addr => xor_mem_addr, mem_din => xor_mem_din, mem_dout => r_rdata);

  u_bank : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => we_bank, wr_addr => smp_wr_addr, din => smp_wr_data,
              rd_addr => rd_pos, dout => bank_dout);

  u_dense_h : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => sv_wr_en, waddr => sv_wr_addr, wdata => sv_wr_data,
              raddr => dense_addr, rdata => dense_a_data);

  u_acc : entity work.ram64_tdp
    generic map (DEPTH => 554, ADDR_W => 10)
    port map (clk => clk,
              we_1 => acc_we1, addr_1 => acc_addr1, din_1 => acc_din1, dout_1 => accA_dout1,
              we_2 => acc_we2, addr_2 => acc_addr2, din_2 => accA_din2, dout_2 => accA_dout2);

  u_res : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => r_we, waddr => r_waddr, wdata => r_wdata,
              raddr => r_raddr, rdata => r_rdata);

  ---------------------------------------------------------------------------
  -- Salidas simples
  ---------------------------------------------------------------------------
  ready      <= '1' when state = S_IDLE else '0';
  seed_ready <= '1' when state = S_SEED else '0';
  done       <= '1' when state = S_DONE else '0';
  cycles     <= cycles_r;
  dbg_state  <= std_logic_vector(to_unsigned(state_t'pos(state), 4));

  ---------------------------------------------------------------------------
  -- Enrutado de la salida del sponge: lo decide SOLO el estado
  ---------------------------------------------------------------------------
  sp_out_ready <= '1'             when (state = S_C1 or state = S_C2) else
                  sv_din_ready    when state = S_C3 else
                  smp_shake_ready when (state = S_Y or state = S_X) else
                  '0';
  sv_din_valid    <= sp_out_valid when state = S_C3 else '0';
  smp_shake_valid <= sp_out_valid when (state = S_Y or state = S_X) else '0';

  ---------------------------------------------------------------------------
  -- Banco de posiciones unico: lo escribe el sampler (y, luego x); lo lee, segun el estado,
  -- el sampler (limpieza), poly_mul2 (y) o sparse_xor (x)
  ---------------------------------------------------------------------------
  we_bank     <= smp_wr_en when (state = S_Y or state = S_X) else '0';
  rd_pos      <= smp_rd_addr   when (state = S_Y or state = S_X) else
                 mul_pos_addr  when state = S_MUL else
                 xor_pos_addr;
  smp_rd_data <= bank_dout;

  ---------------------------------------------------------------------------
  -- RAM de resultado: escribe poly_mul2 (S_MUL), luego sparse_xor (S_XOR), luego se lee en la salida
  ---------------------------------------------------------------------------
  r_we    <= xor_mem_we   when state = S_XOR else res_we;
  r_waddr <= xor_mem_addr when state = S_XOR else res_addr;
  r_wdata <= xor_mem_din  when state = S_XOR else res_a_data;
  r_raddr <= xor_mem_addr when state = S_XOR else out_res_addr;

  ---------------------------------------------------------------------------
  -- Alimentador del sponge: comando + 4 palabras de sw + palabra con el byte de dominio
  --   (mensaje = 33 bytes: seed || dominio; el padding SHAKE/SHA3 lo pone el sponge)
  ---------------------------------------------------------------------------
  dom_word(7 downto 0)  <= f_dom;
  dom_word(63 downto 8) <= (others => '0');
  sp_in_valid <= '1' when (fs = FS_CMD or fs = FS_SEND or fs = FS_DOM) else '0';
  sp_in_data  <= f_cmd             when fs = FS_CMD  else
                 sw(f_base + fk)   when fs = FS_SEND else
                 dom_word;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        fs <= FS_IDLE;
        fk <= 0;
      else
        case fs is
          when FS_IDLE =>
            if f_go = '1' then
              fk <= 0;
              fs <= FS_CMD;
            end if;
          when FS_CMD =>
            if sp_in_ready = '1' then
              fs <= FS_SEND;
            end if;
          when FS_SEND =>
            if sp_in_ready = '1' then
              if fk = 3 then
                fs <= FS_DOM;
              else
                fk <= fk + 1;
              end if;
            end if;
          when FS_DOM =>
            if sp_in_ready = '1' then
              fs <= FS_IDLE;
            end if;
        end case;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Direcciones de la salida (parte 0: seed_ek y s ; parte 1: seed_dk, sigma, seed_kem)
  ---------------------------------------------------------------------------
  process(part, ok)
  begin
    out_sw_idx   <= 0;
    out_res_addr <= (others => '0');
    if part = '0' then
      if ok < 4 then
        out_sw_idx   <= 14 + ok;                 -- seed_ek
      else
        out_res_addr <= to_unsigned(ok - 4, 9);  -- s
      end if;
    else
      if ok < 4 then
        out_sw_idx <= 10 + ok;                   -- seed_dk
      elsif ok < 6 then
        out_sw_idx <= 8 + (ok - 4);              -- sigma
      else
        out_sw_idx <= ok - 6;                    -- seed_kem
      end if;
    end if;
  end process;

  out_valid <= '1' when state = S_O_SEND else '0';
  out_data  <= r_rdata when (part = '0' and ok >= 4) else sw(out_sw_idx);
  out_last  <= '1' when (state = S_O_SEND and
                         ((part = '0' and ok = OUT0_LAST) or (part = '1' and ok = 9))) else '0';
  out_part  <= part;

  ---------------------------------------------------------------------------
  -- FSM maestra
  ---------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state     <= S_IDLE;
        k         <= 0;
        cap_cnt   <= 0;
        running   <= '0';
        part      <= '0';
        ok        <= 0;
        f_go      <= '0';
        sv_start  <= '0';
        smp_start <= '0';
        mul_start <= '0';
        xor_start <= '0';
        abort_req <= '0';
      else
        -- pulsos: por defecto a 0; valen '1' durante UN ciclo cuando se asignan
        f_go      <= '0';
        sv_start  <= '0';
        smp_start <= '0';
        mul_start <= '0';
        xor_start <= '0';
        abort_req <= '0';

        if running = '1' then
          cyc <= cyc + 1;
        end if;

        -- captura de la salida del sponge en sw (pasos 1 y 2; out_ready = '1')
        if (state = S_C1 or state = S_C2) and sp_out_valid = '1' then
          sw(cap_base + cap_cnt) <= sp_out_data;
          cap_cnt <= cap_cnt + 1;
        end if;

        case state is

          when S_IDLE =>
            if start = '1' then
              k       <= 0;
              cyc     <= (others => '0');
              running <= '1';
              state   <= S_SEED;
            end if;

          when S_SEED =>                                    -- seed_ready = '1'
            if seed_valid = '1' then
              sw(k) <= seed_data;
              if k = 3 then
                -- paso 1: SHAKE256(seed_kem||01) -> seed_pke, sigma (6 palabras en sw[4..9])
                f_cmd <= CMD1;  f_base <= 0;  f_dom <= x"01";
                cap_base <= 4;  cap_total <= 6;  cap_cnt <= 0;
                f_go  <= '1';
                state <= S_C1;
              else
                k <= k + 1;
              end if;
            end if;

          when S_C1 =>
            if cap_cnt = cap_total then
              -- paso 2: SHA3-512(seed_pke||02) -> seed_dk, seed_ek (8 palabras en sw[10..17])
              f_cmd <= CMD2;  f_base <= 4;  f_dom <= x"02";
              cap_base <= 10; cap_total <= 8;  cap_cnt <= 0;
              f_go  <= '1';
              state <= S_C2;
            end if;

          when S_C2 =>
            if cap_cnt = cap_total then
              -- paso 3: SHAKE256(seed_ek||01), 2216 B -> sample_vect
              f_cmd <= CMD3;  f_base <= 14; f_dom <= x"01";
              f_go     <= '1';
              sv_start <= '1';
              state    <= S_C3;
            end if;

          when S_C3 =>
            if sv_done = '1' then
              -- paso 4: SHAKE256(seed_dk||01) sin limite -> sampler (y)
              f_cmd <= CMD4;  f_base <= 10; f_dom <= x"01";
              f_go      <= '1';
              smp_start <= '1';
              state     <= S_Y;
            end if;

          when S_Y =>
            if smp_done = '1' then
              mul_start <= '1';                             -- y*h
              state     <= S_MUL;
            end if;

          when S_MUL =>
            if mul_done = '1' then
              smp_start <= '1';                             -- x: sale del MISMO flujo del sponge
              state     <= S_X;
            end if;

          when S_X =>
            if smp_done = '1' then
              abort_req <= '1';                             -- cortar el flujo del sponge
              xor_start <= '1';                             -- s = y*h xor x
              state     <= S_XOR;
            end if;

          when S_XOR =>
            if xor_done = '1' then
              running  <= '0';
              cycles_r <= cyc;
              part     <= '0';
              ok       <= 0;
              state    <= S_O_ADDR;
            end if;

          when S_O_ADDR =>                                  -- direccion presentada; dato valido en S_O_SEND
            state <= S_O_SEND;

          when S_O_SEND =>                                  -- out_valid = '1'
            if out_ready = '1' then
              if part = '0' and ok = OUT0_LAST then
                part  <= '1';
                ok    <= 0;
                state <= S_O_ADDR;
              elsif part = '1' and ok = 9 then
                state <= S_DONE;
              else
                ok    <= ok + 1;
                state <= S_O_ADDR;
              end if;
            end if;

          when S_DONE =>
            state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;
