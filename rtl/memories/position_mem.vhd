library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Memoria de posiciones: RAM dual-port simple (1 escritura + 1 lectura).
--   * Puerto de escritura: lo maneja el sampler (wr_en / wr_addr / wr_data).
--   * Puerto de lectura  : lo usa el sampler (fase 2 / limpieza del bitmap) y despues
--                          el consumidor (vect_mul). Latencia de lectura = 1 ciclo.
-- Lectura y escritura en la misma direccion y ciclo devuelve dato viejo (no se usa asi).
entity position_mem is
  generic(
    DATA_WIDTH : integer := 15; -- posicion 0 .. 17669-1
    ADDR_WIDTH : integer := 7   -- 0 .. 127 (WT <= 75)
  );
  port(
    clk     : in  std_logic;
    -- escritura
    we      : in  std_logic;
    wr_addr : in  unsigned(ADDR_WIDTH - 1 downto 0);
    din     : in  unsigned(DATA_WIDTH - 1 downto 0);
    -- lectura
    rd_addr : in  unsigned(ADDR_WIDTH - 1 downto 0);
    dout    : out unsigned(DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of position_mem is

  type ram_type is array (0 to 2**ADDR_WIDTH - 1) of unsigned(DATA_WIDTH - 1 downto 0);
  signal mem : ram_type := (others => (others => '0'));

  attribute ramstyle : string;
  attribute ramstyle of mem : signal is "M9K, no_rw_check";

begin

  process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        mem(to_integer(wr_addr)) <= din;
      end if;
      dout <= mem(to_integer(rd_addr));
    end if;
  end process;

end rtl;
