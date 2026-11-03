library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_keccak_top is
end tb_keccak_top;

architecture behavior of tb_keccak_top is

    constant CLK_PERIOD : time := 10 ns;

    -- Señales del sistema
    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    -- Interfaz de entrada (Source)
    signal src_ready : std_logic := '1'; -- ACTIVO EN BAJO (Inactivo por defecto)
    signal src_read  : std_logic;        -- ACTIVO EN ALTO
    signal din       : std_logic_vector(63 downto 0) := (others => '0');

    -- Interfaz de salida (Destination)
    signal dst_ready : std_logic := '1'; -- ACTIVO EN BAJO (Inactivo por defecto)
    signal dst_write : std_logic;        -- ACTIVO EN ALTO
    signal dout      : std_logic_vector(63 downto 0);

    component keccak_top is
        -- generic ( HS : integer := 256 ); -- Usualmente omitido o dejado por defecto
        port (
            rst       : in  std_logic;
            clk       : in  std_logic;
            src_ready : in  std_logic;
            src_read  : out std_logic;
            dst_ready : in  std_logic;
            dst_write : out std_logic;
            din       : in  std_logic_vector(63 downto 0);
            dout      : out std_logic_vector(63 downto 0)
        );
    end component;

begin

    --------------------------------------------------------------------
    -- Unidad Bajo Prueba (UUT)
    --------------------------------------------------------------------
    UUT : keccak_top
        port map (
            rst       => rst,
            clk       => clk,
            src_ready => src_ready,
            src_read  => src_read,
            dst_ready => dst_ready,
            dst_write => dst_write,
            din       => din,
            dout      => dout
        );

    --------------------------------------------------------------------
    -- Generador de Reloj
    --------------------------------------------------------------------
    CLK_PROCESS : process
    begin
        clk <= '1'; wait for CLK_PERIOD / 2;
        clk <= '0'; wait for CLK_PERIOD / 2;
    end process;

    --------------------------------------------------------------------
    -- Proceso de Estímulos y Comandos
    --------------------------------------------------------------------
    STIM_PROCESS : process
    begin
        -- 1. Estado Inicial y Reset Activo en Alto
        rst <= '1';
        src_ready <= '1'; -- '1' significa NO válido[cite: 2]
        dst_ready <= '1'; -- '1' significa NO listo para recibir[cite: 2]
        din <= (others => '0');
        wait for CLK_PERIOD * 4;
        
        wait until falling_edge(clk);
        rst <= '0';
        wait for CLK_PERIOD * 2;

        ----------------------------------------------------------------
        -- 2. FASE DE COMANDO
        -- Formato del Comando[cite: 2]:
        -- din[63:60] = 0x8 (Modo SHA3-256)
        -- din[59:32] = 0x0000100 (Salida de 256 bits = 0x100 en Hex)
        -- din[31:0]  = 0x00000040 (Entrada de 64 bits = 0x40 en Hex)
        ----------------------------------------------------------------
        wait until falling_edge(clk);
        din <= x"C000004000000080"; 
        
        wait until falling_edge(clk);
        src_ready <= '0'; -- Afirmar '0' para indicar dato válido[cite: 2]
        
        -- Handshake: Esperar a que el módulo levante src_read a '1'[cite: 2]
        wait until rising_edge(clk) and src_read = '1';

        ----------------------------------------------------------------
        -- 3. FASE DE DATA (Mensaje Semilla)
        -- Enviamos una semilla de 64 bits (Little-endian format)[cite: 2]
        ----------------------------------------------------------------
        wait until falling_edge(clk);
        din <= x"A36EECD800000000"; -- Semilla de ejemplo

        wait until falling_edge(clk);
        src_ready <= '0'; -- Mantener en '0' porque el dato sigue siendo válido
        
        wait until rising_edge(clk) and src_read = '1';
        
        -- Detener inyección de datos
        --wait until falling_edge(clk);
        --src_ready <= '1'; -- Inactivar en '1'[cite: 2]
        --din <= (others => '0');
        wait;
        ----------------------------------------------------------------
        -- 4. FASE DE LECTURA DE HASH
        ----------------------------------------------------------------
        -- Le indicamos al módulo que estamos listos para recibir 
        -- afirmando dst_ready en BAJO ('0')[cite: 2]
        -- wait until dst_write = '1'; -- Esperar a que el módulo indique que hay datos válidos
        dst_ready <= '0';
        wait;
    end process;

end behavior;