-- ============================================================================
-- ram64_sdp : RAM de doble puerto simple, 64 bits: un puerto de ESCRITURA y uno de LECTURA
--             independientes (lectura registrada, latencia 1).
--   Uso en el top:
--     * vectores densos (h, s, u ...): escribe sample_vect (o quien cargue el vector) por el
--       puerto de escritura y lee poly_mul2 por el de lectura, SIN multiplexar direcciones.
--     * memorias de resultado: escribe poly_mul2 (res_*) y leen los consumidores (hash,
--       sparse_xor...). Si dos modulos escriben o leen la misma memoria, el mux va en el top.
--   * Si se lee y se escribe la misma direccion en el mismo ciclo el dato leido no esta
--     definido ("no_rw_check"); en la arquitectura HQC nunca ocurre (fases distintas).
--   * Profundidad exacta DEPTH (277 palabras de 64 bits = un vector de HQC-128).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ram64_sdp is
  generic(
    DATA_WIDTH : integer := 64;
    DEPTH      : integer := 277;
    ADDR_W     : integer := 9
  );
  port(
    clk   : in  std_logic;
    -- escritura
    we    : in  std_logic;
    waddr : in  unsigned(ADDR_W - 1 downto 0);
    wdata : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    -- lectura
    raddr : in  unsigned(ADDR_W - 1 downto 0);
    rdata : out std_logic_vector(DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of ram64_sdp is
  type ram_type is array (0 to DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ram : ram_type := (others => (others => '0'));

  attribute ramstyle : string;
  attribute ramstyle of ram : signal is "M9K, no_rw_check";
begin

  process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        ram(to_integer(waddr)) <= wdata;
      end if;
      rdata <= ram(to_integer(raddr));
    end if;
  end process;

end rtl;
