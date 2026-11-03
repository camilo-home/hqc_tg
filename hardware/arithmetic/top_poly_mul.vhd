library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_poly_mul is
    generic(
        WT         : integer := 3; -- Número de desplazamientos no nulos
        WORD_COUNT : integer := 3  -- 3 palabras densas de 32 bits
    );
    port(
        clk   : in std_logic;
        rst   : in std_logic;
        start : in std_logic;
        done  : out std_logic;

        -- Interfaz externa de carga para memoria de posiciones
        init_pos_we   : in std_logic                       := '0';
        init_pos_addr : in unsigned(6 downto 0)            := (others => '0');
        init_pos_data : in unsigned(14 downto 0)           := (others => '0');

        -- Interfaz externa de carga para memoria densa
        init_dense_we   : in std_logic                     := '0';
        init_dense_addr : in unsigned(9 downto 0)          := (others => '0');
        init_dense_data : in std_logic_vector(31 downto 0) := (others => '0');

        -- Interfaz de lectura externa para el acumulador final
        acc_read_addr : in  unsigned(10 downto 0)          := (others => '0');
        acc_read_dout : out std_logic_vector(31 downto 0)
    );
end entity;

architecture structural of top_poly_mul is

    -- Señales de interconexión
    signal pos_addr_core : unsigned(6 downto 0);
    signal pos_data_core : unsigned(14 downto 0);
    signal pos_addr_mux  : unsigned(6 downto 0);

    signal dense_addr_core : unsigned(9 downto 0);
    signal dense_data_core : std_logic_vector(31 downto 0);
    signal dense_addr_mux  : unsigned(9 downto 0);

    signal acc_addr_a_core : unsigned(10 downto 0);
    signal acc_addr_b_core : unsigned(10 downto 0);
    signal acc_addr_a_mux  : unsigned(10 downto 0);

    signal acc_din_a_core  : std_logic_vector(31 downto 0);
    signal acc_din_b_core  : std_logic_vector(31 downto 0);
    signal acc_dout_a_core : std_logic_vector(31 downto 0);
    signal acc_dout_b_core : std_logic_vector(31 downto 0);

    signal acc_we_a_core   : std_logic;
    signal acc_we_b_core   : std_logic;
    signal done_core       : std_logic;

begin

    done <= done_core;

    -- Multiplexores de control para la carga inicial vs ejecución FSM
    pos_addr_mux   <= init_pos_addr when (init_pos_we = '1') else pos_addr_core;
    dense_addr_mux <= init_dense_addr when (init_dense_we = '1') else dense_addr_core;
    
    -- El puerto A del acumulador se conmuta a lectura externa cuando finaliza la FSM
    acc_addr_a_mux <= acc_read_addr when (done_core = '1') else acc_addr_a_core;
    acc_read_dout  <= acc_dout_a_core;

    -- Instancia del Núcleo de Multiplicación Polinomial
    u_poly_mul : entity work.poly_mul
        generic map(
            WT         => WT,
            WORD_COUNT => WORD_COUNT
        )
        port map(
            clk        => clk,
            rst        => rst,
            start      => start,
            pos_addr   => pos_addr_core,
            pos_data   => pos_data_core,
            dense_addr => dense_addr_core,
            dense_data => dense_data_core,
            acc_addr_a => acc_addr_a_core,
            acc_addr_b => acc_addr_b_core,
            acc_din_a  => acc_din_a_core,
            acc_din_b  => acc_din_b_core,
            acc_dout_a => acc_dout_a_core,
            acc_dout_b => acc_dout_b_core,
            acc_we_a   => acc_we_a_core,
            acc_we_b   => acc_we_b_core,
            done       => done_core
        );

    -- Instancia Memoria de Posiciones (Dispersa)
    u_position_mem : entity work.position_mem
        generic map(
            DATA_WIDTH => 15,
            ADDR_WIDTH => 7
        )
        port map(
            clk  => clk,
            we   => init_pos_we,
            addr => pos_addr_mux,
            din  => init_pos_data,
            dout => pos_data_core
        );

    -- Instancia Memoria Densa (Single-Port BRAM)
    u_dense_mem : entity work.bram_singleport
        generic map(
            DATA_WIDTH => 32,
            ADDR_WIDTH => 10
        )
        port map(
            clk  => clk,
            we   => init_dense_we,
            addr => dense_addr_mux,
            din  => init_dense_data,
            dout => dense_data_core
        );

    -- Instancia Acumulador BRAM (Dual-Port)
    u_acc_mem : entity work.bram_dualport
        generic map(
            DATA_WIDTH => 32,
            ADDR_WIDTH => 11
        )
        port map(
            clk    => clk,
            we_a   => acc_we_a_core,
            addr_a => acc_addr_a_mux,
            din_a  => acc_din_a_core,
            dout_a => acc_dout_a_core,
            we_b   => acc_we_b_core,
            addr_b => acc_addr_b_core,
            din_b  => acc_din_b_core,
            dout_b => acc_dout_b_core
        );

end architecture;