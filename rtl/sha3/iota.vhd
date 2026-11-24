library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity iota is
	port
	(
		s      : in  std_logic_vector(0 to 1599);
		addrct : in  std_logic_vector(4 downto 0);
		sout   : out std_logic_vector(0 to 1599)
	);
end iota;

architecture rtl of iota is

type plane is array (0 to 4) of std_logic_vector(0 to 63);

signal pl0, pl1, pl2, pl3, pl4 : plane;
signal pl0p, pl1p, pl2p, pl3p, pl4p : plane;

signal rc : std_logic_vector(0 to 63);

begin

--==================================================
-- MAP INPUT STATE
--==================================================

-- y = 0
gen_pl0:
for i in 0 to 4 generate
	pl0(i) <= s(i*64 to i*64+63);
end generate;

-- y = 1
gen_pl1:
for i in 0 to 4 generate
	pl1(i) <= s(64*(5+i) to 64*(5+i)+63);
end generate;

-- y = 2
gen_pl2:
for i in 0 to 4 generate
	pl2(i) <= s(64*(10+i) to 64*(10+i)+63);
end generate;

-- y = 3
gen_pl3:
for i in 0 to 4 generate
	pl3(i) <= s(64*(15+i) to 64*(15+i)+63);
end generate;

-- y = 4
gen_pl4:
for i in 0 to 4 generate
	pl4(i) <= s(64*(20+i) to 64*(20+i)+63);
end generate;

--==================================================
-- ROUND CONSTANTS (COMBINATIONAL)
--==================================================

process(addrct)
begin

case addrct is

	when "00000" =>
		rc <= x"8000000000000000";

	when "00001" =>
		rc <= x"4101000000000000";

	when "00010" =>
		rc <= x"5101000000000001";

	when "00011" =>
		rc <= x"0001000100000001";

	when "00100" =>
		rc <= x"D101000000000000";

	when "00101" =>
		rc <= x"8000000100000000";

	when "00110" =>
		rc <= x"8101000100000001";

	when "00111" =>
		rc <= x"9001000000000001";

	when "01000" =>
		rc <= x"5100000000000000";

	when "01001" =>
		rc <= x"1100000000000000";

	when "01010" =>
		rc <= x"9001000100000000";

	when "01011" =>
		rc <= x"5000000100000000";

	when "01100" =>
		rc <= x"D101000100000000";

	when "01101" =>
		rc <= x"D100000000000001";

	when "01110" =>
		rc <= x"9101000000000001";

	when "01111" =>
		rc <= x"C001000000000001";

	when "10000" =>
		rc <= x"4001000000000001";

	when "10001" =>
		rc <= x"0100000000000001";

	when "10010" =>
		rc <= x"5001000000000000";

	when "10011" =>
		rc <= x"5000000100000001";

	when "10100" =>
		rc <= x"8101000100000001";

	when "10101" =>
		rc <= x"0101000000000001";

	when "10110" =>
		rc <= x"8000000100000000";

	when "10111" =>
		rc <= x"1001000100000001";

	when others =>
		rc <= (others => '0');

end case;

end process;

--==================================================
-- IOTA
--==================================================

-- lane (0,0)
pl0p(0) <= pl0(0) xor rc;

-- resto de lanes sin modificar
gen_pl0p:
for i in 1 to 4 generate
	pl0p(i) <= pl0(i);
end generate;

gen_other_planes:
for i in 0 to 4 generate
	pl1p(i) <= pl1(i);
	pl2p(i) <= pl2(i);
	pl3p(i) <= pl3(i);
	pl4p(i) <= pl4(i);
end generate;

--==================================================
-- MAP OUTPUT STATE
--==================================================

-- y = 0
gen_sout0:
for i in 0 to 4 generate
	sout(i*64 to i*64+63) <= pl0p(i);
end generate;

-- y = 1
gen_sout1:
for i in 0 to 4 generate
	sout(64*(5+i) to 64*(5+i)+63) <= pl1p(i);
end generate;

-- y = 2
gen_sout2:
for i in 0 to 4 generate
	sout(64*(10+i) to 64*(10+i)+63) <= pl2p(i);
end generate;

-- y = 3
gen_sout3:
for i in 0 to 4 generate
	sout(64*(15+i) to 64*(15+i)+63) <= pl3p(i);
end generate;

-- y = 4
gen_sout4:
for i in 0 to 4 generate
	sout(64*(20+i) to 64*(20+i)+63) <= pl4p(i);
end generate;

end rtl;