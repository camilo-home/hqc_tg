library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library WORK;
use WORK.RS_COMPONENTS.rs_decoder;
use WORK.RS_FUNCTIONS.get_word_length_from_rs_gf;
use WORK.TB_RS_ENCODER_DECODER_PARAMS.all;

entity tb_rs_decoder is
end tb_rs_decoder;

architecture behavioral of tb_rs_decoder is

    constant WORD_LENGTH : natural := get_word_length_from_rs_gf(TB_N, TB_RS_GF);
    constant CLK_PERIOD  : time := 10 ns;

    -- Activa o desactiva la inyección de errores manteniendo el vector limpio de referencia
    constant INJECT_ERRORS : boolean := true;

    -- Señales del sistema
    signal clk : std_logic;
    signal rst : std_logic;

    -- Entradas al Decoder
    signal i_start_codeword : std_logic;
    signal i_end_codeword   : std_logic;
    signal i_valid          : std_logic;
    signal i_consume        : std_logic;
    signal i_symbol         : std_logic_vector(WORD_LENGTH-1 downto 0);

    -- Salidas del Decoder
    signal o_start_codeword : std_logic;
    signal o_end_codeword   : std_logic;
    signal o_error          : std_logic;
    signal o_in_ready       : std_logic;
    signal o_valid          : std_logic;
    signal o_symbol         : std_logic_vector(WORD_LENGTH-1 downto 0);

    -- Palabra: EDA27A14973188FE613AC94FBEDF1106416FB391801BBEE1E2E7677430BF74B2D352CF74C934069C9DE74757F505
    -- Orden: índice 0 = b0 (16#05#) ... índice 45 = b45 (16#ED#)
    type codeword_array is array (0 to TB_N-1) of natural;
    constant ENCODED_VECTOR : codeword_array := (
        -- Bytes de datos: b0 .. b15
        16#05#, 16#F5#, 16#57#, 16#47#, 16#E7#, 16#9D#, 16#9C#, 16#06#,
        16#34#, 16#C9#, 16#74#, 16#CF#, 16#52#, 16#D3#, 16#B2#, 16#74#,
        -- Bytes de paridad: b16 .. b45
        16#BF#, 16#30#, 16#74#, 16#67#, 16#E7#, 16#E2#, 16#E1#, 16#BE#,
        16#1B#, 16#80#, 16#91#, 16#B3#, 16#6F#, 16#41#, 16#06#, 16#11#,
        16#DF#, 16#BE#, 16#4F#, 16#C9#, 16#3A#, 16#61#, 16#FE#, 16#88#,
        16#31#, 16#97#, 16#14#, 16#7A#, 16#A2#, 16#ED#
    );

    -- Máscara XOR de errores: 15 símbolos corrompidos (límite máximo t = 15 para RS(46,16))
    constant ERROR_MASK : codeword_array := (
        -- 6 errores en datos (índices 0..15)
        0  => 16#FF#,
        3  => 16#A5#,
        4  => 16#FF#,
        7  => 16#5A#,
        11 => 16#3C#,
        15 => 16#C3#,
        -- 9 errores en paridad (índices 16..45)
        16 => 16#81#,
        19 => 16#7E#,
        22 => 16#1F#,
        24 => 16#FF#,
        28 => 16#E0#,
        33 => 16#55#,
        37 => 16#AA#,
        41 => 16#0F#,
        45 => 16#F0#,
        others => 16#00#
    );

begin

    --------------------------------------------------------------------
    -- Unidad Bajo Prueba (Decoder) con parámetros de TB_RS_ENCODER_DECODER_PARAMS
    --------------------------------------------------------------------
    UUT : rs_decoder
        generic map (
            N                    => TB_N,
            K                    => TB_K,
            RS_GF                => TB_RS_GF,
            FCR                  => TB_FCR,
            PRIMITIVE_POLYNOMIAL => TB_PRIMITIVE_POLYNOMIAL,
            TEST_MODE            => false
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
    -- Reloj
    --------------------------------------------------------------------
    CLK_PROCESS : process
    begin
        clk <= '1'; wait for CLK_PERIOD/2;
        clk <= '0'; wait for CLK_PERIOD/2;
    end process;

    --------------------------------------------------------------------
    -- Proceso de Estímulos y Envío Manual de Trama
    --------------------------------------------------------------------
    STIM_PROCESS : process
    begin
        rst <= '1';
        i_start_codeword <= '0';
        i_end_codeword   <= '0';
        i_valid          <= '0';
        i_consume        <= '1';
        i_symbol         <= (others => '0');

        wait for CLK_PERIOD * 5;
        wait until falling_edge(clk);
        rst <= '0';

        for wait_cycles in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;

        ----------------------------------------------------------------
        -- Envío de TB_NUM_CODEWORDS tramas de 46 símbolos
        ----------------------------------------------------------------
        for cw in 0 to TB_NUM_CODEWORDS-2 loop
            for I in 0 to TB_N-1 loop
                wait until falling_edge(clk);

                if INJECT_ERRORS then
                    i_symbol <= std_logic_vector(
                        to_unsigned(ENCODED_VECTOR(I), WORD_LENGTH) xor
                        to_unsigned(ERROR_MASK(I), WORD_LENGTH)
                    );
                else
                    i_symbol <= std_logic_vector(to_unsigned(ENCODED_VECTOR(I), WORD_LENGTH));
                end if;

                i_valid <= '1';

                if I = 0 then
                    i_start_codeword <= '1';
                    i_end_codeword   <= '0';
                elsif I = TB_N-1 then
                    i_start_codeword <= '0';
                    i_end_codeword   <= '1';
                else
                    i_start_codeword <= '0';
                    i_end_codeword   <= '0';
                end if;

                loop
                    wait until rising_edge(clk);
                    exit when o_in_ready = '1';
                end loop;
            end loop;

            wait until falling_edge(clk);
            i_valid          <= '0';
            i_start_codeword <= '0';
            i_end_codeword   <= '0';
            i_symbol         <= (others => '0');

            for gap in 1 to 6 loop
                wait until rising_edge(clk);
            end loop;
        end loop;

        wait;
    end process;

    --------------------------------------------------------------------
    -- Verificación automática de la salida decodificada
    --------------------------------------------------------------------
    CHECK_PROCESS : process(clk, rst)
        variable out_idx : natural := 0;
    begin
        if rst = '1' then
            out_idx := 0;
        elsif rising_edge(clk) then
            assert o_error = '0'
                report "Decoder reporto un error no corregible (o_error = '1')"
                severity error;

            if o_valid = '1' and i_consume = '1' then
                assert to_integer(unsigned(o_symbol)) = ENCODED_VECTOR(out_idx mod TB_N)
                    report "Discrepancia en simbolo de salida [" & integer'image(out_idx) &
                           "]: esperado=" & integer'image(ENCODED_VECTOR(out_idx mod TB_N)) &
                           ", recibido=" & integer'image(to_integer(unsigned(o_symbol)))
                    severity error;

                if o_end_codeword = '1' then
                    report "Codeword decodificado y verificado correctamente (15 errores corregidos)." severity note;
                    out_idx := 0;
                else
                    out_idx := out_idx + 1;
                end if;
            end if;
        end if;
    end process;

end behavioral;