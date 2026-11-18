library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;
use std.textio.all;

entity tb_rm_encoder is
end tb_rm_encoder;

architecture behavioral of tb_rm_encoder is
    -- Parámetros de HQC-128: RM(1, 7) con multiplicidad 3 -> 3 * 128 = 384 bits por byte
    constant M_VAL : natural := 7;
    constant REP_VAL : natural := 3;
    constant GEN_MAT_01 : boolean := false;
    constant STEP_PERIOD : time := 10 ns;
    constant NUM_BYTES : natural := 46;

    type byte_array is array (0 to NUM_BYTES - 1) of std_logic_vector(M_VAL downto 0);

    -- Cadena original: EDA27A14973188FE613AC94FBEDF1106416FB391801BBEE1E2E7677430BF74B2D352CF74C934069C9DE74757F505
    -- Orden de entrada: 05 (índice 0) -> ... -> ED (índice 45)
    constant INPUT_WORDS : byte_array := (
        -- Bytes 0..7
        x"05", x"F5", x"57", x"47", x"E7", x"9D", x"9C", x"06",
        -- Bytes 8..15
        x"34", x"C9", x"74", x"CF", x"52", x"D3", x"B2", x"74",
        -- Bytes 16..23
        x"BF", x"30", x"74", x"67", x"E7", x"E2", x"E1", x"BE",
        -- Bytes 24..31
        x"1B", x"80", x"91", x"B3", x"6F", x"41", x"06", x"11",
        -- Bytes 32..39
        x"DF", x"BE", x"4F", x"C9", x"3A", x"61", x"FE", x"88",
        -- Bytes 40..45 (último byte = ED)
        x"31", x"97", x"14", x"7A", x"A2", x"ED"
    );

    signal data_in  : std_logic_vector(M_VAL downto 0) := (others => '0');
    signal data_out : std_logic_vector(REP_VAL * (2**M_VAL) - 1 downto 0);
    signal byte_idx : integer := 0;

begin
    UUT: entity work.RMEncoder
        generic map (
            m                   => M_VAL,
            rep                 => REP_VAL,
            generator_matrix_01 => GEN_MAT_01
        )
        port map (
            data_in  => data_in,
            data_out => data_out
        );

    STIM_AND_CHECK : process
        variable l : line;
        variable rep0, rep1, rep2 : std_logic_vector(2**M_VAL - 1 downto 0);
    begin
        -- Espera inicial de estabilización
        wait for STEP_PERIOD;

        for i in 0 to NUM_BYTES - 1 loop
            byte_idx <= i;
            data_in  <= INPUT_WORDS(i);

            -- Tiempo de propagación combinacional
            wait for STEP_PERIOD;

            -- Extrae las 3 copias de 128 bits generadas en data_out
            rep0 := data_out(127 downto 0);
            rep1 := data_out(255 downto 128);
            rep2 := data_out(383 downto 256);

            -- Verifica que las 3 repeticiones sean idénticas
            assert (rep0 = rep1) and (rep1 = rep2)
                report "Error de repetición en el byte índice " & integer'image(i)
                severity error;

            -- Imprime en consola de Questa el byte de entrada y el bloque codificado (128 bits en hex)
            write(l, string'("Byte["));
            write(l, i);
            write(l, string'("] data_in = 0x"));
            hwrite(l, data_in);
            write(l, string'(" -> RM(1,7) [128b] = 0x"));
            hwrite(l, rep0);
            writeline(output, l);
        end loop;

        report "Codificación Reed-Muller completada para los 46 bytes (17,664 bits totales generados)." severity note;
        wait;
    end process;

end behavioral;