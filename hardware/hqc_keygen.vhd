-- ============================================================================
-- hqc_keygen : HQC-128 KeyGen (spec 2025, hqc128.py:keygen) sobre tus modulos.
--
--   entrada : seed_kem (32 bytes = 4 palabras de 64 bits), tras un pulso de start
--   salida  : un flujo de palabras de 64 bits en dos partes
--               parte 0 (out_part='0'): ek = seed_ek(32 B) || s(2209 B)  -> 281 palabras (la ultima solo
--                                        tiene 1 byte util, el resto a 0)           [clave publica 2241 B]
--               parte 1 (out_part='1'): seed_dk(32 B) || sigma(16 B) || seed_kem(32 B) -> 10 palabras
--               dk = ek || parte 1                                                 [clave secreta 2321 B]
--             out_last marca la ultima palabra de CADA parte.
--   cycles  : ciclos desde start hasta tener s listo (antes de sacar nada): latencia de calculo.
--   Bytes en palabras: byte 0 en los bits [7:0] (igual que el sponge y el resto del proyecto).
--
-- Secuencia (cada paso es una micro-operacion con su propio start/done):
--   1  SHAKE256(seed_kem||01) , 48 B  -> seed_pke (4 palabras) y sigma (2)        [capturados en seedmem]
--   2  SHA3-512(seed_pke||02) , 64 B  -> seed_dk (4) y seed_ek (4)                [capturados en seedmem]
--   3  SHAKE256(seed_ek||01)  , 2216 B -> sample_vect -> h  (ram densa, 277 palabras)
--   4  SHAKE256(seed_dk||01)  , SIN LIMITE (se corta con abort):
--        sampler rej -> y (banco de posiciones Y)
--        poly_mul2 (y*h)  ||  sampler rej -> x (banco X)     <- el muestreo de x se solapa con la multiplicacion
--        abort al terminar x
--   5  sparse_xor: s = y*h xor x  (sobre la RAM de resultado)
--   6  salida
--
-- Decisiones de diseno: ver la explicacion que acompana a este archivo.
-- Supuestos sobre tus modulos: samplefxwtrej consume del flujo exactamente lo que la referencia (incluido
-- el drenado del chunk) y puede relanzarse tras sample_done; sus puertos son los que indicaste.
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

    -- seed_kem (4 palabras)
    seed_valid : in  std_logic;
    seed_ready : out std_logic;
    seed_data  : in  std_logic_vector(63 downto 0);

    -- ek (281 palabras) y luego dk_extra (10 palabras)
    out_valid : out std_logic;
    out_ready : in  std_logic;
    out_data  : out std_logic_vector(63 downto 0);
    out_last  : out std_logic;
    out_part  : out std_logic;

    cycles    : out unsigned(31 downto 0)
  );
end entity;

architecture rtl of hqc_keygen is

  constant WORDS     : integer := 277;                    -- palabras de un vector (64 bits)
  constant H_BYTES   : integer := WORDS * 8;              -- 2216 B que consume sample_vect
  constant OUT0_LAST : integer := 4 + WORDS - 1;          -- ultima palabra de ek (indice 280)

  constant CMD1 : std_logic_vector(63 downto 0) := make_cmd(MODE_SHAKE256, 33, 48);
  constant CMD2 : std_logic_vector(63 downto 0) := make_cmd(MODE_SHA3_512, 33, 0);
  constant CMD3 : std_logic_vector(63 downto 0) := make_cmd(MODE_SHAKE256, 33, H_BYTES);
  constant CMD4 : std_logic_vector(63 downto 0) := make_cmd_stream(MODE_SHAKE256, 33);

  constant ZERO64 : std_logic_vector(63 downto 0) := (others => '0');
  constant NPOS_C : unsigned(6 downto 0) := to_unsigned(WT, 7);

  -- mapa de seedmem (palabras de 64 bits)
  --   0..3 seed_kem | 4..7 seed_pke | 8..9 sigma | 10..13 seed_dk | 14..17 seed_ek

  type state_t  is (S_IDLE, S_SEED, S_SETUP, S_GO, S_RUN, S_MUL_GO, S_MUL_WAIT,
                    S_XOR_GO, S_XOR_WAIT, S_O_ADDR, S_O_SEND, S_DONE);
  type phase_t  is (PH_NONE, PH_CAP, PH_H, PH_SMP);
  type fstate_t is (FS_IDLE, FS_CMD, FS_RD, FS_SEND, FS_DOM);

  signal state : state_t := S_IDLE;
  signal phase : phase_t := PH_NONE;
  signal fs    : fstate_t := FS_IDLE;

  signal step      : integer range 0 to 4 := 0;
  signal k         : integer range 0 to 3 := 0;
  signal fk        : integer range 0 to 3 := 0;
  signal cap_base  : integer range 0 to 31 := 0;
  signal cap_cnt   : integer range 0 to 8 := 0;
  signal cap_total : integer range 0 to 8 := 0;
  signal f_cmd     : std_logic_vector(63 downto 0) := (others => '0');
  signal f_base    : integer range 0 to 31 := 0;
  signal f_dom     : std_logic_vector(7 downto 0) := (others => '0');

  signal smp_y_act, smp_x_act : std_logic := '0';
  signal f_mul, f_smp         : std_logic := '0';
  signal abort_req            : std_logic := '0';

  signal running : std_logic := '0';
  signal cyc     : unsigned(31 downto 0) := (others => '0');
  signal cycles_r: unsigned(31 downto 0) := (others => '0');

  signal part : std_logic := '0';
  signal ok   : integer range 0 to OUT0_LAST := 0;

  -- pulsos hacia los motores
  signal f_go, sv_start, smp_start, mul_start, xor_start : std_logic;

  -- sponge
  signal sp_in_valid, sp_in_ready, sp_out_valid, sp_out_ready, sp_abort : std_logic;
  signal sp_in_data, sp_out_data : std_logic_vector(63 downto 0);

  -- seedmem
  signal sm_we    : std_logic;
  signal sm_waddr, sm_raddr, fb_addr, out_sm_addr : unsigned(4 downto 0);
  signal sm_wdata, sm_rdata : std_logic_vector(63 downto 0);

  -- sample_vect
  signal sv_din_valid, sv_din_ready, sv_wr_en, sv_done : std_logic;
  signal sv_wr_addr : unsigned(8 downto 0);
  signal sv_wr_data : std_logic_vector(63 downto 0);

  -- sampler rej
  signal smp_shake_valid, smp_shake_ready, smp_wr_en, smp_done : std_logic;
  signal smp_wr_addr, smp_rd_addr : unsigned(6 downto 0);
  signal smp_wr_data, smp_rd_data : unsigned(14 downto 0);

  -- bancos de posiciones
  signal we_y, we_x : std_logic;
  signal rd_y, rd_x, mul_pos_addr, xor_pos_addr : unsigned(6 downto 0);
  signal bankY_dout, bankX_dout : unsigned(14 downto 0);

  -- memoria densa h y acumulador
  signal dense_addr : unsigned(8 downto 0);
  signal dense_a_data : std_logic_vector(63 downto 0);
  signal acc_addr1, acc_addr2 : unsigned(9 downto 0);
  signal acc_we1, acc_we2 : std_logic;
  signal acc_din1, accA_din2, accA_dout1, accA_dout2 : std_logic_vector(63 downto 0);

  -- poly_mul2
  signal mul_ready, mul_done, res_we : std_logic;
  signal res_addr : unsigned(8 downto 0);
  signal res_a_data : std_logic_vector(63 downto 0);

  -- sparse_xor
  signal xor_ready, xor_done, xor_mem_we : std_logic;
  signal xor_mem_addr : unsigned(8 downto 0);
  signal xor_mem_din : std_logic_vector(63 downto 0);

  -- RAM de resultado
  signal r_we : std_logic;
  signal r_waddr, r_raddr, out_res_addr : unsigned(8 downto 0);
  signal r_wdata, r_rdata : std_logic_vector(63 downto 0);

  signal in_xor : boolean;
  signal dom_word : std_logic_vector(63 downto 0);

begin

  ---------------------------------------------------------------------------
  -- Instancias
  ---------------------------------------------------------------------------
  u_sponge : entity work.keccak_sponge
    generic map (BIG_ENDIAN_WORDS => false)
    port map (clk => clk, rst => rst, abort => sp_abort,
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
              ready => mul_ready, done => mul_done,
              pos_addr => mul_pos_addr, pos_data => bankY_dout,
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
              ready => xor_ready, done => xor_done,
              pos_addr => xor_pos_addr, pos_data => bankX_dout,
              mem_we => xor_mem_we, mem_addr => xor_mem_addr, mem_din => xor_mem_din, mem_dout => r_rdata);

  -- memorias
  u_bank_y : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => we_y, wr_addr => smp_wr_addr, din => smp_wr_data,
              rd_addr => rd_y, dout => bankY_dout);
  u_bank_x : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => we_x, wr_addr => smp_wr_addr, din => smp_wr_data,
              rd_addr => rd_x, dout => bankX_dout);

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

  u_seed : entity work.ram64_sdp
    generic map (DEPTH => 18, ADDR_W => 5)
    port map (clk => clk, we => sm_we, waddr => sm_waddr, wdata => sm_wdata,
              raddr => sm_raddr, rdata => sm_rdata);

  ---------------------------------------------------------------------------
  -- Pulsos (Moore: duran el ciclo en que la FSM esta en ese estado)
  ---------------------------------------------------------------------------
  f_go      <= '1' when state = S_GO else '0';
  sv_start  <= '1' when (state = S_GO and step = 3) else '0';
  smp_start <= '1' when ((state = S_GO and step = 4) or state = S_MUL_GO) else '0';
  mul_start <= '1' when state = S_MUL_GO else '0';
  xor_start <= '1' when state = S_XOR_GO else '0';
  sp_abort  <= abort_req;

  ready      <= '1' when state = S_IDLE else '0';
  seed_ready <= '1' when state = S_SEED else '0';
  done       <= '1' when state = S_DONE else '0';
  cycles     <= cycles_r;

  ---------------------------------------------------------------------------
  -- Enrutado de la salida del sponge segun la fase
  ---------------------------------------------------------------------------
  sp_out_ready <= '1'             when phase = PH_CAP else
                  sv_din_ready    when phase = PH_H   else
                  smp_shake_ready when phase = PH_SMP else
                  '0';
  sv_din_valid    <= sp_out_valid when phase = PH_H   else '0';
  smp_shake_valid <= sp_out_valid when phase = PH_SMP else '0';

  ---------------------------------------------------------------------------
  -- Bancos de posiciones: Y (y luego lo lee poly_mul2) y X (luego lo lee sparse_xor)
  ---------------------------------------------------------------------------
  we_y <= smp_wr_en and smp_y_act;
  we_x <= smp_wr_en and smp_x_act;
  rd_y <= smp_rd_addr when smp_y_act = '1' else mul_pos_addr;
  rd_x <= smp_rd_addr when smp_x_act = '1' else xor_pos_addr;
  smp_rd_data <= bankY_dout when smp_y_act = '1' else bankX_dout;

  ---------------------------------------------------------------------------
  -- RAM de resultado: escribe poly_mul2, luego sparse_xor (RMW), luego se lee para la salida
  ---------------------------------------------------------------------------
  in_xor  <= (state = S_XOR_GO or state = S_XOR_WAIT);
  r_we    <= xor_mem_we   when in_xor else res_we;
  r_waddr <= xor_mem_addr when in_xor else res_addr;
  r_wdata <= xor_mem_din  when in_xor else res_a_data;
  r_raddr <= xor_mem_addr when in_xor else out_res_addr;

  ---------------------------------------------------------------------------
  -- seedmem: escritura (semilla de entrada o captura de la salida del sponge) y lectura
  ---------------------------------------------------------------------------
  process(state, seed_valid, k, seed_data, phase, sp_out_valid, cap_base, cap_cnt, sp_out_data)
  begin
    sm_we    <= '0';
    sm_waddr <= (others => '0');
    sm_wdata <= (others => '0');
    if state = S_SEED and seed_valid = '1' then
      sm_we    <= '1';
      sm_waddr <= to_unsigned(k, 5);
      sm_wdata <= seed_data;
    elsif phase = PH_CAP and sp_out_valid = '1' then
      sm_we    <= '1';
      sm_waddr <= to_unsigned(cap_base + cap_cnt, 5);
      sm_wdata <= sp_out_data;
    end if;
  end process;

  fb_addr  <= to_unsigned(f_base + fk, 5);
  sm_raddr <= out_sm_addr when (state = S_O_ADDR or state = S_O_SEND) else fb_addr;

  ---------------------------------------------------------------------------
  -- Direcciones de la etapa de salida
  ---------------------------------------------------------------------------
  process(part, ok)
  begin
    out_sm_addr  <= (others => '0');
    out_res_addr <= (others => '0');
    if part = '0' then
      if ok < 4 then
        out_sm_addr  <= to_unsigned(14 + ok, 5);          -- seed_ek
      else
        out_res_addr <= to_unsigned(ok - 4, 9);           -- s
      end if;
    else
      if ok < 4 then
        out_sm_addr <= to_unsigned(10 + ok, 5);           -- seed_dk
      elsif ok < 6 then
        out_sm_addr <= to_unsigned(8 + (ok - 4), 5);      -- sigma
      else
        out_sm_addr <= to_unsigned(ok - 6, 5);            -- seed_kem
      end if;
    end if;
  end process;

  out_valid <= '1' when state = S_O_SEND else '0';
  out_data  <= r_rdata when (part = '0' and ok >= 4) else sm_rdata;
  out_last  <= '1' when (state = S_O_SEND and
                         ((part = '0' and ok = OUT0_LAST) or (part = '1' and ok = 9))) else '0';
  out_part  <= part;

  ---------------------------------------------------------------------------
  -- Alimentador del sponge: comando + 4 palabras de seedmem + palabra con el byte de dominio
  --   (el mensaje son 33 bytes: seed || dominio; el padding SHAKE/SHA3 lo pone el sponge)
  ---------------------------------------------------------------------------
  sp_in_valid <= '1' when (fs = FS_CMD or fs = FS_SEND or fs = FS_DOM) else '0';
  dom_word(7 downto 0)  <= f_dom;
  dom_word(63 downto 8) <= (others => '0');
  sp_in_data  <= f_cmd    when fs = FS_CMD  else
                 sm_rdata when fs = FS_SEND else
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
          when FS_CMD =>                                  -- in_valid = '1'
            if sp_in_ready = '1' then
              fs <= FS_RD;
            end if;
          when FS_RD =>                                   -- direccion presentada; el dato llega en FS_SEND
            fs <= FS_SEND;
          when FS_SEND =>
            if sp_in_ready = '1' then
              if fk = 3 then
                fs <= FS_DOM;
              else
                fk <= fk + 1;
                fs <= FS_RD;
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
  -- FSM maestra
  ---------------------------------------------------------------------------
  process(clk)
    variable v_mul, v_smp : std_logic;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state     <= S_IDLE;
        phase     <= PH_NONE;
        step      <= 0;
        k         <= 0;
        cap_cnt   <= 0;
        smp_y_act <= '0';
        smp_x_act <= '0';
        f_mul     <= '0';
        f_smp     <= '0';
        abort_req <= '0';
        running   <= '0';
        part      <= '0';
        ok        <= 0;
      else
        abort_req <= '0';

        if running = '1' then
          cyc <= cyc + 1;
        end if;
        if phase = PH_CAP and sp_out_valid = '1' then       -- out_ready = '1' en esta fase
          cap_cnt <= cap_cnt + 1;
        end if;

        case state is

          when S_IDLE =>
            if start = '1' then
              k         <= 0;
              cyc       <= (others => '0');
              running   <= '1';
              phase     <= PH_NONE;
              smp_y_act <= '0';
              smp_x_act <= '0';
              state     <= S_SEED;
            end if;

          when S_SEED =>                                   -- seed_ready = '1'; escribe en seedmem[k]
            if seed_valid = '1' then
              if k = 3 then
                step  <= 1;
                state <= S_SETUP;
              else
                k <= k + 1;
              end if;
            end if;

          when S_SETUP =>
            cap_cnt <= 0;
            case step is
              when 1 =>
                f_cmd <= CMD1; f_base <= 0;  f_dom <= x"01";
                cap_base <= 4;  cap_total <= 6; phase <= PH_CAP;
              when 2 =>
                f_cmd <= CMD2; f_base <= 4;  f_dom <= x"02";
                cap_base <= 10; cap_total <= 8; phase <= PH_CAP;
              when 3 =>
                f_cmd <= CMD3; f_base <= 14; f_dom <= x"01";
                phase <= PH_H;
              when others =>
                f_cmd <= CMD4; f_base <= 10; f_dom <= x"01";
                phase <= PH_SMP;
                smp_y_act <= '1';
            end case;
            state <= S_GO;

          when S_GO =>                                      -- pulsos f_go / sv_start / smp_start
            state <= S_RUN;

          when S_RUN =>
            case step is
              when 1 | 2 =>
                if cap_cnt = cap_total then
                  step  <= step + 1;
                  state <= S_SETUP;
                end if;
              when 3 =>
                if sv_done = '1' then
                  step  <= 4;
                  state <= S_SETUP;
                end if;
              when others =>                                -- y listo: multiplicar y muestrear x a la vez
                if smp_done = '1' then
                  smp_y_act <= '0';
                  smp_x_act <= '1';
                  f_mul     <= '0';
                  f_smp     <= '0';
                  state     <= S_MUL_GO;
                end if;
            end case;

          when S_MUL_GO =>                                  -- pulsos mul_start / smp_start (x)
            state <= S_MUL_WAIT;

          when S_MUL_WAIT =>
            v_mul := f_mul or mul_done;
            v_smp := f_smp or smp_done;
            f_mul <= v_mul;
            f_smp <= v_smp;
            if smp_done = '1' then
              abort_req <= '1';                             -- x listo: cortar el flujo del sponge
              smp_x_act <= '0';
            end if;
            if v_mul = '1' and v_smp = '1' then
              state <= S_XOR_GO;
            end if;

          when S_XOR_GO =>                                  -- pulso xor_start
            state <= S_XOR_WAIT;

          when S_XOR_WAIT =>
            if xor_done = '1' then
              running  <= '0';
              cycles_r <= cyc;
              part     <= '0';
              ok       <= 0;
              state    <= S_O_ADDR;
            end if;

          when S_O_ADDR =>                                  -- direcciones presentadas; dato en S_O_SEND
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
            phase <= PH_NONE;
            state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;
