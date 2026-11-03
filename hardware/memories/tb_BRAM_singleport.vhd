library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_BRAM_singleport is
end entity;

architecture behavioral of tb_BRAM_singleport is

    constant CLK_PERIOD : time := 10 ns;

    signal clk   : std_logic := '0';
    signal we    : std_logic := '0';
    signal addr  : unsigned(9 downto 0) := (others => '0');
    signal din   : std_logic_vector(31 downto 0) := (others => '0');
    signal dout  : std_logic_vector(31 downto 0);

begin

    -- Instanciación del componente de memoria
    DUT: entity work.BRAM_singleport
        port map (
            clk   => clk,
            we    => we,
            addr  => addr,
            din   => din,
            dout  => dout
        );

    -- Generación de reloj
    clk_process: process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Proceso de estímulos (Escritura y Lectura)
    stim_proc: process
    begin
        wait for 20 ns;

        -- 1. Escribir un valor en la dirección 10
        addr <= to_unsigned(10, 10);
        din  <= x"DEADBEEF";
        we   <= '1';
        wait for CLK_PERIOD;

        -- 2. Escribir otro valor en la dirección 11
        addr <= to_unsigned(11, 10);
        din  <= x"CAFE1234";
        we   <= '1';
        wait for CLK_PERIOD;

        -- Desactivar escritura
        we <= '0';
        wait for CLK_PERIOD;

        -- 3. Leer la dirección 10
        addr <= to_unsigned(10, 10);
        wait for CLK_PERIOD * 2; -- Esperar ciclos de lectura de la BRAM

        -- 4. Leer la dirección 11
        addr <= to_unsigned(11, 10);
        wait for CLK_PERIOD * 2;

        wait for 30 ns;
        assert false report "Fin de la simulación de la BRAM" severity failure;
    end process;

end architecture;