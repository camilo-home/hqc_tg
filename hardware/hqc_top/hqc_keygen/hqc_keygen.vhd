-- ============================================================================
-- hqc_keygen (v3) : HQC-128 KeyGen
--
--   entrada : pulso start y luego seed_kem (4 palabras de 64 bits, valid/ready)
--   salida  : parte 0 (out_part='0'): ek = seed_ek(32 B) || s(2209 B)                -> 281 palabras
--             parte 1 (out_part='1'): seed_dk(32 B) || sigma(16 B) || seed_kem(32 B) -> 10 palabras
--             dk = ek || parte 1.   out_last marca la ultima palabra de cada parte.
--   cycles  : ciclos desde start hasta tener s listo (antes de sacar datos)
--   Bytes en palabras: byte 0 en los bits [7:0] (igual que el sponge).
--
-- Organizacion:
--   * Claves intermedias en arrays con nombre propio (seed_kem_r, seed_pke_r, sigma_r, seed_dk_r, seed_ek_r).
--     En una Cyclone IV E (DE2-115) NO hay MLAB: se sintetizan como registros (lectura inmediata).
--   * state : dirige que motor trabaja ;  phase : dirige el RUTEO (sponge -> store / sample_vect / sampler,
--     y que banco de posiciones escribe el sampler).
--   * Un unico sponge genera, uno detras de otro, los flujos de todos los destinos.
--   * Bancos de posiciones DEDICADOS: Y y X. Memoria densa unica "hs": primero h (la escribe sample_vect),
--     luego poly_mul2 escribe y*h EN SU LUGAR (ya no lee h) y sparse_xor la convierte en s = y*h xor x.
--
-- Secuencia (state):
--   S_SEED   recibe seed_kem
--   S_LAUNCH lanza el comando siguiente al sponge (step 1..4)
--   S_STORE  captura la salida del sponge en las claves intermedias:
--              step 1: SHAKE256(seed_kem||01), 48 B   -> seed_pke, sigma
--              step 2: SHA3-512(seed_pke||02), 64 B   -> seed_dk, seed_ek
--   S_H      step 3: SHAKE256(seed_ek||01), 2216 B   -> sample_vect -> h (memoria hs)
--   S_Y      step 4: SHAKE256(seed_dk||01), SIN LIMITE (se corta con abort) -> sampler -> y (banco Y)
--   S_MX     poly_mul2: y*h (-> hs)   y   sampler -> x (banco X), del MISMO flujo.
--              OVERLAP=true : x se muestrea a la vez que se multiplica ;  false: x tras la multiplicacion.
--              abort al terminar x.
--   S_XOR    sparse_xor: hs <- hs xor x   (= s)
--   S_O_*    salida
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.keccak_sponge_pkg.all;

entity hqc_keygen is
  generic(
    WT      : integer := 66;      -- peso de x e y (HQC-128)
    OVERLAP : boolean := true     -- true: muestrear x mientras corre poly_mul2
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
    dbg_state : out std_logic_vector(3 downto 0)
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

  type state_t  is (S_IDLE, S_SEED, S_LAUNCH, S_STORE, S_H, S_Y, S_MX, S_XOR,
                    S_O_ADDR, S_O_SEND, S_DONE);
  type phase_t  is (PH_NONE, PH_STORE, PH_H, PH_Y, PH_X);
  type fstate_t is (FS_IDLE, FS_CMD, FS_SEND, FS_DOM);
  type words4_t is array (0 to 3) of std_logic_vector(63 downto 0);
  type words2_t is array (0 to 1) of std_logic_vector(63 downto 0);

  signal state : state_t := S_IDLE;
  signal phase : phase_t := PH_NONE;
  signal fs    : fstate_t := FS_IDLE;

  -- claves intermedias (registros con nombre)
  signal seed_kem_r : words4_t := (others => (others => '0'));
  signal seed_pke_r : words4_t := (others => (others => '0'));
  signal seed_dk_r  : words4_t := (others => (others => '0'));
  signal seed_ek_r  : words4_t := (others => (others => '0'));
  signal sigma_r    : words2_t := (others => (others => '0'));

  signal step      : integer range 0 to 4 := 0;
  signal k         : integer range 0 to 3 := 0;
  signal fk        : integer range 0 to 3 := 0;
  signal f_src     : integer range 0 to 3 := 0;      -- 0 seed_kem, 1 seed_pke, 2 seed_ek, 3 seed_dk
  signal store_sel : integer range 0 to 1 := 0;      -- 0 -> seed_pke,sigma ; 1 -> seed_dk,seed_ek
  signal cap_cnt   : integer range 0 to 8 := 0;
  signal cap_total : integer range 0 to 8 := 0;
  signal f_cmd     : std_logic_vector(63 downto 0) := (others => '0');
  signal f_dom     : std_logic_vector(7 downto 0) := (others => '0');
  signal dom_word  : std_logic_vector(63 downto 0);

  signal mul_fin, x_fin, x_started : std_logic := '0';

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

  -- bancos de posiciones dedicados
  signal we_y, we_x : std_logic;
  signal rd_y, rd_x, mul_pos_addr, xor_pos_addr : unsigned(6 downto 0);
  signal bankY_dout, bankX_dout : unsigned(14 downto 0);

  -- memoria densa/resultado unica "hs" (h, luego y*h, luego s)
  signal hs_we : std_logic;
  signal hs_waddr, hs_raddr, dense_addr, res_addr, xor_mem_addr, out_hs_addr : unsigned(8 downto 0);
  signal hs_wdata, hs_rdata, res_a_data, xor_mem_din : std_logic_vector(63 downto 0);

  -- acumulador de poly_mul2
  signal acc_addr1, acc_addr2 : unsigned(9 downto 0);
  signal acc_we1, acc_we2 : std_logic;
  signal acc_din1, accA_din2, accA_dout1, accA_dout2 : std_logic_vector(63 downto 0);

  signal mul_done, res_we, xor_done, xor_mem_we : std_logic;

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
              pos_addr => mul_pos_addr, pos_data => bankY_dout,
              dense_addr => dense_addr, dense_a_data => hs_rdata, dense_b_data => ZERO64,
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
              pos_addr => xor_pos_addr, pos_data => bankX_dout,
              mem_we => xor_mem_we, mem_addr => xor_mem_addr, mem_din => xor_mem_din, mem_dout => hs_rdata);

  u_bank_y : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => we_y, wr_addr => smp_wr_addr, din => smp_wr_data,
              rd_addr => rd_y, dout => bankY_dout);
  u_bank_x : entity work.position_mem
    generic map (DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map (clk => clk, we => we_x, wr_addr => smp_wr_addr, din => smp_wr_data,
              rd_addr => rd_x, dout => bankX_dout);

  u_hs : entity work.ram64_sdp
    generic map (DEPTH => 277, ADDR_W => 9)
    port map (clk => clk, we => hs_we, waddr => hs_waddr, wdata => hs_wdata,
              raddr => hs_raddr, rdata => hs_rdata);

  u_acc : entity work.ram64_tdp
    generic map (DEPTH => 554, ADDR_W => 10)
    port map (clk => clk,
              we_1 => acc_we1, addr_1 => acc_addr1, din_1 => acc_din1, dout_1 => accA_dout1,
              we_2 => acc_we2, addr_2 => acc_addr2, din_2 => accA_din2, dout_2 => accA_dout2);

  ---------------------------------------------------------------------------
  -- Salidas simples
  ---------------------------------------------------------------------------
  ready      <= '1' when state = S_IDLE else '0';
  seed_ready <= '1' when state = S_SEED else '0';
  done       <= '1' when state = S_DONE else '0';
  cycles     <= cycles_r;
  dbg_state  <= std_logic_vector(to_unsigned(state_t'pos(state), 4));

  ---------------------------------------------------------------------------
  -- RUTEO (phase): salida del sponge y bancos de posiciones
  ---------------------------------------------------------------------------
  sp_out_ready <= '1'             when phase = PH_STORE else
                  sv_din_ready    when phase = PH_H     else
                  smp_shake_ready when (phase = PH_Y or phase = PH_X) else
                  '0';
  sv_din_valid    <= sp_out_valid when phase = PH_H else '0';
  smp_shake_valid <= sp_out_valid when (phase = PH_Y or phase = PH_X) else '0';

  we_y        <= smp_wr_en when phase = PH_Y else '0';
  we_x        <= smp_wr_en when phase = PH_X else '0';
  rd_y        <= smp_rd_addr when phase = PH_Y else mul_pos_addr;     -- Y: sampler (limpieza) o poly_mul2
  rd_x        <= smp_rd_addr when phase = PH_X else xor_pos_addr;     -- X: sampler (limpieza) o sparse_xor
  smp_rd_data <= bankY_dout  when phase = PH_Y else bankX_dout;

  ---------------------------------------------------------------------------
  -- Memoria hs: escribe sample_vect (S_H), poly_mul2 (S_MX) o sparse_xor (S_XOR); lee poly_mul2,
  -- sparse_xor o la etapa de salida
  ---------------------------------------------------------------------------
  hs_we    <= sv_wr_en when state = S_H else xor_mem_we when state = S_XOR else res_we;
  hs_waddr <= sv_wr_addr when state = S_H else xor_mem_addr when state = S_XOR else res_addr;
  hs_wdata <= sv_wr_data when state = S_H else xor_mem_din when state = S_XOR else res_a_data;
  hs_raddr <= dense_addr when state = S_MX else xor_mem_addr when state = S_XOR else out_hs_addr;

  ---------------------------------------------------------------------------
  -- Alimentador del sponge: comando + 4 palabras de la clave elegida + palabra con el byte de dominio
  ---------------------------------------------------------------------------
  dom_word(7 downto 0)  <= f_dom;
  dom_word(63 downto 8) <= (others => '0');
  sp_in_valid <= '1' when (fs = FS_CMD or fs = FS_SEND or fs = FS_DOM) else '0';

  process(fs, f_cmd, f_src, fk, dom_word, seed_kem_r, seed_pke_r, seed_ek_r, seed_dk_r)
  begin
    sp_in_data <= dom_word;
    if fs = FS_CMD then
      sp_in_data <= f_cmd;
    elsif fs = FS_SEND then
      case f_src is
        when 0      => sp_in_data <= seed_kem_r(fk);
        when 1      => sp_in_data <= seed_pke_r(fk);
        when 2      => sp_in_data <= seed_ek_r(fk);
        when others => sp_in_data <= seed_dk_r(fk);
      end case;
    end if;
  end process;

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
  -- Etapa de salida: parte 0 = seed_ek, s ; parte 1 = seed_dk, sigma, seed_kem
  ---------------------------------------------------------------------------
  process(part, ok, hs_rdata, seed_ek_r, seed_dk_r, sigma_r, seed_kem_r)
  begin
    out_hs_addr <= (others => '0');
    out_data    <= (others => '0');
    if part = '0' then
      if ok < 4 then
        out_data <= seed_ek_r(ok);
      else
        out_hs_addr <= to_unsigned(ok - 4, 9);
        out_data    <= hs_rdata;
      end if;
    else
      if ok < 4 then
        out_data <= seed_dk_r(ok);
      elsif ok < 6 then
        out_data <= sigma_r(ok - 4);
      else
        out_data <= seed_kem_r(ok - 6);
      end if;
    end if;
  end process;

  out_valid <= '1' when state = S_O_SEND else '0';
  out_last  <= '1' when (state = S_O_SEND and
                         ((part = '0' and ok = OUT0_LAST) or (part = '1' and ok = 9))) else '0';
  out_part  <= part;

  ---------------------------------------------------------------------------
  -- FSM maestra (state)
  ---------------------------------------------------------------------------
  process(clk)
    variable v_mul, v_x : std_logic;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state     <= S_IDLE;
        phase     <= PH_NONE;
        step      <= 0;
        k         <= 0;
        cap_cnt   <= 0;
        running   <= '0';
        part      <= '0';
        ok        <= 0;
        mul_fin   <= '0';
        x_fin     <= '0';
        x_started <= '0';
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

        -- STORE: captura explicita de la salida del sponge en las claves intermedias (out_ready = '1')
        if state = S_STORE and sp_out_valid = '1' then
          if store_sel = 0 then
            if cap_cnt < 4 then
              seed_pke_r(cap_cnt) <= sp_out_data;
            else
              sigma_r(cap_cnt - 4) <= sp_out_data;
            end if;
          else
            if cap_cnt < 4 then
              seed_dk_r(cap_cnt) <= sp_out_data;
            else
              seed_ek_r(cap_cnt - 4) <= sp_out_data;
            end if;
          end if;
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
              seed_kem_r(k) <= seed_data;
              if k = 3 then
                step  <= 1;
                state <= S_LAUNCH;
              else
                k <= k + 1;
              end if;
            end if;

          when S_LAUNCH =>                                  -- lanza el comando 'step' (pulsos en el ciclo siguiente)
            f_go <= '1';
            case step is
              when 1 =>                                     -- SHAKE256(seed_kem||01) -> seed_pke, sigma
                f_cmd <= CMD1; f_src <= 0; f_dom <= x"01";
                store_sel <= 0; cap_total <= 6; cap_cnt <= 0;
                phase <= PH_STORE; state <= S_STORE;
              when 2 =>                                     -- SHA3-512(seed_pke||02) -> seed_dk, seed_ek
                f_cmd <= CMD2; f_src <= 1; f_dom <= x"02";
                store_sel <= 1; cap_total <= 8; cap_cnt <= 0;
                phase <= PH_STORE; state <= S_STORE;
              when 3 =>                                     -- SHAKE256(seed_ek||01), 2216 B -> sample_vect
                f_cmd <= CMD3; f_src <= 2; f_dom <= x"01";
                sv_start <= '1';
                phase <= PH_H; state <= S_H;
              when others =>                                -- SHAKE256(seed_dk||01) sin limite -> y
                f_cmd <= CMD4; f_src <= 3; f_dom <= x"01";
                smp_start <= '1';
                phase <= PH_Y; state <= S_Y;
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

          when S_Y =>
            if smp_done = '1' then
              mul_start <= '1';                             -- y*h
              mul_fin   <= '0';
              x_fin     <= '0';
              if OVERLAP then
                smp_start <= '1';                           -- x a la vez, del MISMO flujo
                phase     <= PH_X;
                x_started <= '1';
              else
                phase     <= PH_NONE;
                x_started <= '0';
              end if;
              state <= S_MX;
            end if;

          when S_MX =>
            v_mul := mul_fin or mul_done;
            v_x   := x_fin or smp_done;
            mul_fin <= v_mul;
            x_fin   <= v_x;
            if (not OVERLAP) and v_mul = '1' and x_started = '0' then
              smp_start <= '1';                             -- secuencial: x tras la multiplicacion
              phase     <= PH_X;
              x_started <= '1';
            end if;
            if smp_done = '1' then
              abort_req <= '1';                             -- x listo: cortar el flujo del sponge
              phase     <= PH_NONE;
            end if;
            if v_mul = '1' and v_x = '1' then
              xor_start <= '1';                             -- hs <- hs xor x
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
            phase <= PH_NONE;
            state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;
