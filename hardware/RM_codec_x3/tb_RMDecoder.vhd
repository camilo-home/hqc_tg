-- Revision History
-- 03-05-2017 : File creation and first implementation
-- 06-11-2026 : Reescrito: encoder + inyeccion de errores + decoder, con molteplicita' rep=3 (HQC-128).
--              Para cada byte de entrada (0..255) se codifica, se invierten NERR bits y se comprueba que
--              el decoder devuelva el mismo byte. Con NERR <= 95 el test debe pasar siempre.
--              Nota: generator_matrix_01 => false coincide con la tabla HQC_RM_TAB del codigo de referencia.

library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;

entity tb_RMDecoder is
end tb_RMDecoder;

architecture Behavioral of tb_RMDecoder is

	component RMEncoder is
		Generic (	m 					: 		natural := 7;
					rep					:		natural := 3;
					generator_matrix_01 : 		boolean := true);
	    Port (		data_in 			: in 	std_logic_vector (m downto 0);
	           		data_out 			: out 	std_logic_vector (rep*2**m-1 downto 0));
	end component;

	component RMDecoder is
		Generic (	m 					: 		natural := 7;
					rep					:		natural := 3;
					generator_matrix_01 : 		boolean := true);
	    Port (		clock 				: in	std_logic;
					reset_n 			: in	std_logic;
					data_in 			: in 	std_logic_vector (rep*2**m-1 downto 0);
	           		data_out 			: out 	std_logic_vector (m downto 0));
	end component;

	function ceil_log2 (n : natural) return natural is
		variable r : natural := 0;
		variable v : natural := 1;
	begin
		while v < n loop
			v := v * 2;
			r := r + 1;
		end loop;
		return r;
	end function;

	constant m 					: natural := 7;
	constant rep				: natural := 3;
	constant generator_matrix_01: boolean := false;
	constant NERR				: natural := 95;   -- errores inyectados en los 384 bits (cambia a 96+ para ver fallos posibles)
	constant clock_period		: time := 10 ns;
	-- latencia del decoder: L1 + L2 + 1
	constant LAT : natural := ceil_log2((rep*2**(m-1) + 3) / 4) + ceil_log2((rep*2**m + 3) / 4) + 1;

	-- mascara de errores: invierte los bits 0, 4, 8, ... (NERR bits repartidos entre las 3 copias)
	function make_mask return std_logic_vector is
		variable v : std_logic_vector(rep*2**m-1 downto 0) := (others => '0');
	begin
		for k in 0 to NERR-1 loop
			v(4*k) := '1';
		end loop;
		return v;
	end function;
	constant err_mask : std_logic_vector(rep*2**m-1 downto 0) := make_mask;

	signal clock 		: std_logic := '0';
	signal reset_n 		: std_logic := '0';
	signal enc_in 		: std_logic_vector (m downto 0) := (others => '0');
	signal enc_out 		: std_logic_vector (rep*2**m-1 downto 0);
	signal noisy 		: std_logic_vector (rep*2**m-1 downto 0);
	signal dec_out 		: std_logic_vector (m downto 0);

begin

	encoder : RMEncoder
		Generic map (m => m, rep => rep, generator_matrix_01 => generator_matrix_01)
		Port map (data_in => enc_in, data_out => enc_out);

	noisy <= enc_out xor err_mask;

	uut : RMDecoder
		Generic map (m => m, rep => rep, generator_matrix_01 => generator_matrix_01)
		Port map (clock => clock, reset_n => reset_n, data_in => noisy, data_out => dec_out);

	clock_process : process
	begin
		clock <= not clock;
		wait for clock_period / 2;
	end process clock_process;

	stim_process : process
		variable errors : natural := 0;
	begin
		reset_n <= '0', '1' after 5*clock_period;
		wait for 7*clock_period;
		for i in 0 to 2**(m+1)-1 loop
			enc_in <= std_logic_vector(to_unsigned(i, m+1));
			-- se mantiene el dato LAT+3 ciclos para no depender del alineamiento exacto de la pipe
			wait for (LAT+3)*clock_period;
			if dec_out /= std_logic_vector(to_unsigned(i, m+1)) then
				errors := errors + 1;
				report "FALLO: entrada " & integer'image(i) & " salida " &
					integer'image(to_integer(unsigned(dec_out))) severity error;
			end if;
		end loop;
		report "Fin del test, errores = " & integer'image(errors) severity note;
		wait;
	end process stim_process;

end Behavioral;
