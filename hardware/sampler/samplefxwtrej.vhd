library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity samplefxwtrej is
  port(
    clk         : in  std_logic;
    rst         : in  std_logic;

    start       : in  std_logic;

    -- Entrada desde SHAKE (32 bits)
    shake_din     : in  std_logic_vector(31 downto 0);
    shake_valid   : in  std_logic;

    -- Comunicacion con squeeze
    get_bytes : out std_logic; -- solicitar 32 bytes de shake256

    -- Interfaz con la pos_mem
    wr_en : out std_logic;
    wr_addr : out unsigned(6 downto 0);
    wr_data : out unsigned(14 downto 0);

    sample_done        : out std_logic
  );
end entity;

architecture rtl of samplefxwtrej is

  -- Parametros HQC
  constant N      : integer := 17669;
  constant WT     : integer := 66;

  -- n_32 = 2^32 // 17669
  constant N_32   : integer := 243079;
  -- n_rej = (2^24 // 17669) * 17669 = 949 * 17669 = 16767881
  constant N_REJ  : integer := 16767881;

  -- Bitmap
  constant RAM_BYTES : integer := 2209;

type ram_type is array (0 to RAM_BYTES-1) of std_logic_vector(7 downto 0);
signal ram : ram_type :=(others => (others => '0'));
attribute ramstyle : string;
attribute ramstyle of ram : signal is "M9K";

  -- FSM
  type state_type is (IDLE, LOAD_BUF, LOAD_U24, CHECK, REDUCE, READ_BRAM, WRITE_BRAM, COUNT_POS, DONE);
  signal fsm : state_type := IDLE;

  -- Contadores / datos
  signal i          : integer range 0 to WT := 0;
  signal u24        : unsigned(23 downto 0);
  signal mult       : unsigned(41 downto 0);
  signal posn        : unsigned(24 downto 0);
  signal dup       : integer := 0;

  -- Direcciones y registros de la ram
  signal byte_addr  : integer range 0 to RAM_BYTES-1;
  signal bit_addr   : integer range 0 to 7;
  signal we        : std_logic := '0';
  signal re : std_logic := '0';
  signal din_ram   : std_logic_vector(7 downto 0);
  signal dout_ram  : std_logic_vector(7 downto 0);

  -- =========================
  -- Gearbox (32 ? 24)
  signal buf        : unsigned(63 downto 0) := (others => '0'); -- buffer de 64 bits
  signal bit_cnt    : integer range 0 to 64 := 0;

begin
  
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        fsm      <= IDLE;
        i        <= 0;
        sample_done     <= '0';
        buf      <= (others => '0');
        bit_cnt  <= 0;

      else

        case fsm is

          -- =========================
          when IDLE =>
	    sample_done <= '0';

            if start = '1' then
              i       <= 0;
              buf     <= (others => '0');
              bit_cnt <= 0;
              fsm     <= LOAD_BUF;
            end if;

          -- =========================
          -- Llenar buffer con palabras de 32 bits, pide datos si el buffer esta bajo
          when LOAD_BUF =>
	    we <= '0';
          if bit_cnt < 24 then
	    if shake_valid = '1' then
	      get_bytes <= '0';
              buf((bit_cnt + 31) downto (bit_cnt)) <= unsigned(shake_din);
              bit_cnt <= bit_cnt + 32;
	      fsm <= LOAD_U24;
	    else
	      get_bytes <= '1';
	    end if;
	  else
	      fsm <= LOAD_U24;
          end if;

          -- =========================
          -- Extraer 24 bits
          when LOAD_U24 =>
            u24 <= buf(23 downto 0);
            buf     <= buf srl 24;
            bit_cnt <= bit_cnt - 24;
            fsm     <= CHECK;

          -- =========================
          -- Rechazo
          when CHECK =>
            if u24 < to_unsigned(N_REJ, 24) then
	      mult <= u24 * to_unsigned(N_32, 18);
              fsm <= REDUCE;
            else
              fsm <= LOAD_BUF;
            end if;

          -- =========================

          when REDUCE =>
            posn <= u24 - (mult(41 downto 32) * to_unsigned(N, 15));
	    re <= '1';
            fsm <= READ_BRAM;


when READ_BRAM =>
	re <= '0';
	fsm <= WRITE_BRAM;

when WRITE_BRAM =>
  if dout_ram(bit_addr) = '0' then
    din_ram <= dout_ram;
    din_ram(bit_addr) <= '1';
    we <= '1';
    fsm <= COUNT_POS;
  else
    dup <= dup + 1;
    fsm <= LOAD_BUF;
  end if;

when COUNT_POS =>
    we <= '0';
    i <= i + 1;
  if i + 1 >= WT then
    fsm <= DONE;
  else
    fsm <= LOAD_BUF;
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
bit_addr  <= to_integer(posn(2 downto 0));

wr_addr <= to_unsigned(i, 7);
wr_data <= posn(14 downto 0);
wr_en <= we;
end rtl;