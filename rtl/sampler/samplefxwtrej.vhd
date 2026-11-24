library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- sample_fixed_wt_rej (HQC-128, WT = 66)
--
-- Equivalente a la referencia Python:
--   * El XOF se lee por lotes de 3*WT bytes = 198 bytes, que ocupan NWB = 25 palabras de 64 bits
--     (los 2 bytes de relleno se descartan). Dentro de un lote hay WT = 66 candidatos de 3 bytes.
--   * Cada candidato es BIG-ENDIAN: sup = b0<<16 | b1<<8 | b2 (b0 = primer byte del flujo).
--   * Si sup < N_REJ: sup mod N (Barrett + correccion), y si el bit no esta ocupado se acepta.
--   * Solo se pide un lote nuevo si se agotaron los 66 candidatos y aun faltan posiciones.
--   * Al terminar se consumen (descartan) las palabras que falten del lote actual, para que el
--     flujo SHAKE quede alineado para la siguiente llamada (y -> x).
--   * Al final se limpia el bitmap leyendo las posiciones desde pos_mem.
--
-- Gearbox 64 -> 24: buffer de 10 bytes (buf) con cnt bytes validos en los LSB.
-- Handshake con SHAKE: transferencia con shake_valid = shake_ready = '1'.
entity samplefxwtrej is
  generic(
    N               : integer := 17669;
    N_32            : integer := 243079;  -- floor(2^32 / N)
    WT              : integer := 66;
    SHAKE_BYTE_SWAP : boolean := false    -- true si SHAKE entrega el byte 0 en bits 63:56
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

architecture rtl of samplefxwtrej is

  -- n_rej = (2^24 // N) * N = 949 * 17669 = 16767881
  constant N_REJ : integer := (2**24 / N) * N;
  constant NWB   : integer := (3*WT + 7) / 8;  -- palabras de 64 bits por lote (25)
  constant NC    : integer := WT;              -- candidatos de 24 bits por lote (66)

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

  type state_type is (IDLE, S_GET, S_TAKE, S_CHK, S_RED, S_FIX, S_BMRD, S_BMCHK,
                      S_NEXT, S_DRAIN, CLEAN, CLEAN_END, DONE);
  signal fsm : state_type := IDLE;

  -- gearbox 64 -> 24
  signal buf : std_logic_vector(79 downto 0) := (others => '0');
  signal cnt : integer range 0 to 10 := 0;     -- bytes validos en buf
  signal bw  : integer range 0 to NWB := 0;    -- palabras del lote ya pedidas a SHAKE
  signal bc  : integer range 0 to NC := 0;     -- candidatos del lote ya tomados
  signal ready_i : std_logic;

  -- datapath
  signal i    : integer range 0 to WT := 0;    -- posiciones aceptadas (luego, indice de limpieza)
  signal u24  : unsigned(23 downto 0) := (others => '0');
  signal mult : unsigned(41 downto 0) := (others => '0');
  signal r    : unsigned(15 downto 0) := (others => '0');
  signal posn : unsigned(14 downto 0) := (others => '0');

  -- salida registrada hacia pos_mem
  signal wr_en_i   : std_logic := '0';
  signal wr_addr_i : unsigned(6 downto 0)  := (others => '0');
  signal wr_data_i : unsigned(14 downto 0) := (others => '0');

  signal cl_v : std_logic := '0';

begin

  -- ===================== combinacional =====================
  ready_i <= '1' when ((fsm = S_GET and cnt < 3) or (fsm = S_DRAIN and bw < NWB)) else '0';
  shake_ready <= ready_i;

  rd_addr <= to_unsigned(i, 7);
  bm_addr <= posn when (fsm = S_BMRD or fsm = S_BMCHK) else rd_data;
  bm_we   <= '1' when ((fsm = S_BMCHK and bm_dout = '0') or cl_v = '1') else '0';
  bm_din  <= '1' when fsm = S_BMCHK else '0';

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
        sample_done <= '0';
        wr_en_i     <= '0';
        cl_v        <= '0';
        cnt         <= 0;
        bw          <= 0;
        bc          <= 0;
        i           <= 0;
        buf         <= (others => '0');

      else
        sample_done <= '0';
        wr_en_i     <= '0';

        if SHAKE_BYTE_SWAP then
          v_in := bswap64(shake_din);
        else
          v_in := shake_din;
        end if;

        case fsm is

          when IDLE =>
            if start = '1' then
              i   <= 0;
              cnt <= 0;
              bw  <= 0;
              bc  <= 0;
              buf <= (others => '0');
              fsm <= S_GET;
            end if;

          -- Hay 3 bytes en el buffer? si no, pedir una palabra (ready_i = '1' aqui)
          when S_GET =>
            if cnt >= 3 then
              fsm <= S_TAKE;
            elsif shake_valid = '1' then
              buf <= buf or std_logic_vector(shift_left(resize(unsigned(v_in), 80), 8*cnt));
              cnt <= cnt + 8;
              bw  <= bw + 1;
            end if;

          -- Candidato big-endian: primer byte del flujo = MSB
          when S_TAKE =>
            u24 <= unsigned(std_logic_vector'(buf(7 downto 0) & buf(15 downto 8) & buf(23 downto 16)));
            buf <= std_logic_vector'(x"000000" & buf(79 downto 24));
            cnt <= cnt - 3;
            bc  <= bc + 1;
            fsm <= S_CHK;

          -- Rechazo y multiplicacion de Barrett
          when S_CHK =>
            mult <= u24 * to_unsigned(N_32, 18);
            if u24 < to_unsigned(N_REJ, 24) then
              fsm <= S_RED;
            else
              fsm <= S_NEXT;
            end if;

          -- r = u24 - q*N, con q = (u24*N_32) >> 32 (q puede ser 1 menos que el real)
          when S_RED =>
            r   <= resize(u24, 16) - resize(mult(41 downto 32) * to_unsigned(N, 15), 16);
            fsm <= S_FIX;

          -- correccion: r en [0, 2N) -> r mod N
          when S_FIX =>
            if r >= to_unsigned(N, 16) then
              posn <= resize(r - to_unsigned(N, 16), 15);
            else
              posn <= resize(r, 15);
            end if;
            fsm <= S_BMRD;

          when S_BMRD =>             -- bm_addr = posn
            fsm <= S_BMCHK;

          when S_BMCHK =>            -- bm_dout = bit ocupado
            if bm_dout = '0' then    -- nueva: marcar bit (bm_we) y guardar en pos_mem
              wr_en_i   <= '1';
              wr_addr_i <= to_unsigned(i, 7);
              wr_data_i <= posn;
              i         <= i + 1;
              if i = WT-1 then
                fsm <= S_DRAIN;
              else
                fsm <= S_NEXT;
              end if;
            else                     -- duplicada: se ignora
              fsm <= S_NEXT;
            end if;

          -- Lote agotado y faltan posiciones -> descartar los 2 bytes de relleno, lote nuevo
          when S_NEXT =>
            if bc = NC then
              buf <= (others => '0');
              cnt <= 0;
              bw  <= 0;
              bc  <= 0;
            end if;
            fsm <= S_GET;

          -- Alinear SHAKE: consumir las palabras restantes del lote actual
          when S_DRAIN =>
            if bw = NWB then
              i   <= WT-1;
              fsm <= CLEAN;
            elsif shake_valid = '1' then
              bw <= bw + 1;
            end if;

          -- Limpiar bitmap leyendo las WT posiciones de pos_mem (1 por ciclo)
          when CLEAN =>
            cl_v <= '1';
            if i = 0 then
              fsm <= CLEAN_END;
            else
              i <= i - 1;
            end if;

          when CLEAN_END =>
            cl_v <= '0';
            fsm  <= DONE;

          when DONE =>
            sample_done <= '1';
            fsm         <= IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;