
library IEEE;
use ieee.std_logic_1164.all;
	
entity theta is
	port
	(
		s: in std_logic_vector(0 to 1600-1);
		sout: out std_logic_vector(0 to 1600-1)		
	);
end theta;

architecture rtl of theta is

type plane is array (0 to 4) of std_logic_vector(0 to 63);
signal pl0: plane;
signal pl1: plane;
signal pl2: plane;
signal pl3: plane;
signal pl4: plane;	
signal c,c1,c2,d: plane;
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

-----------------------------
--        c
-----------------------------

gen_c: 
	for i in 0 to 4 generate
		c(i) <= pl0(i) xor pl1(i) xor pl2(i) xor pl3(i) xor pl4(i);
	end generate;

-- c1(x,z) = c[(x-1)mod5,z]

c1(0) <= c(4);

gen_c1: 
	for i in 1 to 4 generate
		c1(i) <= c(i-1);
	end generate;

-- c2(x,z) = c[(x+1),z-1]

gen_c2: 
	for i in 0 to 3 generate
		c2(i)(1 to 63) <= c(i+1)(0 to 62);
		c2(i)(0) <= c(i+1)(63);
	end generate;
	
c2(4)(1 to 63) <= c(0)(0 to 62);
c2(4)(0) <= c(0)(63);

---------------------------
--         d
---------------------------

gen_d: 
	for i in 0 to 4 generate
		d(i) <= c1(i) xor c2(i);
	end generate;

--------------------------
-- Output state array
--------------------------	

gen_pl0p: 
	for i in 0 to 4 generate
		pl0p(i) <= pl0(i) xor d(i);
	end generate;

gen_pl1p: 
	for i in 0 to 4 generate
		pl1p(i) <= pl1(i) xor d(i);
	end generate;
	
gen_pl2p: 
	for i in 0 to 4 generate
		pl2p(i) <= pl2(i) xor d(i);
	end generate;	

gen_pl3p: 
	for i in 0 to 4 generate
		pl3p(i) <= pl3(i) xor d(i);
	end generate;
	
gen_pl4p: 
	for i in 0 to 4 generate
		pl4p(i) <= pl4(i) xor d(i);
	end generate;	

-----------------------------------------------
-- Map output state array pl0p,pl1p,pl2p,pl3p,pl4p to sout 
-----------------------------------------------
 
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
