library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
library WORK;
use WORK.RS_COMPONENTS.rs_encoder;
use WORK.RS_FUNCTIONS.get_word_length_from_rs_gf;
use WORK.RS_TYPES.all;
use WORK.TB_RS_ENCODER_DECODER_PARAMS.all;

entity tb_rs_encoder is
end tb_rs_encoder;

architecture behavioral of tb_rs_encoder is
    constant CLK_PERIOD : time := 10 ns;

    -- Parámetros cargados desde tb_rs_encoder_decoder_params.vhd
    constant N : natural := TB_N;
    constant K : natural := TB_K;
    constant RS_GF : RSGFSize := TB_RS_GF;
    constant NUM_CODEWORDS : natural := 1;

    constant WORD_LENGTH : natural := get_word_length_from_rs_gf(N, RS_GF);
    constant EXPECTED_SYMBOLS : natural := N * NUM_CODEWORDS;
    constant EXPECTED_DATA_SYMBOLS : natural := K * NUM_CODEWORDS;
    constant SIM_TIMEOUT : time := CLK_PERIOD * (EXPECTED_SYMBOLS * 20 + 200);

    type symbol_array is array (natural range <>) of std_logic_vector(WORD_LENGTH-1 downto 0);
    type byte_vector is array (natural range <>) of natural;

    -- =========================================================================
    -- EDITA AQUÍ LOS K SÍMBOLOS DE ENTRADA DEL ENCODER (en hexadecimal 16#XX#)
    -- =========================================================================
    constant REVERSE_BYTES : boolean := false; -- Cambia a true para invertir el orden
    constant INPUT_MESSAGE : byte_vector(0 to K-1) := (
        16#05#, 16#f5#, 16#57#, 16#47#,
        16#e7#, 16#9d#, 16#9c#, 16#06#,
        16#34#, 16#c9#, 16#74#, 16#cf#,
        16#52#, 16#d3#, 16#b2#, 16#74#
    );
    -- 05f55747 e79d9c06 34c974cf 52d3b274
    -- =========================================================================

    signal clk : std_logic;
    signal rst : std_logic;

    signal enc_i_start_codeword : std_logic;
    signal enc_i_end_codeword : std_logic;
    signal enc_i_valid : std_logic;
    signal enc_i_consume : std_logic := '1';
    signal enc_i_symbol : std_logic_vector(WORD_LENGTH-1 downto 0);
    signal enc_o_start_codeword : std_logic;
    signal enc_o_end_codeword : std_logic;
    signal enc_o_error : std_logic;
    signal enc_o_in_ready : std_logic;
    signal enc_o_valid : std_logic;
    signal enc_o_symbol : std_logic_vector(WORD_LENGTH-1 downto 0);

    signal done : boolean := false;
begin
    ENCODER_UUT: rs_encoder
                 generic map(N => N,
                             K => K,
                             RS_GF => RS_GF,
                             TEST_MODE => false)
                 port map(clk => clk,
                          rst => rst,
                          i_end_codeword => enc_i_end_codeword,
                          i_start_codeword => enc_i_start_codeword,
                          i_valid => enc_i_valid,
                          i_consume => enc_i_consume,
                          i_symbol => enc_i_symbol,
                          o_start_codeword => enc_o_start_codeword,
                          o_end_codeword => enc_o_end_codeword,
                          o_error => enc_o_error,
                          o_in_ready => enc_o_in_ready,
                          o_valid => enc_o_valid,
                          o_symbol => enc_o_symbol);

    CLK_PROCESS : process
    begin
        while not done loop
            clk <= '1';
            wait for CLK_PERIOD/2;
            clk <= '0';
            wait for CLK_PERIOD/2;
        end loop;
        wait;
    end process;

    STIM_PROCESS : process
        procedure send_symbol(symbol_value : natural;
                              start_codeword : std_logic;
                              end_codeword : std_logic) is
        begin
            wait until falling_edge(clk);

            enc_i_symbol <= std_logic_vector(to_unsigned(symbol_value, WORD_LENGTH));
            enc_i_start_codeword <= start_codeword;
            enc_i_end_codeword <= end_codeword;
            enc_i_valid <= '1';

            loop
                wait until rising_edge(clk);
                exit when enc_o_in_ready = '1' and enc_i_consume = '1';
            end loop;
            -- No bajamos enc_i_valid aquí para encadenar el siguiente símbolo en el próximo falling_edge
        end procedure;

        procedure idle_cycles(cycles : natural) is
        begin
            for I in 1 to cycles loop
                wait until falling_edge(clk);
                enc_i_start_codeword <= '0';
                enc_i_end_codeword <= '0';
                enc_i_valid <= '0';
                wait until rising_edge(clk);
            end loop;
        end procedure;

        procedure send_codeword(reverse_order : boolean := false) is
            variable symbol_index : natural;
            variable start_codeword : std_logic;
            variable end_codeword : std_logic;
        begin
            for I in 0 to K-1 loop
                if reverse_order then
                    symbol_index := K - 1 - I;
                else
                    symbol_index := I;
                end if;

                start_codeword := '0';
                end_codeword := '0';
                if I = 0 then
                    start_codeword := '1';
                end if;
                if I = K-1 then
                    end_codeword := '1';
                end if;

                send_symbol(INPUT_MESSAGE(symbol_index) mod (2**WORD_LENGTH),
                            start_codeword => start_codeword,
                            end_codeword => end_codeword);
            end loop;

            -- Bajamos enc_i_valid en el flanco de bajada inmediatamente posterior al último símbolo
            wait until falling_edge(clk);
            enc_i_start_codeword <= '0';
            enc_i_end_codeword <= '0';
            enc_i_valid <= '0';
            -- enc_i_consume <= '0';
        end procedure;
    begin
        rst <= '1';
        enc_i_start_codeword <= '0';
        enc_i_end_codeword <= '0';
        enc_i_valid <= '0';
        enc_i_symbol <= (others => '0');

        wait for CLK_PERIOD*5;
        wait until falling_edge(clk);
        rst <= '0';

        for I in 0 to NUM_CODEWORDS-1 loop
            send_codeword(reverse_order => REVERSE_BYTES);
            idle_cycles(6);
        end loop;

        wait;
    end process;

    CHECK_PROCESS : process(clk, rst)
        variable data_scoreboard : symbol_array(0 to EXPECTED_DATA_SYMBOLS-1);
        variable wr_index : natural range 0 to EXPECTED_SYMBOLS := 0;
        variable data_wr_index : natural range 0 to EXPECTED_DATA_SYMBOLS := 0;
        variable data_rd_index : natural range 0 to EXPECTED_DATA_SYMBOLS := 0;
        variable enc_codeword_symbol_index : natural range 0 to N-1 := 0;
    begin
        if rst = '1' then
            wr_index := 0;
            data_wr_index := 0;
            data_rd_index := 0;
            enc_codeword_symbol_index := 0;
        elsif rising_edge(clk) then
            assert enc_o_error = '0'
                report "Encoder reported an error"
                severity error;

            if enc_i_valid = '1' and enc_o_in_ready = '1' and enc_i_consume = '1' then
                assert data_wr_index < EXPECTED_DATA_SYMBOLS
                    report "Encoder accepted more input data symbols than expected"
                    severity failure;
                data_scoreboard(data_wr_index) := enc_i_symbol;
                data_wr_index := data_wr_index + 1;
            end if;

            if enc_o_valid = '1' and enc_i_consume = '1' then
                assert wr_index < EXPECTED_SYMBOLS
                    report "Encoded more symbols than expected"
                    severity failure;
                wr_index := wr_index + 1;

                if enc_codeword_symbol_index < K then
                    assert data_rd_index < data_wr_index
                        report "Encoder produced a data symbol before the matching input symbol was stored"
                        severity failure;

                    assert enc_o_symbol = data_scoreboard(data_rd_index)
                        report "Encoder output data symbol differs from encoder input at data index " &
                               integer'image(data_rd_index) &
                               ". Input=" & integer'image(to_integer(unsigned(data_scoreboard(data_rd_index)))) &
                               ", encoded=" & integer'image(to_integer(unsigned(enc_o_symbol)))
                        severity error;

                    data_rd_index := data_rd_index + 1;
                end if;

                if enc_o_end_codeword = '1' or enc_codeword_symbol_index = N-1 then
                    enc_codeword_symbol_index := 0;
                else
                    enc_codeword_symbol_index := enc_codeword_symbol_index + 1;
                end if;

                if wr_index = EXPECTED_SYMBOLS then
                    assert data_rd_index = EXPECTED_DATA_SYMBOLS
                        report "Not all encoder input data symbols were compared against encoder outputs"
                        severity failure;

                    report "Encoder test passed for " &
                           integer'image(EXPECTED_SYMBOLS) & " symbols"
                           severity note;
                    done <= true;
                end if;
            end if;
        end if;
    end process;

    TIMEOUT_PROCESS : process
    begin
        wait for SIM_TIMEOUT;
        assert done
            report "Simulation timeout before encoder produced all expected symbols"
            severity failure;
        wait;
    end process;
end behavioral;