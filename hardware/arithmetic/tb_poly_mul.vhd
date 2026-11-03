library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_poly_mul is
end entity;

architecture behavioral of tb_poly_mul is

    constant CLK_PERIOD : time := 10 ns;
    constant WT_VAL     : integer := 3;
    constant WORD_CNT   : integer := 4;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal start      : std_logic := '0';
    signal done       : std_logic;

    -- Position memory signals
    signal pos_addr   : unsigned(6 downto 0);
    signal pos_data   : unsigned(14 downto 0);
    signal pos_we     : std_logic := '0';
    signal pos_din    : unsigned(14 downto 0) := (others => '0');
    
    -- Dense memory signals (Conectados directo, sin multiplexor)
    signal dense_addr : unsigned(9 downto 0);
    signal dense_data : std_logic_vector(31 downto 0);
    signal dense_we   : std_logic := '0';
    signal dense_din  : std_logic_vector(31 downto 0) := (others => '0');

    -- Accumulator BRAM signals
    signal acc_addr_a : unsigned(10 downto 0);
    signal acc_addr_b : unsigned(10 downto 0);
    signal acc_din_a  : std_logic_vector(31 downto 0);
    signal acc_din_b  : std_logic_vector(31 downto 0);
    signal acc_dout_a : std_logic_vector(31 downto 0);
    signal acc_dout_b : std_logic_vector(31 downto 0);
    signal acc_we_a   : std_logic;
    signal acc_we_b   : std_logic;

begin

    -- 1. DUT (Módulo Multiplicador)
    DUT: entity work.poly_mul
        generic map (
            WT         => WT_VAL,
            WORD_COUNT => WORD_CNT
        )
        port map (
            clk        => clk,
            rst        => rst,
            start      => start,
            pos_addr   => pos_addr,
            pos_data   => pos_data,
            dense_addr => dense_addr, -- Salida directa
            dense_data => dense_data, -- Entrada directa
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

    -- 2. Memoria de Posiciones (Asumimos precargada o manejada internamente)
    U_POS_MEM: entity work.position_mem
        port map (
            clk     => clk,
            rst     => rst,
            we      => pos_we,
            addr    => pos_addr,
            din     => pos_din,
            dout    => pos_data
        );

    -- 3. Memoria Densa Single Port (Conexión Directa)
    U_DENSE_MEM: entity work.BRAM_singleport
        port map (
            clk  => clk,
            we   => dense_we,            -- Nunca escribimos desde el TB
            addr => dense_addr,     -- Conexión directa y única a la salida del DUT
            din  => dense_din,
            dout => dense_data
        );

    -- 4. Memoria Acumuladora Dual Port
    U_ACC_BRAM: entity work.BRAM_dualport
        port map (
            clk    => clk,
            we_a   => acc_we_a,
            addr_a => acc_addr_a,
            din_a  => acc_din_a,
            dout_a => acc_dout_a,
            we_b   => acc_we_b,
            addr_b => acc_addr_b,
            din_b  => acc_din_b,
            dout_b => acc_dout_b
        );

    -- Reloj
    clk_process : process
    begin
        clk <= '0';
        wait for CLK_PERIOD / 2;
        clk <= '1';
        wait for CLK_PERIOD / 2;
    end process;

    -- Control de Simulación
    stim_proc: process
    begin
        rst <= '1';
        start <= '0';
        wait for 40 ns;
        
        rst <= '0';
        wait for 20 ns;
    
        pos_addr <= to_unsigned(0, 7); pos_din <= to_unsigned(3, 15); pos_we <= '1'; wait for CLK_PERIOD;
        pos_addr <= to_unsigned(1, 7); pos_din <= to_unsigned(35, 15); pos_we <= '1'; wait for CLK_PERIOD;
        pos_addr <= to_unsigned(2, 7); pos_din <= to_unsigned(97, 15); pos_we <= '1'; wait for CLK_PERIOD;
        pos_we <= '0';

        dense_addr <= to_unsigned(0, 10); dense_din <= x"9009C00C"; dense_we <= '1'; wait for CLK_PERIOD;
        dense_addr <= to_unsigned(1, 10); dense_din <= x"9009C00C"; dense_we <= '1'; wait for CLK_PERIOD;
        dense_addr <= to_unsigned(2, 10); dense_din <= x"9009C00C"; dense_we <= '1'; wait for CLK_PERIOD;
        dense_addr <= to_unsigned(3, 10); dense_din <= x"0000007F"; dense_we <= '1'; wait for CLK_PERIOD;
        dense_we <= '0';
        -- Iniciar la multiplicación directamente (los datos ya están en la RAM)

        start <= '1';
        wait for CLK_PERIOD;
        start <= '0';

        wait until rising_edge(done);
        
        wait for 50 ns;
        assert false report "Fin de la simulación" severity failure;
    end process;

end architecture;