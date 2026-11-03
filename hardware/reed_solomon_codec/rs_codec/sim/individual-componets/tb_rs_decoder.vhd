library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library WORK;
use WORK.RS_COMPONENTS.rs_decoder;
use WORK.RS_FUNCTIONS.get_word_length_from_rs_gf;
-- Carga del paquete de parámetros para la config RS(46,16)
use WORK.TB_RS_ENCODER_DECODER_PARAMS.all;

entity tb_rs_decoder is
end tb_rs_decoder;

architecture behavioral of tb_rs_decoder is

    constant WORD_LENGTH : natural := get_word_length_from_rs_gf(TB_N, TB_RS_GF);
    constant CLK_PERIOD : time := 10 ns;

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

    -- Declaración del vector codificado estático RS(46,16)
    type codeword_array is array (0 to TB_N-1) of natural;
    constant ENCODED_VECTOR : codeword_array := (
        97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112,
        18, 71, 141, 47, 92, 10, 106, 47, 149, 107, 227, 208, 196, 227, 136, 192, 
        50, 97, 227, 73, 0, 93, 123, 150, 38, 134, 2, 253, 32, 96
    );

begin

    --------------------------------------------------------------------
    -- Unidad Bajo Prueba (Decoder)
    --------------------------------------------------------------------
    UUT : rs_decoder
        generic map (
            N         => TB_N,
            K         => TB_K,
            RS_GF     => TB_RS_GF,
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
        
        -- Estado inicial
        rst <= '1';
        i_start_codeword <= '0';
        i_end_codeword   <= '0';
        i_valid          <= '0';
        i_consume        <= '1'; -- Siempre listo para consumir salida
        i_symbol         <= (others => '0');

        wait for CLK_PERIOD * 5;
        wait until falling_edge(clk);
        rst <= '0';

        -- Pausa antes de iniciar
        for wait_cycles in 1 to 5 loop
            wait until rising_edge(clk);
        end loop;

        ----------------------------------------------------------------
        -- Envío de los 46 símbolos con inyección de error manual
        ----------------------------------------------------------------
        for I in 0 to TB_N-1 loop
            wait until falling_edge(clk);
            
            -- INYECCIÓN DE ERRORES INTENCIONALES
            -- Corrompemos el índice 4 (datos) y el índice 24 (paridad)
            if I = 4 or I = 24 then
                i_symbol <= std_logic_vector( to_unsigned(ENCODED_VECTOR(I), WORD_LENGTH) xor to_unsigned(255, WORD_LENGTH) );
            else
                i_symbol <= std_logic_vector( to_unsigned(ENCODED_VECTOR(I), WORD_LENGTH) );
            end if;

            i_valid <= '1';

            -- Control de delimitadores de trama
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

            wait until rising_edge(clk);
        end loop;

        -- Bajar las señales tras enviar el último símbolo
        wait until falling_edge(clk);
        i_valid <= '0';
        i_start_codeword <= '0';
        i_end_codeword <= '0';
        i_symbol <= (others => '0');

        -- Mantener la simulación corriendo para observar cómo el decodificador 
        -- procesa los polinomios de error y escupe la trama ya corregida
        wait;

    end process;

end behavioral;