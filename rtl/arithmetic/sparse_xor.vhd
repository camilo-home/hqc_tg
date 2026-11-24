-- ============================================================================
-- sparse_xor : mem <= mem XOR (vector disperso)
--
-- Para cada una de las n_pos posiciones de pos_mem invierte ese bit en una memoria densa de
-- palabras de 64 bits (lectura-modificacion-escritura). Se usa para:
--   keygen : s = y*h  XOR x          (x = posiciones del sampler rej)
--   encaps : u = r2*h XOR r1 ;  v = ... XOR e
--   y para v = cm XOR r2*s XOR e (el XOR denso de cm es aparte).
--
-- Orden de bits: posicion p -> palabra p/64, bit p mod 64 (igual que poly_mul2 y sample_vect).
-- Las posiciones deben ser < N: la cola de la ultima palabra no se toca. Si una posicion
-- se repite se invierte dos veces (se cancela), igual que el XOR matematico.
--
-- Ritmo: 3 ciclos por posicion (la siguiente se lee por adelantado) y sin riesgos: la
-- escritura de una posicion termina antes de que se lea la siguiente, aunque caigan en la
-- misma palabra.   Latencia start -> done = 3*n_pos + 3 ciclos  (n_pos=75 -> 228).
--
-- Memorias (lectura registrada, latencia 1, como tus bram_singleport / position_mem):
--   pos_mem : pos_addr -> pos_data
--   destino : mem_we / mem_addr / mem_din / mem_dout (un solo puerto; read-before-write)
-- El destino tambien lo escribe poly_mul2 (res_*): el top decide quien lo maneja con un mux.
--
-- Protocolo: start (pulso, con ready='1') captura n_pos (>= 1); done = pulso de 1 ciclo.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sparse_xor is
  generic(
    POS_W : integer := 15;   -- bits de una posicion
    PA_W  : integer := 7;    -- bits de direccion de pos_mem
    AW    : integer := 9     -- bits de direccion de la memoria densa
  );
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;

    start : in  std_logic;
    n_pos : in  unsigned(PA_W - 1 downto 0);
    ready : out std_logic;
    done  : out std_logic;

    pos_addr : out unsigned(PA_W - 1 downto 0);
    pos_data : in  unsigned(POS_W - 1 downto 0);

    mem_we   : out std_logic;
    mem_addr : out unsigned(AW - 1 downto 0);
    mem_din  : out std_logic_vector(63 downto 0);
    mem_dout : in  std_logic_vector(63 downto 0)
  );
end entity;

architecture rtl of sparse_xor is

  type state_t is (S_IDLE, S_L0, S_L1, S_RD0, S_RD1, S_WR, S_DONE);
  signal state : state_t := S_IDLE;

  signal idx   : integer range 0 to 2**PA_W - 1 := 0;
  signal npos  : integer range 0 to 2**PA_W - 1 := 0;
  signal pa    : unsigned(PA_W - 1 downto 0) := (others => '0');
  signal wi    : unsigned(AW - 1 downto 0)   := (others => '0');   -- palabra de la posicion actual
  signal bi    : integer range 0 to 63 := 0;                       -- bit dentro de la palabra
  signal wdata : std_logic_vector(63 downto 0) := (others => '0');

begin

  ready    <= '1' when state = S_IDLE else '0';
  done     <= '1' when state = S_DONE else '0';
  pos_addr <= pa;
  mem_addr <= wi;
  mem_din  <= wdata;
  mem_we   <= '1' when state = S_WR else '0';

  process(clk)
    variable oh : std_logic_vector(63 downto 0);
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_IDLE;
        idx   <= 0;
        pa    <= (others => '0');
      else
        case state is

          when S_IDLE =>
            if start = '1' then
              npos  <= to_integer(n_pos);
              idx   <= 0;
              pa    <= (others => '0');
              state <= S_L0;
            end if;

          when S_L0 =>                             -- pos_addr = 0 presentada
            state <= S_L1;

          when S_L1 =>                             -- pos_data = posicion 0
            wi    <= resize(pos_data(POS_W - 1 downto 6), AW);
            bi    <= to_integer(pos_data(5 downto 0));
            state <= S_RD0;

          when S_RD0 =>                            -- mem_addr = wi presentada (lectura)
            pa    <= to_unsigned(idx + 1, PA_W);   -- adelantar la posicion siguiente
            state <= S_RD1;

          when S_RD1 =>                            -- mem_dout valido: invertir el bit
            oh     := (others => '0');
            oh(bi) := '1';
            wdata  <= mem_dout xor oh;
            state  <= S_WR;

          when S_WR =>                             -- mem_we = '1': se escribe wdata en wi
            if idx = npos - 1 then
              state <= S_DONE;
            else
              idx   <= idx + 1;
              wi    <= resize(pos_data(POS_W - 1 downto 6), AW);   -- posicion siguiente (ya leida)
              bi    <= to_integer(pos_data(5 downto 0));
              state <= S_RD0;
            end if;

          when S_DONE =>
            state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;
