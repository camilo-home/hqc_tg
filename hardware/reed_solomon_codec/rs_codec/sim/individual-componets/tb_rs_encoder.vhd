library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library WORK;
use WORK.RS_COMPONENTS.rs_encoder;
use WORK.RS_FUNCTIONS.get_word_length_from_rs_gf;
use WORK.TB_RS_ENCODER_DECODER_PARAMS.all;


entity tb_rs_encoder is
end tb_rs_encoder;


architecture behavioral of tb_rs_encoder is

    --------------------------------------------------------------------
    -- Parameters
    --------------------------------------------------------------------

    constant WORD_LENGTH : natural :=
        get_word_length_from_rs_gf(TB_N, TB_RS_GF);

    constant CLK_PERIOD : time := 10 ns;


    --------------------------------------------------------------------
    -- Signals
    --------------------------------------------------------------------

    signal clk : std_logic;
    signal rst : std_logic;

    signal i_start_codeword : std_logic;
    signal i_end_codeword   : std_logic;
    signal i_valid          : std_logic;
    signal i_consume        : std_logic;

    signal i_symbol : std_logic_vector(WORD_LENGTH-1 downto 0);

    signal o_start_codeword : std_logic;
    signal o_end_codeword   : std_logic;
    signal o_error          : std_logic;
    signal o_in_ready       : std_logic;
    signal o_valid          : std_logic;

    signal o_symbol : std_logic_vector(WORD_LENGTH-1 downto 0);


begin

    --------------------------------------------------------------------
    -- Unit Under Test
    --------------------------------------------------------------------

    UUT : rs_encoder
        generic map (
            N        => TB_N,
            K        => TB_K,
            RS_GF    => TB_RS_GF,
            TEST_MODE => false
        )
        port map (
            clk                => clk,
            rst                => rst,

            i_end_codeword     => i_end_codeword,
            i_start_codeword   => i_start_codeword,
            i_valid            => i_valid,
            i_consume          => i_consume,
            i_symbol           => i_symbol,

            o_end_codeword     => o_end_codeword,
            o_error            => o_error,
            o_in_ready         => o_in_ready,
            o_start_codeword   => o_start_codeword,
            o_valid            => o_valid,
            o_symbol           => o_symbol
        );


    --------------------------------------------------------------------
    -- Clock
    --------------------------------------------------------------------

    CLK_PROCESS : process
    begin
        clk <= '1';
        wait for CLK_PERIOD/2;

        clk <= '0';
        wait for CLK_PERIOD/2;
    end process;


    --------------------------------------------------------------------
    -- Stimulus
    --------------------------------------------------------------------

    STIM_PROCESS : process

        procedure send_symbol(
            symbol_value  : natural;
            start_codeword : std_logic;
            end_codeword   : std_logic
        ) is
        begin

            wait until falling_edge(clk);

            i_symbol         <= std_logic_vector(
                                    to_unsigned(symbol_value, WORD_LENGTH)
                                );

            i_start_codeword <= start_codeword;
            i_end_codeword   <= end_codeword;
            i_valid          <= '1';

            wait until rising_edge(clk);

            i_start_codeword <= '0';
            i_end_codeword   <= '0';
            i_valid          <= '0';

        end procedure;


        procedure idle_cycles(
            cycles : natural
        ) is
        begin

            for I in 1 to cycles loop

                wait until falling_edge(clk);

                i_start_codeword <= '0';
                i_end_codeword   <= '0';
                i_valid          <= '0';

                wait until rising_edge(clk);

            end loop;

        end procedure;


    begin

        ----------------------------------------------------------------
        -- Initial values
        ----------------------------------------------------------------

        rst <= '1';

        i_start_codeword <= '0';
        i_end_codeword   <= '0';
        i_valid          <= '0';
        i_consume        <= '1';

        i_symbol <= (others => '0');


        ----------------------------------------------------------------
        -- Reset
        ----------------------------------------------------------------

        wait for CLK_PERIOD * 5;

        wait until falling_edge(clk);

        rst <= '0';


        ----------------------------------------------------------------
        -- Send TB_NUM_CODEWORDS codewords
        ----------------------------------------------------------------

        for CW in 0 to TB_NUM_CODEWORDS-1 loop

            ------------------------------------------------------------
            -- Send K information symbols
            ------------------------------------------------------------

            for I in 96 to 96+TB_K-1 loop

                if I = 96 then

                    -- First symbol of the codeword
                    send_symbol(
                        I + 1,
                        '1',
                        '0'
                    );

                elsif I = 96+TB_K-1 then

                    -- Last information symbol
                    send_symbol(
                        I + 1,
                        '0',
                        '1'
                    );

                else

                    -- Intermediate information symbols
                    send_symbol(
                        I + 1,
                        '0',
                        '0'
                    );

                end if;

            end loop;


            ------------------------------------------------------------
            -- Wait before next codeword
            ------------------------------------------------------------

            idle_cycles(6);

        end loop;


        ----------------------------------------------------------------
        -- End simulation
        ----------------------------------------------------------------

        wait;

    end process;

end behavioral;