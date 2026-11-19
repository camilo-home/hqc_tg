-- tb_rm_encoder.vhd : verifica RMEncoder (HQC-128: m=7, rep=3) contra los valores que imprime la version Python.
--
-- Diferencias respecto al testbench anterior:
--  * Los simbolos se aplican en el orden de Python: indice 0 = byte 0 del codeword RS (0xED), indice 45 = 0x05.
--    (El testbench anterior los aplicaba al reves, 05 ... ED.)
--  * La palabra de 128 bits se imprime en el formato de Python: byte 0 (bits 7..0) PRIMERO. hwrite imprime el bit 127 primero,
--    es decir, los 16 bytes en orden inverso; por eso solo coincidian los simbolos cuyo patron es simetrico por bytes.
--  * Cada simbolo se compara automaticamente con el valor esperado (tomado de hqc128.py) y se verifica que las 3 copias sean iguales.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_rm_encoder is
end tb_rm_encoder;

architecture behavioral of tb_rm_encoder is
    constant M_VAL      : natural := 7;
    constant REP_VAL    : natural := 3;
    constant GEN_MAT_01 : boolean := false;     -- HQC usa false (tabla HQC_RM_TAB)
    constant STEP_PERIOD : time := 10 ns;
    constant NUM_BYTES  : natural := 46;

    type byte_array is array (0 to NUM_BYTES - 1) of std_logic_vector(M_VAL downto 0);
    type word_array is array (0 to NUM_BYTES - 1) of std_logic_vector(2**M_VAL - 1 downto 0);

    -- Codeword RS (Python): EDA27A14973188FE613AC94FBEDF1106416FB391801BBEE1E2E7677430BF74B2D352CF74C934069C9DE74757F505
    -- Indice i = simbolo i del codeword (indice 0 = primer byte, 0xED)
    constant INPUT_WORDS : byte_array := (
		x"ED", x"A2", x"7A", x"14", x"97", x"31", x"88", x"FE",
		x"61", x"3A", x"C9", x"4F", x"BE", x"DF", x"11", x"06",
		x"41", x"6F", x"B3", x"91", x"80", x"1B", x"BE", x"E1",
		x"E2", x"E7", x"67", x"74", x"30", x"BF", x"74", x"B2",
		x"D3", x"52", x"CF", x"74", x"C9", x"34", x"06", x"9C",
		x"9D", x"E7", x"47", x"57", x"F5", x"05"
    );

    -- Palabra RM de 128 bits esperada por simbolo (valor entero; bit 127 a la izquierda)
    constant EXPECTED : word_array := (
		x"5AA55AA5A55AA55AA55AA55A5AA55AA5", x"CCCCCCCC33333333CCCCCCCC33333333",
		x"CC3333CC33CCCC3333CCCC33CC3333CC", x"0F0FF0F00F0FF0F00F0FF0F00F0FF0F0",
		x"96966969969669699696696996966969", x"AAAA55555555AAAAAAAA55555555AAAA",
		x"00FF00FF00FF00FF00FF00FF00FF00FF", x"C33C3CC33CC3C33C3CC3C33CC33C3CC3",
		x"AAAAAAAA5555555555555555AAAAAAAA", x"33CCCC33CC3333CC33CCCC33CC3333CC",
		x"55AA55AA55AA55AAAA55AA55AA55AA55", x"96699669966996696996699669966996",
		x"3CC3C33CC33C3CC33CC3C33CC33C3CC3", x"96696996966969966996966969969669",
		x"5555AAAA5555AAAA5555AAAA5555AAAA", x"3C3C3C3C3C3C3C3C3C3C3C3C3C3C3C3C",
		x"5555555555555555AAAAAAAAAAAAAAAA", x"69966996966996699669966969966996",
		x"99996666666699999999666666669999", x"AAAA5555AAAA5555AAAA5555AAAA5555",
		x"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF", x"66999966669999666699996666999966",
		x"3CC3C33CC33C3CC33CC3C33CC33C3CC3", x"55555555AAAAAAAAAAAAAAAA55555555",
		x"33333333CCCCCCCCCCCCCCCC33333333", x"69696969969696969696969669696969",
		x"96969696696969696969696996969696", x"0F0FF0F0F0F00F0FF0F00F0F0F0FF0F0",
		x"0000FFFFFFFF00000000FFFFFFFF0000", x"96696996699696699669699669969669",
		x"0F0FF0F0F0F00F0FF0F00F0F0F0FF0F0", x"3333CCCCCCCC33333333CCCCCCCC3333",
		x"99996666999966666666999966669999", x"CCCC3333CCCC33333333CCCC3333CCCC",
		x"69966996699669969669966996699669", x"0F0FF0F0F0F00F0FF0F00F0F0F0FF0F0",
		x"55AA55AA55AA55AAAA55AA55AA55AA55", x"F0F00F0F0F0FF0F0F0F00F0F0F0FF0F0",
		x"3C3C3C3C3C3C3C3C3C3C3C3C3C3C3C3C", x"0FF0F00F0FF0F00F0FF0F00F0FF0F00F",
		x"A55A5AA5A55A5AA5A55A5AA5A55A5AA5", x"69696969969696969696969669696969",
		x"69696969696969699696969696969696", x"96966969969669696969969669699696",
		x"5A5AA5A5A5A55A5AA5A55A5A5A5AA5A5", x"5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A"
    );

    signal data_in  : std_logic_vector(M_VAL downto 0) := (others => '0');
    signal data_out : std_logic_vector(REP_VAL * (2**M_VAL) - 1 downto 0);

    function hex_digit (n : natural) return character is
        constant d : string(1 to 16) := "0123456789ABCDEF";
    begin
        return d(n + 1);
    end function;

    function hex_byte (b : std_logic_vector(7 downto 0)) return string is
    begin
        return hex_digit(to_integer(unsigned(b(7 downto 4)))) & hex_digit(to_integer(unsigned(b(3 downto 0))));
    end function;

    -- 128 bits a hex en el formato de Python: to_bytes(16, 'little').hex().upper()  (byte 0 primero)
    function to_py_hex (v : std_logic_vector(127 downto 0)) return string is
        variable s : string(1 to 32);
    begin
        for i in 0 to 15 loop
            s(2*i + 1) := hex_digit(to_integer(unsigned(v(8*i + 7 downto 8*i + 4))));
            s(2*i + 2) := hex_digit(to_integer(unsigned(v(8*i + 3 downto 8*i))));
        end loop;
        return s;
    end function;

begin
    UUT : entity work.RMEncoder
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
        variable rep0, rep1, rep2 : std_logic_vector(2**M_VAL - 1 downto 0);
        variable errors : natural := 0;
    begin
        wait for STEP_PERIOD;

        for i in 0 to NUM_BYTES - 1 loop
            data_in <= INPUT_WORDS(i);
            wait for STEP_PERIOD;

            rep0 := data_out(127 downto 0);
            rep1 := data_out(255 downto 128);
            rep2 := data_out(383 downto 256);

            if not ((rep0 = rep1) and (rep1 = rep2)) then
                errors := errors + 1;
                report "Las 3 repeticiones no son iguales en el simbolo " & integer'image(i) severity error;
            end if;

            if rep0 /= EXPECTED(i) then
                errors := errors + 1;
                report "Simbolo " & integer'image(i) & " distinto del de Python. Obtenido: " & to_py_hex(rep0) &
                       "  Esperado: " & to_py_hex(EXPECTED(i)) severity error;
            end if;

            report "simbolo " & integer'image(i) & "  data_in = 0x" & hex_byte(data_in) &
                   "  RM(1,7) [128b, formato Python] = " & to_py_hex(rep0) severity note;
        end loop;

        if errors = 0 then
            report "OK: los 46 simbolos coinciden con la referencia Python (17664 bits por tres copias)." severity note;
        else
            report "FALLO: " & integer'image(errors) & " errores." severity error;
        end if;
        wait;
    end process;

end behavioral;
