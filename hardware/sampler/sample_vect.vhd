library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sample_vect is
  generic(
    N      : integer := 17669;
    N_SZ   : integer := 2209  -- bytes
  );
  port(
    clk   : in std_logic;
    rst   : in std_logic;
    start : in std_logic;

    -- SHAKE input (32 bits)
    din       : in  std_logic_vector(31 downto 0);
    din_valid : in  std_logic;
    get_bytes : out std_logic;

    -- interfaz BRAM externa
    wr_en   : out std_logic;
    wr_addr : out unsigned(9 downto 0);
    wr_data : out std_logic_vector(31 downto 0);

    sample_done : out std_logic
  );
end entity;

architecture rtl of sample_vect is

  constant WORDS : integer := (N_SZ + 3) / 4;

  type state_type is (IDLE, LOAD, DONE);
  signal fsm : state_type := IDLE;

  signal addr : unsigned(9 downto 0) := (others => '0');

begin

process(clk)
begin
  if rising_edge(clk) then
    if rst = '1' then
      fsm <= IDLE;
      addr <= (others => '0');
      sample_done <= '0';
      get_bytes <= '0';
      wr_en <= '0';

    else
      -- defaults
      wr_en <= '0';

      case fsm is

        -- =========================
        when IDLE =>
          sample_done <= '0';

          if start = '1' then
            addr <= (others => '0');
            fsm <= LOAD;
          end if;

        -- =========================
        when LOAD =>
          if din_valid = '1' then

            get_bytes <= '0';

            -- escritura a BRAM externa
            wr_en   <= '1';
            wr_addr <= addr;
            wr_data <= din;

            addr <= addr + 1;

            if to_integer(addr) + 1 >= WORDS then
              fsm <= DONE;
            end if;

          else
            get_bytes <= '1';
          end if;

        -- =========================
        when DONE =>
          sample_done <= '1';
          fsm <= IDLE;

      end case;
    end if;
  end if;
end process;

end rtl;