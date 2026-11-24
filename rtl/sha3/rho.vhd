
library IEEE;
use ieee.std_logic_1164.all;
	
entity rho is
	port
	(
		s: in std_logic_vector(0 to 1600-1);
		sout: out std_logic_vector(0 to 1600-1)		
	);
end rho;

architecture rtl of rho is

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
pl0p(0) <= pl0(0);	

gen_x: 
	for i in 0 to 4 generate
			gen_y: 
				for j in 0 to 4 generate
				---------------------------------------------------	
					y2: 	
						if j=2 generate
						
						x3: 
							if i=3 generate					
								pl2p(i)(0 to 24) <= pl2(i)(39 to 63);
								pl2p(i)(25 to 63) <= pl2(i)(0 to 38);
							end generate;						
						
						x4: 
							if i=4 generate					
								pl2p(i)(0 to 38) <= pl2(i)(25 to 63);
								pl2p(i)(39 to 63) <= pl2(i)(0 to 24);
							end generate;
							
						x0: 
							if i=0 generate					
								pl2p(i)(0 to 2) <= pl2(i)(61 to 63);
								pl2p(i)(3 to 63) <= pl2(i)(0 to 60);
							end generate;
						
						x1: 
							if i=1 generate					
								pl2p(i)(0 to 9) <= pl2(i)(54 to 63);
								pl2p(i)(10 to 63) <= pl2(i)(0 to 53);
							end generate;
						
						x2: 
							if i=2 generate					
								pl2p(i)(0 to 42) <= pl2(i)(21 to 63);
								pl2p(i)(43 to 63) <= pl2(i)(0 to 20);
							end generate;							
							
						end generate;	
				     ------------------------------------------------
					  y1: 	
						if j=1 generate
						
						x3: 
							if i=3 generate					
								pl1p(i)(0 to 54) <= pl1(i)(9 to 63);
								pl1p(i)(55 to 63) <= pl1(i)(0 to 8);
							end generate;						
						
						x4: 
							if i=4 generate					
								pl1p(i)(0 to 19) <= pl1(i)(44 to 63);
								pl1p(i)(20 to 63) <= pl1(i)(0 to 43);
							end generate;
							
						x0: 
							if i=0 generate					
								pl1p(i)(0 to 35) <= pl1(i)(28 to 63);
								pl1p(i)(36 to 63) <= pl1(i)(0 to 27);
							end generate;
						
						x1: 
							if i=1 generate					
								pl1p(i)(0 to 43) <= pl1(i)(20 to 63);
								pl1p(i)(44 to 63) <= pl1(i)(0 to 19);
							end generate;
						
						x2: 
							if i=2 generate					
								pl1p(i)(0 to 5) <= pl1(i)(58 to 63);
								pl1p(i)(6 to 63) <= pl1(i)(0 to 57);
							end generate;							
							
						end generate;	
				     ------------------------------------------------					  
					  y0: 	
						if j=0 generate
						
						x3: 
							if i=3 generate					
								pl0p(i)(0 to 27) <= pl0(i)(36 to 63);
								pl0p(i)(28 to 63) <= pl0(i)(0 to 35);
							end generate;						
						
						x4: 
							if i=4 generate					
								pl0p(i)(0 to 26) <= pl0(i)(37 to 63);
								pl0p(i)(27 to 63) <= pl0(i)(0 to 36);
							end generate;						
						
						x1: 
							if i=1 generate					
								pl0p(i)(0) <= pl0(i)(63);
								pl0p(i)(1 to 63) <= pl0(i)(0 to 62);
							end generate;
						
						x2: 
							if i=2 generate					
								pl0p(i)(0 to 61) <= pl0(i)(2 to 63);
								pl0p(i)(62 to 63) <= pl0(i)(0 to 1);
							end generate;							
							
						end generate;				     
					  ------------------------------------------------
					  y4: 	
						if j=4 generate
						
						x3: 
							if i=3 generate					
								pl4p(i)(0 to 55) <= pl4(i)(8 to 63);
								pl4p(i)(56 to 63) <= pl4(i)(0 to 7);
							end generate;						
						
						x4: 
							if i=4 generate					
								pl4p(i)(0 to 13) <= pl4(i)(50 to 63);
								pl4p(i)(14 to 63) <= pl4(i)(0 to 49);
							end generate;
							
						x0: 
							if i=0 generate					
								pl4p(i)(0 to 17) <= pl4(i)(46 to 63);
								pl4p(i)(18 to 63) <= pl4(i)(0 to 45);
							end generate;
						
						x1: 
							if i=1 generate					
								pl4p(i)(0 to 1) <= pl4(i)(62 to 63);
								pl4p(i)(2 to 63) <= pl4(i)(0 to 61);
							end generate;
						
						x2: 
							if i=2 generate					
								pl4p(i)(0 to 60) <= pl4(i)(3 to 63);
								pl4p(i)(61 to 63) <= pl4(i)(0 to 2);
							end generate;							
							
						end generate;	
				     ------------------------------------------------
					  y3: 	
						if j=3 generate
						
						x3: 
							if i=3 generate					
								pl3p(i)(0 to 20) <= pl3(i)(43 to 63);
								pl3p(i)(21 to 63) <= pl3(i)(0 to 42);
							end generate;						
						
						x4: 
							if i=4 generate					
								pl3p(i)(0 to 7) <= pl3(i)(56 to 63);
								pl3p(i)(8 to 63) <= pl3(i)(0 to 55);
							end generate;
							
						x0: 
							if i=0 generate					
								pl3p(i)(0 to 40) <= pl3(i)(23 to 63);
								pl3p(i)(41 to 63) <= pl3(i)(0 to 22);
							end generate;
						
						x1: 
							if i=1 generate					
								pl3p(i)(0 to 44) <= pl3(i)(19 to 63);
								pl3p(i)(45 to 63) <= pl3(i)(0 to 18);
							end generate;
						
						x2: 
							if i=2 generate					
								pl3p(i)(0 to 14) <= pl3(i)(49 to 63);
								pl3p(i)(15 to 63) <= pl3(i)(0 to 48);
							end generate;							
							
						end generate;	
				     ------------------------------------------------
				end generate;
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
