library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_poly_mul is
end entity;

architecture sim of tb_poly_mul is

    -- Constantes de configuración para 128 bits y 10 posiciones activas
    constant WT_C         : integer := 10;
    constant WORD_COUNT_C : integer := 4; -- 128 bits / 32 bits por palabra = 4 palabras
    constant CLK_PERIOD   : time := 10 ns;

    -- Señales de estímulo y control
    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal start : std_logic := '0';
    signal done  : std_logic;

    -- Interfaces de memoria
    signal pos_addr   : unsigned(6 downto 0);
    signal pos_data   : unsigned(14 downto 0);
    signal dense_addr : unsigned(9 downto 0);
    signal dense_data : std_logic_vector(31 downto 0);
    
    signal acc_addr_a : unsigned(10 downto 0);
    signal acc_addr_b : unsigned(10 downto 0);
    signal acc_din_a  : std_logic_vector(31 downto 0);
    signal acc_din_b  : std_logic_vector(31 downto 0);
    signal acc_dout_a : std_logic_vector(31 downto 0);
    signal acc_dout_b : std_logic_vector(31 downto 0);
    signal acc_we_a   : std_logic;
    signal acc_we_b   : std_logic;

    -- Modelos de Memorias (ROMs y RAMs para simulación)
    -- 1. Memoria Posicional: 10 posiciones con índices de bits aleatorios dentro de 0 a 127
    type pos_rom_type is array (0 to WT_C - 1) of unsigned(14 downto 0);
    constant POS_ROM : pos_rom_type := (
        to_unsigned(3, 15),   -- Posición de bit 3
        to_unsigned(15, 15),  -- Posición de bit 15
        to_unsigned(34, 15),  -- Posición de bit 34 (Word 1, bit 2)
        to_unsigned(47, 15),  -- Posición de bit 47
        to_unsigned(68, 15),  -- Posición de bit 68 (Word 2, bit 4)
        to_unsigned(81, 15),  -- Posición de bit 81
        to_unsigned(99, 15),  -- Posición de bit 99 (Word 3, bit 3)
        to_unsigned(110, 15), -- Posición de bit 110
        to_unsigned(121, 15), -- Posición de bit 121
        to_unsigned(127, 15)  -- Posición de bit 127 (Último bit del vector de 128 bits)
    );

    -- 2. Memoria Vector Denso: 4 palabras de 32 bits (128 bits en total)
    type dense_rom_type is array (0 to WORD_COUNT_C - 1) of std_logic_vector(31 downto 0);
    constant DENSE_ROM : dense_rom_type := (
        x"A5A5A5A5", -- Palabra 0 (Bits 0 a 31)
        x"12345678", -- Palabra 1 (Bits 32 a 63)
        x"DEADBEEF", -- Palabra 2 (Bits 64 a 95)
        x"0F0F0F0F"  -- Palabra 3 (Bits 96 a 127)
    );

    -- 3. Memoria Acumuladora BRAM (2048 posiciones de 32 bits)
    type acc_ram_type is array (0 to 2047) of std_logic_vector(31 downto 0);
    signal acc_ram : acc_ram_type := (others => (others => '0'));

begin

    -- Instancia del módulo bajo prueba (DUT)
    DUT: entity work.poly_mul
        generic map (
            WT         => WT_C,
            WORD_COUNT => WORD_COUNT_C
        )
        port map (
            clk        => clk,
            rst        => rst,
            start      => start,
            pos_addr   => pos_addr,
            pos_data   => pos_data,
            dense_addr => dense_addr,
            dense_data => dense_data,
            acc_addr_a => acc_addr_a,
            acc_addr_b => acc_addr_b,
            acc_din_a  => acc_din_a,
            acc_din_b  => acc_din_b,
            acc_dout_a => acc_dout_a,
            acc_dout_b => acc_dout_b,
            acc_we_a   => acc_we_a,
            acc_we_b   => acc_we_b,
            done       => done
        );

    -- Generador de Reloj
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Modelo de Memoria Posicional (ROM síncrona)
    pos_mem_proc : process(clk)
    begin
        if rising_edge(clk) then
            pos_data <= POS_ROM(to_integer(pos_addr));
        end if;
    end process;

    -- Modelo de Memoria de Vector Denso (ROM síncrona)
    dense_mem_proc : process(clk)
    begin
        if rising_edge(clk) then
            if to_integer(dense_addr) < WORD_COUNT_C then
                dense_data <= DENSE_ROM(to_integer(dense_addr));
            else
                dense_data <= (others => '0');
            end if;
        end if;
    end process;

    -- Modelo de Memoria Acumuladora BRAM (Dual-Port Síncrona)
    acc_ram_proc : process(clk)
    begin
        if rising_edge(clk) then
            -- Puerto A: Lectura
            acc_dout_a <= acc_ram(to_integer(acc_addr_a));

            -- Puerto B: Escritura
            if acc_we_b = '1' then
                acc_ram(to_integer(acc_addr_b)) <= acc_din_b;
            end if;
        end if;
    end process;

    -- Proceso de Estímulos Principales
    stimulus_proc : process
    begin
        -- Inicialización y Reset
        rst   <= '1';
        start <= '0';
        wait for 40 ns;
        
        rst <= '0';
        wait for 20 ns;

        -- Iniciar la multiplicación polinomial
        report ">>> Iniciando prueba de multiplicacion polinomial (WT = 10, 128-bits)...";
        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        -- Esperar a que la señal 'done' se ponga en alto
        wait until rising_edge(done);
        report ">>> Multiplicacion finalizada con exito por el modulo DUT.";

        -- Mostrar algunos resultados de la memoria acumuladora
        wait for 50 ns;
        report "--- Resultados en la BRAM Acumuladora ---";
        for i in 0 to WORD_COUNT_C + 2 loop
            report "Acc_RAM[" & integer'image(i) & "] = 0x" & 
                   to_hstring(std_logic_vector'(acc_ram(i)));
        end loop;

        -- Finalizar simulación
        wait for 100 ns;
        assert false report "Simulacion completada correctamente." severity failure;
    end process;

end architecture;
