-- ============================================================================
-- ram64_tdp : RAM de doble puerto verdadero, 64 bits, lectura registrada (latencia 1).
--   Es la memoria del ACUMULADOR de poly_mul2 (una instancia por canal, en el top).
--   * Puerto 1 y puerto 2 independientes: cada uno con we / addr / din / dout.
--   * Lectura-antes-de-escritura por puerto ("old data").
--   * Profundidad exacta DEPTH (no potencia de 2): ahorra bloques M9K.
--   * Sin puerto de limpieza: poly_mul2 inicializa el acumulador durante su primera
--     pasada (ver cabecera de poly_mul2), asi que no hace falta ponerlo a cero nunca.
--   * "no_rw_check": poly_mul2 nunca lee y escribe la misma direccion por puertos
--     distintos en el mismo ciclo; evita logica de bypass innecesaria.
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram64_tdp is
  generic(
    DATA_WIDTH : integer := 64;
    DEPTH      : integer := 554;   -- 2 * palabras de un vector (HQC-128)
    ADDR_W     : integer := 10
  );
  port(
    clk    : in  std_logic;
    -- puerto 1
    we_1   : in  std_logic;
    addr_1 : in  unsigned(ADDR_W - 1 downto 0);
    din_1  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    dout_1 : out std_logic_vector(DATA_WIDTH - 1 downto 0);
    -- puerto 2
    we_2   : in  std_logic;
    addr_2 : in  unsigned(ADDR_W - 1 downto 0);
    din_2  : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    dout_2 : out std_logic_vector(DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of ram64_tdp is
  type ram_type is array (0 to DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ram : ram_type := (others => (others => '0'));

  attribute ramstyle : string;
  attribute ramstyle of ram : signal is "M9K, no_rw_check";
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if we_1 = '1' then
        ram(to_integer(addr_1)) <= din_1;
      end if;
      dout_1 <= ram(to_integer(addr_1));

      if we_2 = '1' then
        ram(to_integer(addr_2)) <= din_2;
      end if;
      dout_2 <= ram(to_integer(addr_2));
    end if;
  end process;

end rtl;
