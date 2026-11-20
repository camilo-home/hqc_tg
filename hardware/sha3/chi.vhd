
library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; 
	
entity chi is
	port
	(
		s: in std_logic_vector(0 to 1600-1);
		sout: out std_logic_vector(0 to 1600-1)		
	);
end chi;

architecture rtl of chi is

type plane is array (0 to 4) of std_logic_vector(0 to 63);
signal pl0: plane;
signal pl1: plane;
signal pl2: plane;
signal pl3: plane;
signal pl4: plane;
signal pl0p: plane;
signal pl1p: plane;
signal pl2p: plane;
signal pl3p: plane;
signal pl4p: plane;

begin

-----------------------------------------------
-- Map s to an state array pl0,pl1,pl2,pl3,pl4
-----------------------------------------------
 
-- pl0 y=0, x=0:4, z=0:63
gen_pl0: 
	for i in 0 to 4 generate
		pl0(i) <= s(i*64 to i*64+63);
	end generate;

-- pl1 y=1, x=0:4, z=0:63
gen_pl1: 
	for i in 0 to 4 generate
		pl1(i) <= s(64*(5+i) to 64*(5+i)+63);
	end generate;	

-- pl2 y=2, x=0:4, z=0:63
gen_pl2: 
	for i in 0 to 4 generate
		pl2(i) <= s(64*(5*2+i) to 64*(5*2+i)+63);
	end generate;
	
-- pl3 y=3, x=0:4, z=0:63
gen_pl3: 
	for i in 0 to 4 generate
		pl3(i) <= s(64*(5*3+i) to 64*(5*3+i)+63);
	end generate;

-- pl4 y=4, x=0:4, z=0:63
gen_pl4: 
	for i in 0 to 4 generate
		pl4(i) <= s(64*(5*4+i) to 64*(5*4+i)+63);
	end generate;	

---------------------------------------------------------------	

gen_chi:
	for i in 0 to 4 generate		
		pl0p(i) <= pl0(i) xor (not(pl0((i+1)rem 5)) and pl0((i+2) rem 5));
		pl1p(i) <= pl1(i) xor (not(pl1((i+1)rem 5)) and pl1((i+2) rem 5));
		pl2p(i) <= pl2(i) xor (not(pl2((i+1)rem 5)) and pl2((i+2) rem 5));
		pl3p(i) <= pl3(i) xor (not(pl3((i+1)rem 5)) and pl3((i+2) rem 5));
		pl4p(i) <= pl4(i) xor (not(pl4((i+1)rem 5)) and pl4((i+2) rem 5));				
	end generate;
				    
-----------------------------------------------------------
-- Map output state array pl0p,pl1p,pl2p,pl3p,pl4p to sout 
-----------------------------------------------------------
 
-- sout 0
gen_sout0: 
	for i in 0 to 4 generate
		sout(i*64 to i*64+63) <= pl0p(i);
	end generate;

-- sout 1
gen_sout1: 
	for i in 0 to 4 generate
		sout(64*(5+i) to 64*(5+i)+63) <= pl1p(i);
	end generate;	

-- sout 2
gen_sout2: 
	for i in 0 to 4 generate
		sout(64*(5*2+i) to 64*(5*2+i)+63) <= pl2p(i);
	end generate;
	
-- sout 3
gen_sout3: 
	for i in 0 to 4 generate
		sout(64*(5*3+i) to 64*(5*3+i)+63) <= pl3p(i);
	end generate;

-- sout 4
gen_sout4: 
	for i in 0 to 4 generate
		sout(64*(5*4+i) to 64*(5*4+i)+63) <= pl4p(i);
	end generate;	
	
end rtl;
