library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity BRAM_dualport is
  port(
    clk    : in std_logic;
    -- PORT A
    we_a   : in  std_logic;
    addr_a : in  unsigned(10 downto 0);
    din_a  : in  std_logic_vector(31 downto 0);
    dout_a : out std_logic_vector(31 downto 0);
    -- PORT B
    we_b   : in  std_logic;
    addr_b : in  unsigned(10 downto 0);
    din_b  : in  std_logic_vector(31 downto 0);
    dout_b : out std_logic_vector(31 downto 0)
  );
end entity;

architecture rtl of BRAM_dualport is
  type ram_type is array (0 to 2047) of std_logic_vector(31 downto 0);
  signal ram : ram_type := (others => (others => '0'));
  attribute ramstyle : string;
  attribute ramstyle of ram : signal is "M9K";
begin
  process(clk)
  begin
    if rising_edge(clk) then
      -- Escrituras síncronas
      if we_a = '1' then ram(to_integer(addr_a)) <= din_a; end if;
      if we_b = '1' then ram(to_integer(addr_b)) <= din_b; end if;

      -- Lecturas síncronas directas (Latencia = 1 ciclo de reloj)
      dout_a <= ram(to_integer(addr_a));
      dout_b <= ram(to_integer(addr_b));
    end if;
  end process;
end architecture;
