library IEEE;
use ieee.std_logic_1164.all;
	
entity keccak_p is
	port(
			clk: in std_logic;
			round_cnt: in std_logic_vector(4 downto 0); 
			permutation_in: in std_logic_vector(0 to 1600-1);			
			permutation_out: out std_logic_vector(0 to 1600-1) 
		  );
end keccak_p;

architecture rtl of keccak_p is

component theta is
	port
	(
		s: in std_logic_vector(0 to 1600-1);
		sout: out std_logic_vector(0 to 1600-1)		
	);
end component;

component rho is
	port
	(
		s: in std_logic_vector(0 to 1600-1);
		sout: out std_logic_vector(0 to 1600-1)		
	);
end component;

component pi is
	port
	(
		s: in std_logic_vector(0 to 1600-1);
		sout: out std_logic_vector(0 to 1600-1)		
	);
end component;

component chi is
	port
	(
		s: in std_logic_vector(0 to 1600-1);
		sout: out std_logic_vector(0 to 1600-1)		
	);
end component;

component iota is	
	port
	(
		s: in std_logic_vector(0 to 1600-1);
		addrct: in std_logic_vector(4 downto 0);	
		sout: out std_logic_vector(0 to 1600-1)		
	);
end component;

-- Funciones IN/OUT
signal theta_rho: std_logic_vector(0 to 1600-1);
signal rho_pi: std_logic_vector(0 to 1600-1);
signal pi_chi: std_logic_vector(0 to 1600-1);
signal chi_iota: std_logic_vector(0 to 1600-1);
signal iota_in: std_logic_vector(0 to 1600-1);

begin
-----------------------------------------------------
-- Rnd
-----------------------------------------------------

gen_theta: theta 
	port map
	(
		permutation_in,
		theta_rho 		
	);
	
gen_rho: rho 
	port map
	(
		theta_rho,
		rho_pi		
	);

gen_pi: pi 
	port map
	(
		rho_pi,
		pi_chi		
	);	

gen_chi: chi 
	port map
	(
		pi_chi,
		chi_iota	
	);
		
	
gen_iota: iota	
	port map
	(		
		chi_iota,
		round_cnt,
		permutation_out		
	);	
	
end rtl;
