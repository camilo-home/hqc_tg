library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity position_mem is
  port(
    clk : in std_logic;
    rst : in std_logic;

    -- escritura (sampler)
    we       : in std_logic;
    addr  : in unsigned(6 downto 0); -- direccion de escritura (0 a 66-1)
    din  : in unsigned(14 downto 0); -- dato (posicion 0 a 17669-1)

    -- lectura (multiplier)
    re_addr  : in unsigned(6 downto 0);
    dout  : out unsigned(14 downto 0)
  );
end entity;

architecture rtl of position_mem is

  type pos_array is array (0 to 74) of unsigned(14 downto 0);
  signal mem : pos_array;

  attribute ramstyle : string;
  attribute ramstyle of mem : signal is "M9K";

  signal rd_addr_reg : unsigned(6 downto 0);

begin

  process(clk)
  begin
    if rising_edge(clk) then

      if rst = '1' then
        -- opcional: limpiar
        mem <= (others => (others => '0'));
        rd_addr_reg <= (others => '0');

      else

        -- escritura
        if we = '1' then
          mem(to_integer(addr)) <= din;
        end if;

        -- registro de dirección de lectura
        rd_addr_reg <= re_addr;

      end if;
    end if;
  end process;

  -- lectura síncrona (1 ciclo)
  dout <= mem(to_integer(rd_addr_reg));

end rtl;
