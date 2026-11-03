library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity bram_singleport is
  generic(
    DATA_WIDTH : integer := 32;
    ADDR_WIDTH : integer := 10
  );
  port(
    clk   : in  std_logic;
    we    : in  std_logic;
    addr  : in  unsigned(ADDR_WIDTH - 1 downto 0);
    din   : in  std_logic_vector(DATA_WIDTH - 1 downto 0);
    dout  : out std_logic_vector(DATA_WIDTH - 1 downto 0)
  );
end entity;

architecture rtl of bram_singleport is
  type ram_type is array (0 to 2**ADDR_WIDTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
  signal ram : ram_type := (others => (others => '0'));

  attribute ramstyle : string;
  attribute ramstyle of ram : signal is "M9K";

begin
  process(clk)
  begin
    if rising_edge(clk) then

      if we = '1' then
        ram(to_integer(unsigned(addr))) <= din;
      end if;
      
      dout <= ram(to_integer(unsigned(addr)));

    end if;
  end process;

end rtl;