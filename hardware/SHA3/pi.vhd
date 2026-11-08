
library IEEE;
use ieee.std_logic_1164.all;
	
entity pi is
	port
	(
		s: in std_logic_vector(0 to 1600-1);
		sout: out std_logic_vector(0 to 1600-1)		
	);
end pi;

architecture rtl of pi is

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

------------------------------------------------

gen_x: 
	for i in 0 to 4 generate
	
		x0: 	
			if i=0 generate				
				gen_0y:
				for j in 0 to 4 generate					
					gen_00:
					if j=0 generate
						pl0p(i) <= pl0(0);
					end generate;
					gen_01:
					if j=1 generate
						pl1p(i) <= pl0(3);
					end generate;
					gen_02:
					if j=2 generate
						pl2p(i) <= pl0(1);
					end generate;
					gen_03:
					if j=3 generate
						pl3p(i) <= pl0(4);
					end generate;
					gen_04:
					if j=4 generate
						pl4p(i) <= pl0(2);
					end generate;					
				end generate;				
			end generate;
			
		x1: 	
			if i=1 generate				
				gen_1y:
				for j in 0 to 4 generate					
					gen_10:
					if j=0 generate
						pl0p(i) <= pl1(1);
					end generate;
					gen_11:
					if j=1 generate
						pl1p(i) <= pl1(4);
					end generate;
					gen_12:
					if j=2 generate
						pl2p(i) <= pl1(2);
					end generate;
					gen_13:
					if j=3 generate
						pl3p(i) <= pl1(0);
					end generate;
					gen_14:
					if j=4 generate
						pl4p(i) <= pl1(3);
					end generate;					
				end generate;				
			end generate;
		
		x2: 	
			if i=2 generate				
				gen_2y:
				for j in 0 to 4 generate					
					gen_20:
					if j=0 generate
						pl0p(i) <= pl2(2);
					end generate;
					gen_21:
					if j=1 generate
						pl1p(i) <= pl2(0);
					end generate;
					gen_22:
					if j=2 generate
						pl2p(i) <= pl2(3);
					end generate;
					gen_23:
					if j=3 generate
						pl3p(i) <= pl2(1);
					end generate;
					gen_24:
					if j=4 generate
						pl4p(i) <= pl2(4);
					end generate;					
				end generate;				
			end generate;
			
		x3: 	
			if i=3 generate				
				gen_3y:
				for j in 0 to 4 generate					
					gen_30:
					if j=0 generate
						pl0p(i) <= pl3(3);
					end generate;
					gen_31:
					if j=1 generate
						pl1p(i) <= pl3(1);
					end generate;
					gen_32:
					if j=2 generate
						pl2p(i) <= pl3(4);
					end generate;
					gen_33:
					if j=3 generate
						pl3p(i) <= pl3(2);
					end generate;
					gen_34:
					if j=4 generate
						pl4p(i) <= pl3(0);
					end generate;					
				end generate;				
			end generate;
		
		x4: 	
			if i=4 generate				
				gen_4y:
				for j in 0 to 4 generate					
					gen_40:
					if j=0 generate
						pl0p(i) <= pl4(4);
					end generate;
					gen_41:
					if j=1 generate
						pl1p(i) <= pl4(2);
					end generate;
					gen_42:
					if j=2 generate
						pl2p(i) <= pl4(0);
					end generate;
					gen_43:
					if j=3 generate
						pl3p(i) <= pl4(3);
					end generate;
					gen_44:
					if j=4 generate
						pl4p(i) <= pl4(1);
					end generate;					
				end generate;				
			end generate;
			
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
