--! @author	Salvatore Barone	<salvator.barone@studenti.unina.it>
--!			Alfonso Di Martino 	<alf.dimartino@studenti.unina.it>
--!			Pietro Liguori 		<pi.liguori@studenti.unina.it>
--! @date 14.04.2017 00:12:12
--! @file majority_voter.vhd
--! @copyright
--! This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as
--! published by the Free Software Foundation; either version 3 of the License, or any later version.
--! This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
--! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--! You should have received a copy of the GNU General Public License along with this program; if not, write to the Free
--! Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

--! @addtogroup MajorityVoter
--! @{

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;

--!	@brief	Implementazione VHDL Structural del majority voter.
--!
--!	@param	width[in]		parametro che determina la dimensione dell'input del componente, width >= 4.
--!							NOVITA': width puo' essere qualsiasi (non solo potenza di 2, es. 3*2^(m-1)). Internamente
--!							il vettore viene completato con zeri fino a 4*2^k >= width: gli zeri non alterano il
--!							conteggio degli uni. La soglia resta width/2 (maggioranza stretta, parita' -> '0').
--!							Latenza = ceil(log2(ceil(width/4))) cicli di clock.
--!
--!	@param	clk[in]			segnale di clock
--!	@param	reset_n[in]		segnale di reset asincrono, attivo basso
--! @param	data_in[in]		stringa di bit di input su cui il componente lavora
--!	@param	majority[out]	bit di uscita :
--!											majority = "0" => nella stringa di input #bit = 1 >= #bit = 0
--!											majority = "1" => nella stringa di input #bit = 1 > #bit = 0
--!


entity majority_voter is
	Generic	(	width 		:	NATURAL := 128);
    Port 	(	clk 		:	in STD_LOGIC;
				reset_n 	:	in STD_LOGIC;
    			data_in 	:	in STD_LOGIC_VECTOR (width-1 downto 0);
           		majority 	:	out STD_LOGIC);
end majority_voter;

architecture Structural of majority_voter is

	component parallel_counter_block
		Generic	(	width 	: NATURAL);
		Port	(	data_in : in STD_LOGIC_VECTOR (width-1 downto 0);
			   		data_out: out STD_LOGIC_VECTOR ((width-(width/4))-1 downto 0));
	end component;

	component generic_adder_pipelined
		Generic (	number_operand 			:	NATURAL;
			  		number_bit_for_operand 	:	NATURAL);
		Port	(	clk 					: 	in STD_LOGIC;
					reset_n 				: 	in STD_LOGIC;
					data_in 				:	in STD_LOGIC_VECTOR ((number_operand * number_bit_for_operand)-1 downto 0);
			   		data_out 				:	out STD_LOGIC_VECTOR ((number_bit_for_operand + natural(log2(real(number_operand))))-1 downto 0));
	end component;

	component generic_comparator
		Generic (	width 		:	NATURAL);
		Port	( 	data_in 	:	in STD_LOGIC_VECTOR (width-1 downto 0);
			   		data_cmp 	:	in STD_LOGIC_VECTOR (width-1 downto 0);
			   		data_out 	:	out STD_LOGIC);
	end component;

	-- logaritmo in base 2 per eccesso, solo interi (evita gli arrotondamenti di math_real)
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

	-- numero di nibble (gruppi da 4 bit), livelli dell'albero di sommatori, larghezza dopo il padding
	constant n_nibble	: natural := (width + 3) / 4;
	constant levels		: natural := ceil_log2(n_nibble);
	constant pad_width	: natural := 4 * 2**levels;
	-- bit del conteggio finale: 3 bit per nibble + un bit per ogni livello di somma
	constant cnt_bits	: natural := 3 + levels;

	-- Segnali di collegamento dei tre moduli di cui il componente e' costituito:
	signal padded_in : std_logic_vector (pad_width-1 downto 0) := (others => '0');
	signal parallel_counter_block_out :  std_logic_vector ((pad_width-(pad_width/4))-1 downto 0) := (others => '0');
	signal generic_adder_out : std_logic_vector (cnt_bits-1 downto 0) := (others => '0');
	signal data_compare_cmp : std_logic_vector (cnt_bits-1 downto 0) := (others => '0');
	signal data_compare_out : std_logic := '0';

begin

	-- Padding: i bit da width a pad_width-1 restano a '0' e non modificano il numero di uni
	padded_in(width-1 downto 0) <= data_in;
	padding : for i in width to pad_width-1 generate
		padded_in(i) <= '0';
	end generate;

	-- Modulo 1: conta gli uni di ogni nibble
	parallel_counter_block_Inst: parallel_counter_block
		Generic Map (	width		=>	pad_width)
		Port Map 	(	data_in 	=> padded_in,
						data_out 	=> parallel_counter_block_out);

	-- Modulo 2: somma pipelined di tutti i conteggi (n_nibble potenza di 2 dopo il padding)
	generic_adder_pipelined_Inst: generic_adder_pipelined
		Generic Map	(	number_operand 			=>	2**levels,
						number_bit_for_operand 	=>	3)
		Port Map 	(	clk						=> 	clk,
						reset_n					=>	reset_n,
						data_in 				=> 	parallel_counter_block_out,
						data_out 				=> 	generic_adder_out);

	-- Modulo 3: majority = 1 se (numero di uni) > width/2, con width = numero REALE di voti
	data_compare_cmp <= std_logic_vector(to_unsigned(width/2, cnt_bits));

	generic_comparator_Inst: generic_comparator
		Generic Map	(	width 		=> cnt_bits)
		Port Map 	(	data_in		=> generic_adder_out,
						data_cmp	=> data_compare_cmp,
						data_out 	=> data_compare_out);

	majority <= data_compare_out;

end Structural;

--! @}
