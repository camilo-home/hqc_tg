library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity position_mem is
  generic(
    DATA_WIDTH : integer := 15;-- dato (posicion 0 a 17669-1)
    ADDR_WIDTH : integer := 7 -- direccion de escritura (0 a 128-1)
  );
  port(
    clk : in std_logic;
    we       : in std_logic;
    addr     : in unsigned(ADDR_WIDTH - 1 downto 0);
    din      : in unsigned(DATA_WIDTH - 1 downto 0); 
    dout     : out unsigned(DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of position_mem is

  type ram_type is array (0 to 2**ADDR_WIDTH - 1) of unsigned(DATA_WIDTH - 1 downto 0);
  signal mem : ram_type;

  attribute ramstyle : string;
  attribute ramstyle of mem : signal is "M9K";

begin

  process(clk)
  begin
    if rising_edge(clk) then
        -- escritura
        if we = '1' then
          mem(to_integer(unsigned(addr))) <= din;
        end if;
        -- lectura
        dout <= mem(to_integer(unsigned(addr)));
    end if;
  end process;

end rtl;
