library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity poly_mul is
generic(
    WT       : integer := 3; --66
    WORD_COUNT : integer := 4 --553
);
port(
    clk   : in std_logic;
    rst   : in std_logic;
    start : in std_logic;

    -- Position memory
    pos_addr : out unsigned(6 downto 0);
    pos_data : in  unsigned(14 downto 0);

    -- Dense memory
    dense_addr : out unsigned(9 downto 0);
    dense_data : in  std_logic_vector(31 downto 0);

    -- Accumulator BRAM
    acc_addr_a : out unsigned(10 downto 0);
    acc_addr_b : out unsigned(10 downto 0);

    acc_din_a  : out std_logic_vector(31 downto 0);
    acc_din_b  : out std_logic_vector(31 downto 0);

    acc_dout_a : in  std_logic_vector(31 downto 0);
    acc_dout_b : in  std_logic_vector(31 downto 0);

    acc_we_a   : out std_logic;
    acc_we_b   : out std_logic;

    done : out std_logic
);
end entity;

architecture rtl of poly_mul is

    type state_t is (
        IDLE,
        LOAD_POS,
        WAIT_POS,
        SET_ADDR,
        WAIT_READ,
        WRITE_BACK,
        NEXT_WORD,
        NEXT_POS,
        FINISHED
    );

    signal state : state_t := IDLE;

    signal pos_cnt  : integer range 0 to WT;
    signal word_cnt : integer range 0 to WORD_COUNT;

    signal current_pos : unsigned(14 downto 0);

    signal word_offset : integer range 0 to 552;
    signal bit_offset  : integer range 0 to 31;

    signal dense_word_r : std_logic_vector(31 downto 0);

    signal lower_part : std_logic_vector(31 downto 0);
    signal upper_part : std_logic_vector(31 downto 0);

    signal acc_addr_low  : integer range 0 to 2047;
    signal acc_addr_high : integer range 0 to 2047;

begin

    process(clk)

        variable lower_v : unsigned(31 downto 0);
        variable upper_v : unsigned(31 downto 0);

    begin
        if rising_edge(clk) then

            if rst = '1' then

                state <= IDLE;

                pos_cnt  <= 0;
                word_cnt <= 0;

                done <= '0';

                acc_we_a <= '0';
                acc_we_b <= '0';

            else

                acc_we_a <= '0';
                acc_we_b <= '0';

                case state is

                ----------------------------------------------------------------
                when IDLE =>
                ----------------------------------------------------------------

                    done <= '0';

                    if start = '1' then

                        pos_cnt  <= 0;
                        word_cnt <= 0;
                        state <= LOAD_POS;

                    end if;

                when LOAD_POS =>
                    pos_addr <= to_unsigned(pos_cnt, 7); -- programar lectura de la posicion desde sparse
                    state <= WAIT_POS;

                when WAIT_POS =>
                    current_pos <= pos_data; -- almacena posicion

                    word_offset <=
                        to_integer(pos_data(14 downto 5)); -- extrae offset de word
                    bit_offset <=
                        to_integer(pos_data(4 downto 0)); -- extrae offset de bit

                    word_cnt <= 0;
                    state <= SET_ADDR;

                ----------------------------------------------------------------
                when SET_ADDR =>
                ----------------------------------------------------------------

                    dense_addr <=
                        to_unsigned(word_cnt, 10);

                    acc_addr_low  <= word_cnt + word_offset;
                    acc_addr_high <= word_cnt + word_offset + 1;

                    acc_addr_a <=
                        to_unsigned(word_cnt + word_offset, 11);

                    acc_addr_b <=
                        to_unsigned(word_cnt + word_offset + 1, 11);

                    state <= WAIT_READ;

                ----------------------------------------------------------------
                when WAIT_READ =>
                ----------------------------------------------------------------

                    dense_word_r <= dense_data;

                    state <= WRITE_BACK;

                ----------------------------------------------------------------
                when WRITE_BACK =>
                ----------------------------------------------------------------

                    if bit_offset = 0 then

                        lower_v := unsigned(dense_word_r);
                        upper_v := (others => '0');

                    else

                        lower_v :=
                            shift_left(
                                unsigned(dense_word_r),
                                bit_offset
                            );

                        upper_v :=
                            shift_right(
                                unsigned(dense_word_r),
                                32 - bit_offset
                            );

                    end if;

                    lower_part <= std_logic_vector(lower_v);
                    upper_part <= std_logic_vector(upper_v);

                    acc_din_a <=
                        acc_dout_a xor std_logic_vector(lower_v);

                    acc_din_b <=
                        acc_dout_b xor std_logic_vector(upper_v);

                    acc_we_a <= '1';
                    acc_we_b <= '1';

                    state <= NEXT_WORD;

                ----------------------------------------------------------------
                when NEXT_WORD =>
                ----------------------------------------------------------------

                    if word_cnt = WORD_CNT-1 then

                        state <= NEXT_POS;

                    else

                        word_cnt <= word_cnt + 1;

                        state <= SET_ADDR;

                    end if;

                ----------------------------------------------------------------
                when NEXT_POS =>
                ----------------------------------------------------------------

                    if pos_cnt = WT-1 then

                        state <= FINISHED;

                    else

                        pos_cnt <= pos_cnt + 1;

                        state <= LOAD_POS;

                    end if;

                ----------------------------------------------------------------
                when FINISHED =>
                ----------------------------------------------------------------

                    done <= '1';

                    if start = '0' then
                        state <= IDLE;
                    end if;

                end case;

            end if;

        end if;
    end process;

end architecture;