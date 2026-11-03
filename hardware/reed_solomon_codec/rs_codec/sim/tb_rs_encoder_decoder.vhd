library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
library WORK;
use WORK.RS_COMPONENTS.rs_decoder;
use WORK.RS_COMPONENTS.rs_encoder;
use WORK.RS_FUNCTIONS.get_word_length_from_rs_gf;
use WORK.RS_TYPES.all;
use WORK.TB_RS_ENCODER_DECODER_PARAMS.all;

entity tb_rs_encoder_decoder is
end tb_rs_encoder_decoder;

architecture behavioral of tb_rs_encoder_decoder is
    constant CLK_PERIOD : time := 10 ns;

    -- Test configuration is generated in tb_rs_encoder_decoder_params.vhd.
    constant N : natural := TB_N;
    constant K : natural := TB_K;
    constant RS_GF : RSGFSize := TB_RS_GF;
    constant FCR : natural := TB_FCR;
    constant PRIMITIVE_POLYNOMIAL : natural := TB_PRIMITIVE_POLYNOMIAL;
    constant NUM_CODEWORDS : natural := TB_NUM_CODEWORDS;

    constant WORD_LENGTH : natural := get_word_length_from_rs_gf(N, RS_GF);
    constant EXPECTED_SYMBOLS : natural := N * NUM_CODEWORDS;
    constant EXPECTED_DATA_SYMBOLS : natural := K * NUM_CODEWORDS;
    constant SIM_TIMEOUT : time := CLK_PERIOD * (EXPECTED_SYMBOLS * 20 + 200);

    type symbol_array is array (natural range <>) of std_logic_vector(WORD_LENGTH-1 downto 0);

    signal clk : std_logic;
    signal rst : std_logic;

    signal enc_i_start_codeword : std_logic;
    signal enc_i_end_codeword : std_logic;
    signal enc_i_valid : std_logic;
    signal enc_i_consume : std_logic;
    signal enc_i_symbol : std_logic_vector(WORD_LENGTH-1 downto 0);
    signal enc_o_start_codeword : std_logic;
    signal enc_o_end_codeword : std_logic;
    signal enc_o_error : std_logic;
    signal enc_o_in_ready : std_logic;
    signal enc_o_valid : std_logic;
    signal enc_o_symbol : std_logic_vector(WORD_LENGTH-1 downto 0);

    signal dec_o_start_codeword : std_logic;
    signal dec_o_end_codeword : std_logic;
    signal dec_o_error : std_logic;
    signal dec_o_in_ready : std_logic;
    signal dec_o_valid : std_logic;
    signal dec_o_symbol : std_logic_vector(WORD_LENGTH-1 downto 0);

    signal done : boolean := false;

    -- Señales puente para inyección de errores (Canal con ruido)
    signal noisy_i_valid          : std_logic;
    signal noisy_i_start_codeword : std_logic;
    signal noisy_i_end_codeword   : std_logic;
    signal noisy_i_symbol         : std_logic_vector(WORD_LENGTH-1 downto 0);
begin
    enc_i_consume <= dec_o_in_ready;

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

    DECODER_UUT: rs_decoder
                 generic map(N => N,
                             K => K,
                             RS_GF => RS_GF,
                             OUTPUT_PARITY_SYMBOLS => true,
                             FCR => FCR,
                             PRIMITIVE_POLYNOMIAL => PRIMITIVE_POLYNOMIAL,
                             TEST_MODE => false)
                 port map(clk => clk,
                          rst => rst,
                          i_end_codeword => noisy_i_end_codeword,
                          i_start_codeword => noisy_i_start_codeword,
                          i_valid => noisy_i_valid,
                          i_consume => '1',
                          i_symbol => noisy_i_symbol,
                          o_in_ready => dec_o_in_ready,
                          o_end_codeword => dec_o_end_codeword,
                          o_start_codeword => dec_o_start_codeword,
                          o_valid => dec_o_valid,
                          o_error => dec_o_error,
                          o_symbol => dec_o_symbol);

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
        function input_symbol(symbol_index : natural;
                              codeword_index : natural) return natural is
            variable value : natural;
        begin
            value := (symbol_index + 97 + codeword_index * K) mod (2**WORD_LENGTH);
            return value;
        end function;

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

        procedure send_codeword(codeword_index : natural;
                                reverse_order : boolean := false) is
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

                send_symbol(input_symbol(symbol_index, codeword_index),
                            start_codeword => start_codeword,
                            end_codeword => end_codeword);
            end loop;
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
            send_codeword(I, reverse_order => (I mod 2) = 1);
            idle_cycles(6);
        end loop;

        wait;
    end process;

    --------------------------------------------------------------------
    -- Canal de Transmisión (Inyección de Errores)
    --------------------------------------------------------------------
    ERROR_INJECT_PROCESS : process(clk)
        variable current_idx : natural := 0;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                noisy_i_valid          <= '0';
                noisy_i_start_codeword <= '0';
                noisy_i_end_codeword   <= '0';
                noisy_i_symbol         <= (others => '0');
                current_idx            := 0;
            else
                -- Retrasar las señales de control 1 ciclo de reloj
                noisy_i_valid          <= enc_o_valid;
                noisy_i_start_codeword <= enc_o_start_codeword;
                noisy_i_end_codeword   <= enc_o_end_codeword;

                if enc_o_valid = '1' then
                    -- Control del contador de posición dentro de la trama
                    if enc_o_start_codeword = '1' then
                        current_idx := 1;
                    else
                        current_idx := current_idx + 1;
                    end if;

                    -- Inyección de errores: 
                    -- Corrompemos alterando todos los bits (XOR 255)
                    if current_idx = 2 or current_idx = 4 or current_idx = 6 or current_idx = 8 then
                        noisy_i_symbol <= enc_o_symbol xor std_logic_vector(to_unsigned(255, WORD_LENGTH));
                    else
                        -- Pasa el símbolo limpio
                        noisy_i_symbol <= enc_o_symbol;
                    end if;
                end if;
            end if;
        end if;
    end process;

    CHECK_PROCESS : process(clk, rst)
        variable encoded_scoreboard : symbol_array(0 to EXPECTED_SYMBOLS-1);
        variable data_scoreboard : symbol_array(0 to EXPECTED_DATA_SYMBOLS-1);
        variable wr_index : natural range 0 to EXPECTED_SYMBOLS := 0;
        variable rd_index : natural range 0 to EXPECTED_SYMBOLS := 0;
        variable data_wr_index : natural range 0 to EXPECTED_DATA_SYMBOLS := 0;
        variable data_rd_index : natural range 0 to EXPECTED_DATA_SYMBOLS := 0;
        variable enc_codeword_symbol_index : natural range 0 to N-1 := 0;
    begin
        if rst = '1' then
            wr_index := 0;
            rd_index := 0;
            data_wr_index := 0;
            data_rd_index := 0;
            enc_codeword_symbol_index := 0;
        elsif rising_edge(clk) then
            assert enc_o_error = '0'
                report "Encoder reported an error"
                severity error;

            assert dec_o_error = '0'
                report "Decoder reported an error"
                severity error;

            if enc_i_valid = '1' and enc_o_in_ready = '1' and enc_i_consume = '1' then
                assert data_wr_index < EXPECTED_DATA_SYMBOLS
                    report "Encoder accepted more input data symbols than expected"
                    severity failure;
                data_scoreboard(data_wr_index) := enc_i_symbol;
                data_wr_index := data_wr_index + 1;
            end if;

            if enc_o_valid = '1' and dec_o_in_ready = '1' then
                assert wr_index < EXPECTED_SYMBOLS
                    report "Encoded more symbols than expected"
                    severity failure;
                encoded_scoreboard(wr_index) := enc_o_symbol;
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
            end if;

            if dec_o_valid = '1' then
                assert rd_index < wr_index
                    report "Decoder produced a symbol before the matching encoder symbol was stored"
                    severity failure;

                assert dec_o_symbol = encoded_scoreboard(rd_index)
                    report "Decoded symbol differs from encoded symbol at index " &
                           integer'image(rd_index) &
                           ". Encoded=" & integer'image(to_integer(unsigned(encoded_scoreboard(rd_index)))) &
                           ", decoded=" & integer'image(to_integer(unsigned(dec_o_symbol)))
                    severity error;

                rd_index := rd_index + 1;

                if rd_index = EXPECTED_SYMBOLS then
                    assert data_rd_index = EXPECTED_DATA_SYMBOLS
                        report "Not all encoder input data symbols were compared against encoder outputs"
                        severity failure;

                    report "Encoder to decoder comparison passed for " &
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
            report "Simulation timeout before all decoded symbols matched the encoded symbols"
            severity failure;
        wait;
    end process;
end behavioral;
