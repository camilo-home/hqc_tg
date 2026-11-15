library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- sample_fixed_wt_mod (HQC-128, WT = 75)
--
-- Equivalente bit a bit a la referencia Python:
--   Fase 1: se leen NW = ceil(WT/2) palabras de 64 bits de SHAKE (consume tambien el relleno
--           de 4 bytes cuando WT es impar). Cada u32 (little-endian, low primero) da
--           supp[i] = ((u32 * (N - i)) >> 32) + i, que se guarda en pos_mem[i] (ascendente).
--   Fase 2: i = WT-1 .. 0. Si supp[i] ya esta en el bitmap -> supp[i] = i. Se marca el bit
--           y se reescribe pos_mem[i] con el valor final.
--   Fase 3: se recorren las WT posiciones finales y se limpian sus bits del bitmap
--           (el bitmap queda en cero para la siguiente llamada).
--
-- Handshake con SHAKE: la transferencia ocurre en el flanco con shake_valid = shake_ready = '1'.
-- shake_ready solo depende de registros internos y nunca se pide mas de NW palabras por llamada,
-- asi el flujo queda alineado para la siguiente llamada (r2 -> e -> r1).
entity samplefxwtmod is
  generic(
    N               : integer := 17669;
    WT              : integer := 75;
    SHAKE_BYTE_SWAP : boolean := false  -- true si SHAKE entrega el byte 0 en bits 63:56
  );
  port(
    clk         : in  std_logic;
    rst         : in  std_logic;
    start       : in  std_logic;  -- pulso

    -- SHAKE256 (64 bits, valid/ready)
    shake_din   : in  std_logic_vector(63 downto 0);
    shake_valid : in  std_logic;
    shake_ready : out std_logic;

    -- pos_mem (escritura y lectura)
    wr_en       : out std_logic;
    wr_addr     : out unsigned(6 downto 0);
    wr_data     : out unsigned(14 downto 0);
    rd_addr     : out unsigned(6 downto 0);
    rd_data     : in  unsigned(14 downto 0);  -- valido 1 ciclo despues de rd_addr

    sample_done : out std_logic  -- pulso: posiciones completas y bitmap limpio
  );
end entity;

architecture rtl of samplefxwtmod is

  constant NW : integer := (WT + 1) / 2;  -- palabras de 64 bits por llamada (38)

  function bswap64(x : std_logic_vector(63 downto 0)) return std_logic_vector is
    variable r : std_logic_vector(63 downto 0);
  begin
    for k in 0 to 7 loop
      r(8*k+7 downto 8*k) := x(63-8*k downto 56-8*k);
    end loop;
    return r;
  end function;

  -- bitmap de posiciones ocupadas: 1 bit x N
  type bm_type is array (0 to N-1) of std_logic_vector(0 downto 0);
  signal bm_mem : bm_type := (others => "0");
  attribute ramstyle : string;
  attribute ramstyle of bm_mem : signal is "M9K, no_rw_check";

  signal bm_addr : unsigned(14 downto 0);
  signal bm_we   : std_logic;
  signal bm_din  : std_logic;
  signal bm_dout : std_logic := '0';

  type state_type is (IDLE, P1, P2_RD, P2_BM, P2_DEC, CLEAN, CLEAN_END, DONE);
  signal fsm : state_type := IDLE;

  -- gearbox 64 -> 32
  signal word      : std_logic_vector(63 downto 0) := (others => '0');
  signal word_v    : std_logic := '0';
  signal half      : std_logic := '0';  -- 0: u32 bajo, 1: u32 alto
  signal widx      : integer range 0 to NW := 0;  -- palabras aceptadas
  signal idx       : integer range 0 to WT := 0;  -- u32 emitidos
  signal m_cnt     : unsigned(14 downto 0) := (others => '0');  -- N - idx
  signal consume   : std_logic;
  signal will_free : std_logic;
  signal ready_i   : std_logic;

  -- pipeline fase 1
  signal s1_v    : std_logic := '0';
  signal s1_u32  : unsigned(31 downto 0) := (others => '0');
  signal s1_m    : unsigned(14 downto 0) := (others => '0');
  signal s1_i    : unsigned(6 downto 0)  := (others => '0');
  signal s2_v    : std_logic := '0';
  signal s2_mult : unsigned(46 downto 0) := (others => '0');
  signal s2_i    : unsigned(6 downto 0)  := (others => '0');
  signal wcnt    : integer range 0 to WT := 0;  -- escrituras de fase 1 realizadas

  -- salida registrada hacia pos_mem
  signal wr_en_i   : std_logic := '0';
  signal wr_addr_i : unsigned(6 downto 0)  := (others => '0');
  signal wr_data_i : unsigned(14 downto 0) := (others => '0');

  -- fase 2 / limpieza
  signal k         : integer range 0 to WT-1 := 0;  -- indice descendente
  signal cur       : unsigned(14 downto 0) := (others => '0');
  signal final_pos : unsigned(14 downto 0);
  signal cl_v      : std_logic := '0';

begin

  -- ===================== combinacional =====================
  consume   <= '1' when (fsm = P1 and word_v = '1' and idx < WT) else '0';
  will_free <= '1' when (consume = '1' and (half = '1' or idx = WT-1)) else '0';
  ready_i   <= '1' when (fsm = P1 and widx < NW and (word_v = '0' or will_free = '1')) else '0';
  shake_ready <= ready_i;

  -- duplicado -> la posicion pasa a ser i; si no, se queda el valor crudo
  final_pos <= to_unsigned(k, 15) when bm_dout = '1' else cur;

  rd_addr <= to_unsigned(k, 7);
  bm_addr <= final_pos when fsm = P2_DEC else rd_data;
  bm_we   <= '1' when (fsm = P2_DEC or cl_v = '1') else '0';
  bm_din  <= '1' when fsm = P2_DEC else '0';

  wr_en   <= wr_en_i;
  wr_addr <= wr_addr_i;
  wr_data <= wr_data_i;

  -- ===================== bitmap (lectura sincrona, 1 ciclo) =====================
  process(clk)
  begin
    if rising_edge(clk) then
      if bm_we = '1' then
        bm_mem(to_integer(bm_addr)) <= (0 => bm_din);
      end if;
      bm_dout <= bm_mem(to_integer(bm_addr))(0);
    end if;
  end process;

  -- ===================== FSM + datapath =====================
  process(clk)
    variable v_in : std_logic_vector(63 downto 0);
  begin
    if rising_edge(clk) then

      if rst = '1' then
        fsm         <= IDLE;
        word_v      <= '0';
        half        <= '0';
        widx        <= 0;
        idx         <= 0;
        wcnt        <= 0;
        s1_v        <= '0';
        s2_v        <= '0';
        wr_en_i     <= '0';
        cl_v        <= '0';
        sample_done <= '0';

      else
        -- valores por defecto
        sample_done <= '0';
        wr_en_i     <= '0';
        s1_v        <= '0';
        s2_v        <= s1_v;
        s2_i        <= s1_i;
        s2_mult     <= s1_u32 * s1_m;

        if SHAKE_BYTE_SWAP then
          v_in := bswap64(shake_din);
        else
          v_in := shake_din;
        end if;

        case fsm is

          when IDLE =>
            if start = '1' then
              idx    <= 0;
              widx   <= 0;
              wcnt   <= 0;
              word_v <= '0';
              half   <= '0';
              m_cnt  <= to_unsigned(N, 15);
              fsm    <= P1;
            end if;

          -- ---------- Fase 1: streaming, 1 u32 por ciclo ----------
          when P1 =>
            if consume = '1' then
              s1_v <= '1';
              if half = '1' then
                s1_u32 <= unsigned(word(63 downto 32));
              else
                s1_u32 <= unsigned(word(31 downto 0));
              end if;
              s1_m  <= m_cnt;
              s1_i  <= to_unsigned(idx, 7);
              m_cnt <= m_cnt - 1;
              idx   <= idx + 1;
              if will_free = '1' then
                word_v <= '0';
                half   <= '0';
              else
                half <= '1';
              end if;
            end if;

            -- transferencia SHAKE -> gearbox (gana sobre el vaciado del mismo ciclo)
            if ready_i = '1' and shake_valid = '1' then
              word   <= v_in;
              word_v <= '1';
              half   <= '0';
              widx   <= widx + 1;
            end if;

            -- todas las escrituras crudas ya estan en pos_mem
            if wcnt = WT then
              k   <= WT-1;
              fsm <= P2_RD;
            end if;

          -- ---------- Fase 2: i descendente, 3 ciclos por posicion ----------
          when P2_RD =>              -- rd_addr = k
            fsm <= P2_BM;

          when P2_BM =>              -- rd_data = supp[k]; bm_addr = rd_data (lectura bitmap)
            cur <= rd_data;
            fsm <= P2_DEC;

          when P2_DEC =>             -- bm_dout = bit ocupado; se marca y se reescribe
            wr_en_i   <= '1';
            wr_addr_i <= to_unsigned(k, 7);
            wr_data_i <= final_pos;
            if k = 0 then
              k   <= WT-1;
              fsm <= CLEAN;
            else
              k   <= k - 1;
              fsm <= P2_RD;
            end if;

          -- ---------- Fase 3: limpiar bitmap (1 posicion por ciclo) ----------
          when CLEAN =>
            cl_v <= '1';
            if k = 0 then
              fsm <= CLEAN_END;
            else
              k <= k - 1;
            end if;

          when CLEAN_END =>
            cl_v <= '0';
            fsm  <= DONE;

          when DONE =>
            sample_done <= '1';
            fsm         <= IDLE;

        end case;

        -- etapa 3 del pipeline de fase 1: posicion cruda -> pos_mem[i]
        if s2_v = '1' then
          wr_en_i   <= '1';
          wr_addr_i <= s2_i;
          wr_data_i <= s2_mult(46 downto 32) + resize(s2_i, 15);
          wcnt      <= wcnt + 1;
        end if;

      end if;
    end if;
  end process;

end rtl;
