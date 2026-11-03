library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity samplefxwtmod is
  port(
    clk           : in  std_logic;
    rst           : in  std_logic;

    start         : in  std_logic;

    shake_din     : in  std_logic_vector(31 downto 0);
    shake_valid   : in  std_logic;

    get_bytes     : out std_logic;  -- solicitar 32 bytes de shake256

    -- Interfaz con la pos_mem
    wr_en : out std_logic;
    wr_addr : out unsigned(6 downto 0);
    wr_data : out unsigned(14 downto 0);

    sample_done   : out std_logic
  );
end entity;

architecture rtl of samplefxwtmod is

  -- =========================
  -- CONSTANTES
  constant N : integer := 17669;
  constant RAM_BYTES : integer := 2209;

  -- =========================
  -- BRAM 
type ram_type is array (0 to RAM_BYTES-1) of std_logic_vector(7 downto 0);
signal ram : ram_type := (others => (others => '0'));

attribute ramstyle : string;
attribute ramstyle of ram : signal is "M9K";

  -- =========================
  -- FSM
  type state_type is (
    IDLE,
    LOAD_U32,
    --COMPUTE,
    COMP_1,
    COMP_2,
    COMP_3,
    READ_BRAM,
    WRITE_BRAM,
    COUNT_POS,
    DONE
  );

  signal fsm : state_type := IDLE;

  -- =========================
  -- DATAPATH
  signal WT       : integer := 75;
  signal i         : integer range 0 to WT := 0;
  signal dup       : integer := 0;

  signal u32       : unsigned(31 downto 0);
  signal m         : unsigned(14 downto 0);

  signal mult      : unsigned(46 downto 0);
  signal posn    : unsigned(14 downto 0);

  signal byte_addr : integer range 0 to RAM_BYTES-1;
  signal bit_addr  : integer range 0 to 7;

  signal we        : std_logic := '0';
  signal re        : std_logic := '0';
  signal din_ram   : std_logic_vector(7 downto 0);
  signal dout_ram  : std_logic_vector(7 downto 0);

begin

  process(clk)
  variable temp : unsigned(46 downto 0);
  begin
    if rising_edge(clk) then

      if rst = '1' then
        fsm   <= IDLE;
	i <= 0;
	sample_done <= '0';

      else
        case fsm is

          -- =========================
          when IDLE =>
            sample_done <= '0';

            if start = '1' then
              i <= 0;
              fsm <= LOAD_U32;
            end if;

          -- =========================
          when LOAD_U32 =>
            if shake_valid = '1' then
	      get_bytes <= '0';
              u32 <= unsigned(shake_din);
              fsm <= COMP_1;
	      
	    else
	      get_bytes <= '1';
            end if;

          -- =========================

	    -- COMBINACIONAL (alta latencia)
	    --when COMPUTE =>
	    --temp := u32 * to_unsigned(N - i, 15);
	    --posn <= temp(46 downto 32) + to_unsigned(i, 15);
	    --fsm <= READ_BRAM;
	    -- SECUENCIAL
            -- m = N - i
	    when COMP_1 =>
	      m <= to_unsigned(N - i, 15);
	      fsm <= COMP_2;
	    -- multiplicacion
	    when COMP_2 =>
	      mult <= u32 * m;
	      fsm <= COMP_3;
	    -- escalado (shift) + posicion
	    when COMP_3 =>
	      re <= '1';
	      posn    <= mult(46 downto 32) + to_unsigned(i, 15);
	      fsm <= READ_BRAM;

          -- =========================
          when READ_BRAM =>
	    re <= '0';
            fsm <= WRITE_BRAM;

          -- =========================
          when WRITE_BRAM =>

            if dout_ram(bit_addr) = '0' then
              -- escribir bit
	      din_ram <= dout_ram;
              din_ram(bit_addr) <= '1';
	      we <= '1';
	      fsm <= COUNT_POS;
            else
              -- duplicado ? ignorar y pedir nuevo u32
	      dup <= dup + 1;
              fsm <= LOAD_U32;
            end if;

          -- =========================
          when COUNT_POS =>
	    we <= '0';
            i <= i + 1;
            if i + 1 >= WT then
              fsm <= DONE;
            else
              fsm <= LOAD_U32;
            end if;

          -- =========================
          when DONE =>
	    dup <= 0;
            sample_done <= '1';
            fsm <= IDLE;

        end case;
      end if;
    end if;
  end process;

process(clk)
begin
  if rising_edge(clk) then
    if we = '1' then
      ram(byte_addr) <= din_ram; -- esritura
    elsif re = '1' then
      dout_ram <= ram(byte_addr);  -- lectura
    end if;
  end if;
end process;

byte_addr <= to_integer(posn(14 downto 3));
bit_addr <= to_integer(posn(2 downto 0));

wr_addr <= to_unsigned(i, 7);
wr_data <= posn(14 downto 0);
wr_en <= we;

end rtl;