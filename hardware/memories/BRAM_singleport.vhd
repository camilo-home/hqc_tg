library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity BRAM_singleport is
  port(
    clk   : in  std_logic;

    -- write
    we    : in  std_logic;
    addr  : in  unsigned(9 downto 0); -- ajusta profundidad
    din   : in  std_logic_vector(31 downto 0);

    -- read
    dout  : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of BRAM_singleport is

  type ram_type is array (0 to 1023) of std_logic_vector(31 downto 0);
  signal ram : ram_type;

  attribute ramstyle : string;
  attribute ramstyle of ram : signal is "M9K";

  signal addr_reg : unsigned(9 downto 0);

begin

  process(clk)
  begin
    if rising_edge(clk) then

      -- escritura
      if we = '1' then
        ram(to_integer(addr)) <= din;
      end if;

      -- registro de dirección (lectura síncrona)
      addr_reg <= addr;

      -- salida
      dout <= ram(to_integer(addr_reg));

    end if;
  end process;

end rtl;