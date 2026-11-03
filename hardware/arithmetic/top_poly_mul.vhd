library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity top_poly_mul is
    generic(
        WT         : integer := 3;  -- 66 o 75 según el muestreo
        WORD_COUNT : integer := 1;  -- Palabras necesarias para 17669 bits
        N_BITS     : integer := 32 -- Tamaño exacto del anillo en bits
    );
    port(
        clk   : in std_logic;
        rst   : in std_logic;
        start : in std_logic;
        done  : out std_logic;

        -- Puertos opcionales de carga externa (útiles para inicializar memorias desde fuera)
        ext_pos_we   : in std_logic := '0';
        ext_pos_addr : in unsigned(6 downto 0) := (others => '0');
        ext_pos_din  : in unsigned(14 downto 0) := (others => '0');

        ext_dense_we   : in std_logic := '0';
        ext_dense_addr : in unsigned(9 downto 0) := (others => '0');
        ext_dense_din  : in std_logic_vector(31 downto 0) := (others => '0')
    );
end entity;

architecture structural of top_poly_mul is

    -- Señales de interconexión interna entre poly_mul y las memorias
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

    -- Multiplexación para permitir escritura externa o de prueba en las memorias
    signal final_pos_we   : std_logic;
    signal final_pos_addr : unsigned(6 downto 0);
    signal final_pos_din  : unsigned(14 downto 0);

    signal final_dense_we   : std_logic;
    signal final_dense_addr : unsigned(9 downto 0);
    signal final_dense_din  : std_logic_vector(31 downto 0);

begin

    -- Multiplexores de control para la memoria posicional
    -- (Durante la operación normal del multiplicador, no escribe en position_mem, solo lee)
    final_pos_we   <= ext_pos_we;
    final_pos_addr <= ext_pos_addr when ext_pos_we = '1' else (others => '0');
    final_pos_din  <= ext_pos_din;

    -- Multiplexores de control para la memoria del vector denso
    final_dense_we   <= ext_dense_we;
    final_dense_addr <= ext_dense_addr when ext_dense_we = '1' else dense_addr;
    final_dense_din  <= ext_dense_din;

    ---------------------------------------------------------------------------
    -- 1. Instancia del Multiplicador Polinomial
    ---------------------------------------------------------------------------
    u_poly_mul : entity work.poly_mul
        generic map (
            WT         => WT,
            WORD_COUNT => WORD_COUNT,
            N_BITS     => N_BITS
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

    ---------------------------------------------------------------------------
    -- 2. Instancia de la Memoria Posicional (`position_mem`)
    ---------------------------------------------------------------------------
    u_position_mem : entity work.position_mem
        port map (
            clk     => clk,
            rst     => rst,
            we      => final_pos_we,
            addr    => final_pos_addr,
            din     => final_pos_din,
            re_addr => pos_addr,
            dout    => pos_data
        );

    ---------------------------------------------------------------------------
    -- 3. Instancia del Vector Denso (`BRAM_singleport`)
    ---------------------------------------------------------------------------
    u_dense_mem : entity work.BRAM_singleport
        port map (
            clk  => clk,
            we   => final_dense_we,
            addr => final_dense_addr,
            din  => final_dense_din,
            dout => dense_data
        );

    ---------------------------------------------------------------------------
    -- 4. Instancia de la Memoria Acumuladora (`BRAM_dualport`)
    ---------------------------------------------------------------------------
    u_acc_bram : entity work.BRAM_dualport
        port map (
            clk    => clk,
            -- Puerto A: Utilizado exclusivamente para lectura en el pipeline
            we_a   => acc_we_a,
            addr_a => acc_addr_a,
            din_a  => acc_din_a,
            dout_a => acc_dout_a,
            -- Puerto B: Utilizado exclusivamente para escritura del resultado XOR
            we_b   => acc_we_b,
            addr_b => acc_addr_b,
            din_b  => acc_din_b,
            dout_b => acc_dout_b
        );

end architecture;
