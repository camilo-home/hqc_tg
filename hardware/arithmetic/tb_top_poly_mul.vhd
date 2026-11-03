library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_top_poly_mul is
end entity;

architecture sim of tb_top_poly_mul is

    -- Parámetros de configuración (usando una escala reducida de prueba para claridad)
    constant WT_C         : integer := 2;
    constant WORD_COUNT_C : integer := 5;
    constant N_BITS_C       : integer := 135; -- Tamaño exacto del anillo en bits
    constant CLK_PERIOD   : time := 10 ns;

    -- Señales del testbench
    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal start : std_logic := '0';
    signal done  : std_logic;

    -- Puertos de control externo para precargar memorias
    signal ext_pos_we     : std_logic := '0';
    signal ext_pos_addr   : unsigned(6 downto 0) := (others => '0');
    signal ext_pos_din    : unsigned(14 downto 0) := (others => '0');

    signal ext_dense_we   : std_logic := '0';
    signal ext_dense_addr : unsigned(9 downto 0) := (others => '0');
    signal ext_dense_din  : std_logic_vector(31 downto 0) := (others => '0');

begin

    -- Instancia del Top-Level bajo prueba (DUT)
    DUT: entity work.top_poly_mul
        generic map (
            WT         => WT_C,
            WORD_COUNT => WORD_COUNT_C,
            N_BITS     => N_BITS_C
        )
        port map (
            clk            => clk,
            rst            => rst,
            start          => start,
            done           => done,
            ext_pos_we     => ext_pos_we,
            ext_pos_addr   => ext_pos_addr,
            ext_pos_din    => ext_pos_din,
            ext_dense_we   => ext_dense_we,
            ext_dense_addr => ext_dense_addr,
            ext_dense_din  => ext_dense_din
        );

    -- Generador de Reloj
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Proceso principal de estímulos y carga de datos
    stimulus_proc : process
    begin
        -- 1. Reset del Sistema
        rst          <= '1';
        start        <= '0';
        ext_pos_we   <= '0';
        ext_dense_we <= '0';
        wait for 40 ns;
        
        rst <= '0';
        wait for 20 ns;

        report ">>> Iniciando precarga de memorias (Posicional y Vector Denso)...";

        -- 2. Precargar Memoria Posicional (10 posiciones de prueba dentro de 128 bits)
        -- Formato: pos_data de 15 bits -> [14..5] = word_offset, [4..0] = bit_offset
        -- Para 128 bits, los offsets de palabras van de 0 a 3.
        
        -- Posición 0: bit 3  -> word 0, bit 3
        ext_pos_addr <= to_unsigned(0, 7); ext_pos_din <= to_unsigned(3, 15);   ext_pos_we <= '1'; wait for CLK_PERIOD;
        -- Posición 1: bit 15 -> word 0, bit 15
        ext_pos_addr <= to_unsigned(1, 7); ext_pos_din <= to_unsigned(45, 15);  ext_pos_we <= '1'; wait for CLK_PERIOD;
        
        ext_pos_we <= '0';

        -- 3. Precargar Memoria del Vector Denso (4 palabras de 32 bits = 128 bits)
        ext_dense_addr <= to_unsigned(0, 10); ext_dense_din <= x"9009C00C"; ext_dense_we <= '1'; wait for CLK_PERIOD;
        ext_dense_addr <= to_unsigned(1, 10); ext_dense_din <= x"9009C00C"; ext_dense_we <= '1'; wait for CLK_PERIOD;
        ext_dense_addr <= to_unsigned(2, 10); ext_dense_din <= x"9009C00C"; ext_dense_we <= '1'; wait for CLK_PERIOD;
        ext_dense_addr <= to_unsigned(3, 10); ext_dense_din <= x"9009C00C"; ext_dense_we <= '1'; wait for CLK_PERIOD;
        ext_dense_addr <= to_unsigned(4, 10); ext_dense_din <= x"0000007F"; ext_dense_we <= '1'; wait for CLK_PERIOD;
        
        ext_dense_we <= '0';
        wait for 20 ns;

        -- 4. Disparar el Multiplicador Polinomial
        report ">>> Disparando la senal START...";
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        -- 5. Esperar a que la bandera 'done' se active
        wait until rising_edge(done);
        report ">>> ¡Multiplicación completada con éxito por el TOP!";

        -- Finalizar simulación
        wait for 50 ns;
        assert false report "Simulación finalizada correctamente." severity failure;
    end process;

end architecture;
