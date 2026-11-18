-- ============================================================================
-- sample_vect : sample_vect() de hqc128.py (vector denso de N bits), version de 64 bits.
--
-- Entrada : flujo de palabras de 64 bits desde keccak_sponge (ready/valid).
--           Consume EXACTAMENTE ceil(N_SZ/8) palabras (277 para HQC-128), que es lo que
--           consume xof_get_bytes(n_sz) (incluido el relleno a multiplo de 8 bytes), asi el
--           siguiente consumidor del mismo flujo queda alineado.
-- Salida  : BRAM externa de 64 bits (la que lee poly_mul2): una escritura por palabra del
--           sponge, wr_addr = 0 .. 276, a 1 palabra por ciclo si el sponge no se frena.
--           La ultima palabra se enmascara: el byte N_SZ-1 conserva solo los N mod 8 bits
--           validos (v &= (1<<N)-1) y los bytes >= N_SZ salen a 0 => en HQC-128 la palabra 276
--           solo tiene 5 bits distintos de cero, que es lo que exige poly_mul2.
--
-- Orden de bytes: byte 0 del flujo = bits [7:0] de la palabra 0 (igual que el sponge);
--                 bit i del vector = bit (i mod 64) de la palabra i/64.
--
-- Handshake: din_ready depende solo del estado. Una palabra se transfiere en el flanco en
-- que din_valid='1' y din_ready='1'. wr_* son registros (Moore). sample_done es un pulso
-- de 1 ciclo y la BRAM ya tiene todo escrito cuando se activa.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sample_vect is
  generic(
    N      : integer := 17669;
    N_SZ   : integer := 2209;     -- bytes = ceil(N/8)
    ADDR_W : integer := 9         -- 2**ADDR_W >= ceil(N_SZ/8)
  );
  port(
    clk   : in std_logic;
    rst   : in std_logic;
    start : in std_logic;

    -- desde keccak_sponge (out_data / out_valid / out_ready)
    din       : in  std_logic_vector(63 downto 0);
    din_valid : in  std_logic;
    din_ready : out std_logic;

    -- BRAM externa de 64 bits
    wr_en   : out std_logic;
    wr_addr : out unsigned(ADDR_W - 1 downto 0);
    wr_data : out std_logic_vector(63 downto 0);

    sample_done : out std_logic
  );
end entity;

architecture rtl of sample_vect is

  constant WORDS64 : integer := (N_SZ + 7) / 8;   -- 277
  constant TAIL    : integer := N mod 8;          -- bits validos del ultimo byte (0 = completo)

  type state_type is (S_IDLE, S_RUN, S_FLUSH, S_DONE);
  signal fsm : state_type := S_IDLE;
  signal k   : integer range 0 to WORDS64 - 1 := 0;

  signal wr_en_r   : std_logic := '0';
  signal wr_addr_r : unsigned(ADDR_W - 1 downto 0) := (others => '0');
  signal wr_data_r : std_logic_vector(63 downto 0) := (others => '0');

  -- enmascara los bytes fuera de rango y los bits sobrantes del ultimo byte
  function mask64(w : std_logic_vector(63 downto 0); a : integer) return std_logic_vector is
    variable r  : std_logic_vector(63 downto 0) := w;
    variable bi : integer;
  begin
    for t in 0 to 7 loop
      bi := 8 * a + t;
      if bi >= N_SZ then
        r(8*t+7 downto 8*t) := (others => '0');
      elsif bi = N_SZ - 1 and TAIL /= 0 then
        for b in TAIL to 7 loop
          r(8*t+b) := '0';
        end loop;
      end if;
    end loop;
    return r;
  end function;

begin

  din_ready   <= '1' when fsm = S_RUN else '0';
  wr_en       <= wr_en_r;
  wr_addr     <= wr_addr_r;
  wr_data     <= wr_data_r;
  sample_done <= '1' when fsm = S_DONE else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        fsm     <= S_IDLE;
        k       <= 0;
        wr_en_r <= '0';
      else
        wr_en_r <= '0';
        case fsm is

          when S_IDLE =>
            if start = '1' then
              k   <= 0;
              fsm <= S_RUN;
            end if;

          when S_RUN =>                              -- din_ready = '1'
            if din_valid = '1' then
              wr_en_r   <= '1';
              wr_addr_r <= to_unsigned(k, ADDR_W);
              wr_data_r <= mask64(din, k);
              if k = WORDS64 - 1 then
                fsm <= S_FLUSH;
              else
                k <= k + 1;
              end if;
            end if;

          when S_FLUSH =>                            -- la ultima escritura ocurre en este ciclo
            fsm <= S_DONE;

          when S_DONE =>
            fsm <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;
