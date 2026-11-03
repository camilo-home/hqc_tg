library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top_poly_mul is
end entity;

architecture sim of tb_top_poly_mul is

    constant CLK_PERIOD : time := 10 ns;

    constant WT         : integer := 3;
    constant WORD_COUNT : integer := 3;

    signal clk   : std_logic := '0';
    signal rst   : std_logic := '0';
    signal start : std_logic := '0';
    signal done  : std_logic;

    -- Entradas para la precarga de memorias
    signal init_pos_we   : std_logic := '0';
    signal init_pos_addr : unsigned(6 downto 0) := (others => '0');
    signal init_pos_data : unsigned(14 downto 0) := (others => '0');

    signal init_dense_we   : std_logic := '0';
    signal init_dense_addr : unsigned(9 downto 0) := (others => '0');
    signal init_dense_data : std_logic_vector(31 downto 0) := (others => '0');

    signal acc_read_addr : unsigned(10 downto 0) := (others => '0');
    signal acc_read_dout : std_logic_vector(31 downto 0);

begin

    -- Generador de reloj (100 MHz)
    clk <= not clk after CLK_PERIOD / 2;

    -- UUT (Unit Under Test)
    uut: entity work.top_poly_mul
        generic map(
            WT         => WT,
            WORD_COUNT => WORD_COUNT
        )
        port map(
            clk             => clk,
            rst             => rst,
            start           => start,
            done            => done,
            init_pos_we     => init_pos_we,
            init_pos_addr   => init_pos_addr,
            init_pos_data   => init_pos_data,
            init_dense_we   => init_dense_we,
            init_dense_addr => init_dense_addr,
            init_dense_data => init_dense_data,
            acc_read_addr   => acc_read_addr,
            acc_read_dout   => acc_read_dout
        );

    -- Proceso de estímulos
    stim_proc: process
    begin
        -- 1. Reset inicial
        rst <= '1';
        wait for CLK_PERIOD * 2;
        rst <= '0';
        wait for CLK_PERIOD;

        -- 2. Cargar Memoria Densa (3 palabras de 32 bits)
        init_dense_we <= '1';
        
        init_dense_addr <= to_unsigned(0, 10);
        init_dense_data <= x"C000000F";
        wait for CLK_PERIOD;

        init_dense_addr <= to_unsigned(1, 10);
        init_dense_data <= x"C000000F";
        wait for CLK_PERIOD;

        init_dense_addr <= to_unsigned(2, 10);
        init_dense_data <= x"C000000F";
        wait for CLK_PERIOD;
        
        init_dense_we   <= '0';

        -- 3. Cargar Memoria de Posiciones (Desplazamientos: 3, 35 y 70)
        init_pos_we <= '1';

        -- Posición 0: Desplazamiento de 3 bits
        init_pos_addr <= to_unsigned(0, 7);
        init_pos_data <= to_unsigned(3, 15);
        wait for CLK_PERIOD;

        -- Posición 1: Desplazamiento de 35 bits (word_offset=1, bit_offset=3)
        init_pos_addr <= to_unsigned(1, 7);
        init_pos_data <= to_unsigned(35, 15);
        wait for CLK_PERIOD;

        -- Posición 2: Desplazamiento de 70 bits (word_offset=2, bit_offset=6)
        init_pos_addr <= to_unsigned(2, 7);
        init_pos_data <= to_unsigned(70, 15);
        wait for CLK_PERIOD;

        init_pos_we <= '0';
        wait for CLK_PERIOD * 2;

        -- 4. Iniciar la Multiplicación
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        -- 5. Esperar finalización del cómputo y reducción
        wait until done = '1';
        wait for CLK_PERIOD * 2;

        -- 6. Leer los resultados finales del anillo (Palabras 0, 1 y 2)
        acc_read_addr <= to_unsigned(0, 11);
        wait for CLK_PERIOD * 2;
        -- Verificación: acc_read_dout contiene la palabra 0 reducida

        acc_read_addr <= to_unsigned(1, 11);
        wait for CLK_PERIOD * 2;
        -- Verificación: acc_read_dout contiene la palabra 1 reducida

        acc_read_addr <= to_unsigned(2, 11);
        wait for CLK_PERIOD * 2;
        -- Verificación: acc_read_dout contiene la palabra 2 reducida

        report "Simulación completada con éxito." severity note;
        wait;
    end process;

end architecture;