--! @author	Salvatore Barone <salvator.barone@studenti.unina.it>
--!			Alfonso Di Martino <alf.dimartino@studenti.unina.it>
--!			Pietro Liguori <pi.liguori@studenti.unina.it>
--! @date 13-04-2017
--! @file RMDecoder.vhd - implementazione VHDL del decodificatore a maggioranza utilizzabile per la decodifica dei codici di
--! Reed-Muller RM(1, m).
--! @copyright
--! This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as
--! published by the Free Software Foundation; either version 3 of the License, or any later version.
--! This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
--! of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
--! You should have received a copy of the GNU General Public License along with this program; if not, write to the Free
--! Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

--! @addtogroup RMDecoder
--! @{

-- Changelog
-- 13-04-2017 : File creation and first implementation
-- 02-05-2017 : Semplificazione generale del codice, volta ad abbassare il numero di dipendenze
--				- il componente Generic2to1Mux e' stato sostituito con l'equivalente codice VHDL, inserito in questo file
--				- l'array di componenti ParityCheck e' stato sostituito con una xor tra i vettori std_logic_vector che
--				  compongono la matrice attraverso la quale viene calcolato il bit piu' significativo dell'output
-- 03-05-2017 : Modifiche volte all'aumento della funzionalita' del componente:
--				- sono stati introdotti due buffer, uno per la bufferizzazione dei dati in ingresso, uno per la bufferizzazione
--				  dei dati in uscita;
--				- l'introduzione dei buffer ha reso necessaria l'aggiunta delle porte per il segnale di clock ed il segnale di
--				  reset (attivo basso);
--				- il buffer di ingresso viene pilotato direttamente dal segnale di "go", mentre quello di uscita e' aggiornato
--				  attraverso un divisore di frequenza, automaticamente, ogni clock_cycle_delay fronti di salita del clock.
-- 06-05-2017 : Implementazione fully-pipelined
--				- rimosso il componente Timing unit, l'ingresso "go" ed il parametro "clock_cycle_delay"
--				- i majority-voter sono fully-pipelined
--				- gli stadi totali della pipeline sono 2(m-3)+1
-- 08-05-2017 : Rimosso buffer in ingresso
-- 09-05-2017 : Correzione di bug su struttura della pipe: il segnale data_in ed il majority non attraversavano tutti gli stadi
--				della pipe,	divenendo causa di possibili problemi di tempificazione.
-- 				- il numero di stadi di pipe attraversati dal segnale data_in deve coincidere con il numero di stadi di pipe dei
--				  majority voter in voter_array, cioe' m-3, perche' data_in verra' riusato per la decidifica del bit piu'
--				  significativo
-- 				- il numero di stadi di pipe attraversati dal segnale majority deve coincidere con il numero di stadi di pipe
--				  dei majority voter am_voter, cioe' m-2, in modo che i due segnali siano temporalmente accoppiati
--				- il numero di stadi della pipe è m-3 + m-2 +1 = 2m-4, il che vuol dire latenza pari a 2m-4 cicli di clock

-- 06-11-2026 : Aggiunto il generic "rep" (molteplicita', 3 per HQC-128).
--				- data_in ha rep*2^m bit: rep copie (eventualmente rumorose) della stessa parola RM(1,m)
--				- ogni copia attraversa la propria rete di butterfly; per il coefficiente a_i i voti (coppie xor)
--				  delle rep copie vengono concatenati e votati da UN solo majority_voter da rep*2^(m-1) ingressi
--				- per a_m il residuo (data_in xor parte lineare) di tutte le copie viene votato da un voter da rep*2^m ingressi
--				- le latenze dei voter non sono piu' m-3 e m-2 ma L1 = ceil(log2(ceil(rep*2^(m-1)/4))) e
--				  L2 = ceil(log2(ceil(rep*2^m/4))); per rep=1 coincidono con m-3 e m-2. Latenza totale L1+L2+1
--				- con rep=3, m=7: L1=6, L2=7, latenza 14 cicli. Corregge con certezza fino a 95 errori
--				  su 384 bit (distanza minima 192)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief Implementazione VHDL del decodificatore per codici di Reed-Muller(1,m)
--!
--! Tale implementazione fa uso della tecnica con majority-voter ed e' pipelined, con numero di stadi delle pipe variabile in
--! base al particolare codice di Reed-Muller. Il numero totale di stadi della pipe, in funzione di "m", e' 2m-4. Ad esempio,
--! per codici RM(1,7), il numero di stadi della pipe e' 10.
--! Il componente, in questo modo, manifesta, questo si, una latenza di 2m-4 colpi di clock, ma e' potenzialmente in grado di
--! completare una decodifica per colpo di clock.<br>
--! Il seguente esempio istanzia un encoder ed un decoder. L'output dell'encoder viene posto in ingresso al decoder. L'input
--! dell'encoder viene controllato attraverso un VIO. Lo stesso VIO viene usato anche per monitorare l'uscita dell'encoder e
--! l'uscita del decoder, oltre che per controllare il segnale di reset di quest'ultimo.
--!
--! @code
--!		encoder : RMEncoder
--!			Generic map (	m 					=> m,
--!							generator_matrix_01 => generator_matrix_01)
--!			Port map (		data_in 			=> encoder_data_in,
--!							data_out 			=> encoder_data_out);
--!
--!		decoder : RMDecoder
--!			Generic map (	m 					=> m,
--!							generator_matrix_01 => generator_matrix_01)
--!			Port map (		clock 				=> clock,
--!							reset_n 			=> reset_n,
--!							data_in 			=> encoder_data_out,
--!							data_out 			=> decoder_data_out);
--!
--!		vio : vio_0
--!			Port map (	clk 			=> clock,
--!						probe_in0 		=> encoder_data_out,
--!						probe_in1 		=> decoder_data_out,
--!						probe_out0 		=> encoder_data_in,
--!						probe_out1(0) 	=> reset_n);
--! @endcode
--!
--! @warning	I codici devono essere stati ottenuti con una matrice di generazione in forma canonica.
--!				Vedi il parametro generator_matrix_01.
--!
--! @param m[in]					parametro "m" del codice di Reed-Muller; incide sulla dimensione, in bit, dell'input e dell'
--!									output del componente: l'input sara' 2^m bit, mentre l'output m+1 bit.
--!									Oltre che stabilire il particolare codice che e' possibile decifrare, incide sul numero di
--!									stadi della pipe di cui il decoder e' composto. Il numero totale di stadi della pipe, in
--!									funzione di "m", e' 2(m-3)+1. Ad esempio, per codici RM(1,7), il numero di stadi e' 9.
--! @param generator_matrix_01[in]	permette di scegliere la matrice di generazione da usare in fase di decodifica.
--!									Scegliendo generator_matrix_01 => true, verra' usata una matrice<br>
--! 								1111111111111111<br>
--! 								0000000011111111<br>
--! 								0000111100001111<br>
--! 								0011001100110011<br>
--! 								0101010101010101<br>
--!									Se, invece, generator_matrix_01 => false, verra' usata una matrice<br>
--! 								1111111111111111<br>
--! 								1111111100000000<br>
--! 								1111000011110000<br>
--! 								1100110011001100<br>
--! 								1010101010101010
--! @param clock[in]				segnale di clock
--! @param reset_n[in]				segnale di reset asincrono, attivo basso
--! @param data_in[in]				codice di Reed-Muller RM(1, m) da decodificare, di lunghezza 2^{m} bit
--! @param data_out[out]			stringa di bit corrispondente al codice di Reed-Muller RM(1, m) decodificato, di lunghezza
--!									pari ad m bit
--! @test
--!	RM(1,m), m=3<br>
--! <table>
--! <tr><th>data_in</th><th>data_out</th></tr>
--! <tr><td>x"00"</td><td>x"0"</td></tr>
--! <tr><td>x"55"</td><td>x"1"</td></tr>
--! <tr><td>x"33"</td><td>x"2"</td></tr>
--! <tr><td>x"66"</td><td>x"3"</td></tr>
--! <tr><td>x"0f"</td><td>x"4"</td></tr>
--! <tr><td>x"5a"</td><td>x"5"</td></tr>
--! <tr><td>x"3c"</td><td>x"6"</td></tr>
--! <tr><td>x"69"</td><td>x"7"</td></tr>
--! <tr><td>x"ff"</td><td>x"8"</td></tr>
--! <tr><td>x"aa"</td><td>x"9"</td></tr>
--! <tr><td>x"cc"</td><td>x"a"</td></tr>
--! <tr><td>x"99"</td><td>x"b"</td></tr>
--! <tr><td>x"f0"</td><td>x"c"</td></tr>
--! <tr><td>x"a5"</td><td>x"d"</td></tr>
--! <tr><td>x"c3"</td><td>x"e"</td></tr>
--! <tr><td>x"96"</td><td>x"f"</td></tr>
--! </table>
--! RM(1,m), m=4<br>
--! <table>
--! <tr><th>data_in</th><th>data_out</th></tr>
--! <tr><td>x"0000"</td><td>x"00"</td></tr>
--! <tr><td>x"5555"</td><td>x"01"</td></tr>
--! <tr><td>x"3333"</td><td>x"02"</td></tr>
--! <tr><td>x"6666"</td><td>x"03"</td></tr>
--! <tr><td>x"0f0f"</td><td>x"04"</td></tr>
--! <tr><td>x"5a5a"</td><td>x"05"</td></tr>
--! <tr><td>x"3c3c"</td><td>x"06"</td></tr>
--! <tr><td>x"6969"</td><td>x"07"</td></tr>
--! <tr><td>x"00ff"</td><td>x"08"</td></tr>
--! <tr><td>x"55aa"</td><td>x"09"</td></tr>
--! <tr><td>x"33cc"</td><td>x"0a"</td></tr>
--! <tr><td>x"6699"</td><td>x"0b"</td></tr>
--! <tr><td>x"0ff0"</td><td>x"0c"</td></tr>
--! <tr><td>x"5aa5"</td><td>x"0d"</td></tr>
--! <tr><td>x"3cc3"</td><td>x"0e"</td></tr>
--! <tr><td>x"6996"</td><td>x"0f"</td></tr>
--! <tr><td>x"ffff"</td><td>x"10"</td></tr>
--! <tr><td>x"aaaa"</td><td>x"11"</td></tr>
--! <tr><td>x"cccc"</td><td>x"12"</td></tr>
--! <tr><td>x"9999"</td><td>x"13"</td></tr>
--! <tr><td>x"f0f0"</td><td>x"14"</td></tr>
--! <tr><td>x"a5a5"</td><td>x"15"</td></tr>
--! <tr><td>x"c3c3"</td><td>x"16"</td></tr>
--! <tr><td>x"9696"</td><td>x"17"</td></tr>
--! <tr><td>x"ff00"</td><td>x"18"</td></tr>
--! <tr><td>x"aa55"</td><td>x"19"</td></tr>
--! <tr><td>x"cc33"</td><td>x"1a"</td></tr>
--! <tr><td>x"9966"</td><td>x"1b"</td></tr>
--! <tr><td>x"f00f"</td><td>x"1c"</td></tr>
--! <tr><td>x"a55a"</td><td>x"1d"</td></tr>
--! <tr><td>x"c33c"</td><td>x"1e"</td></tr>
--! <tr><td>x"9669"</td><td>x"1f"</td></tr>
--! </table>
--!
entity RMDecoder is
	Generic (	m 					: 		natural := 7;
				rep					:		natural := 3;
				generator_matrix_01 : 		boolean := true);
    Port (		clock 				: in	std_logic;
				reset_n 			: in	std_logic;
				data_in 			: in 	std_logic_vector (rep*2**m-1 downto 0);
           		data_out 			: out	std_logic_vector (m downto 0));
end RMDecoder;

architecture Structural of RMDecoder is

	component GenericBuffer is
		Generic (	width 		:		natural := 8;
					edge		:		std_logic := '1');
		Port (		clock 		: in	std_logic;
					reset_n 	: in	std_logic;
					load 		: in	std_logic;
					data_in 	: in	std_logic_vector(width-1 downto 0);
					data_out	: out	std_logic_vector(width-1 downto 0));
	end component;

	component ButterflyCell is
		Generic (	m 			: 		natural := 3);
	    Port (		data_in 	: in 	std_logic_vector (2**m-1 downto 0);
	           		swapped 	: out 	std_logic_vector (2**m-1 downto 0));
	end component;

	component majority_voter is
		Generic( width : natural := 8);
	    Port (	clk 		: in	std_logic;
				reset_n 	: in	std_logic;
				data_in		: in	std_logic_vector (width-1 downto 0);
	        	majority	: out	std_logic);
	end component;

	-- logaritmo in base 2 per eccesso
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

	-- latenza (in cicli) dei voter dei coefficienti a_0..a_{m-1}: rep*2^(m-1) ingressi
	constant L1 : natural := ceil_log2((rep*2**(m-1) + 3) / 4);
	-- latenza (in cicli) del voter di a_m: rep*2^m ingressi
	constant L2 : natural := ceil_log2((rep*2**m + 3) / 4);

	-- tipi matrice usati nel seguito
	-- matrix1: una copia (2^m bit); matrix2: voti di una copia (2^(m-1) bit); matrix3: m bit
	-- matrix4: voti di tutte le copie (rep*2^(m-1) bit); matrix5: tutte le copie (rep*2^m bit)
	type std_logic_matrix1 is array (natural range <>) of std_logic_vector(2**m-1 downto 0);
	type std_logic_matrix2 is array (natural range <>) of std_logic_vector(2**(m-1)-1 downto 0);
	type std_logic_matrix3 is array (natural range <>) of std_logic_vector(m-1 downto 0);
	type std_logic_matrix4 is array (natural range <>) of std_logic_vector(rep*2**(m-1)-1 downto 0);
	type std_logic_matrix5 is array (natural range <>) of std_logic_vector(rep*2**m-1 downto 0);

	-- matrice di generazione dei codici di Reed-Muller
	signal generation_matrix : std_logic_matrix1(0 to m);

	-- data_in (tutte le copie) attraverso i diversi stadi della pipe: L1 stadi
	signal buffered_data_in : std_logic_matrix5(0 to L1);

	-- le rep copie separate
	signal copies : std_logic_matrix1(0 to rep-1);

	-- swapped_data(c*m + i): copia c, dopo i livelli di butterfly. Riga c*m e' la copia non swappata.
	signal swapped_data : std_logic_matrix1(0 to rep*m-1);

	-- xor delle coppie di segnali di ciascuna riga di swapped_data (stesso indice c*m + i)
	signal coupled_xor : std_logic_matrix2(0 to rep*m-1);

	-- ingresso dei voter: per il coefficiente i, concatenazione dei voti delle rep copie
	signal voter_in : std_logic_matrix4(0 to m-1);

	-- uscite dei MajorityVoter
	signal majority : std_logic_vector (m-1 downto 0) := (others => '0');
	signal majority_m : std_logic := '0';
	-- segnale di ingresso/uscita al blocco majority_pipe_buffer (L2 stadi)
	signal pipe_majority : std_logic_matrix3(0 to L2);

	-- segnale tutti zero, costituisce l'ingresso "data_in0" dei mux usati per il calcolo di am
	constant zero :  std_logic_vector(2**m-1 downto 0) := (others => '0');

	-- riga i : majority(i) and generation_matrix(m-i), per una singola copia
	signal am_matrix : std_logic_matrix1(0 to m-1);
	-- stessa riga replicata rep volte, cosi' si puo' sottrarre (xor) la parte lineare a tutte le copie
	signal am_matrix_rep : std_logic_matrix5(0 to m-1);
	-- residuo di tutte le copie dopo aver tolto via via i termini lineari
	signal am_xored_matrix : std_logic_matrix5(0 to m);

begin

	-- buffer su data_in: il numero di stadi deve coincidere con la latenza dei voter di voter_array (L1),
	-- perche' data_in verra' riusato per la decisione del bit piu' significativo
	buffered_data_in(0) <= data_in;
	data_in_pipes_buffer : for i in 1 to L1 generate
		data_in_buffer :GenericBuffer
			Generic map (	width 		=> rep*2**m,
							edge		=> '1')
			Port map (		clock 		=> clock,
							reset_n 	=> reset_n,
							load 		=> '1',
							data_in 	=> buffered_data_in(i-1),
							data_out	=> buffered_data_in(i));
	end generate;

	-- separazione delle copie
	copy_split : for c in 0 to rep-1 generate
		copies(c) <= data_in((c+1)*2**m-1 downto c*2**m);
	end generate;

	-- rete di butterfly: una per ogni copia (vedi commenti dell'originale: il livello i ha 2^i celle)
	copy_array : for c in 0 to rep-1 generate
		swapped_data(c*m) <= copies(c);
		butterfly_cell_matrix : for i in 0 to m-2 generate
			butterfly_cell_array : for j in 0 to 2**i-1 generate
				cell : ButterflyCell
					Generic map (m => m-i)
					Port map ( 	data_in => swapped_data(c*m+i)(((j+1)*2**(m-i))-1 downto j*(2**(m-i))),
						   		swapped => swapped_data(c*m+i+1)(((j+1)*2**(m-i))-1 downto j*(2**(m-i))));
			end generate;
		end generate;
	end generate;

	-- coupled_xor(c*m+i)(j) = xor dei bit 2j e 2j+1 della riga swapped_data(c*m+i)
	coupled_xor_copy : for c in 0 to rep-1 generate
		coupled_xor_matrix : for i in 0 to m-1 generate
			coupled_xor_array : for j in 0 to 2**(m-1)-1 generate
				coupled_xor(c*m+i)(j) <= swapped_data(c*m+i)(2*j) xor swapped_data(c*m+i)(2*j+1);
			end generate;
			-- i voti della copia c per il coefficiente i vanno nel segmento c del vettore da votare
			voter_in(i)((c+1)*2**(m-1)-1 downto c*2**(m-1)) <= coupled_xor(c*m+i);
		end generate;
	end generate;

	-- generazione dei coefficienti a_0 .. a_{m-1}: un voter per coefficiente, con i voti di TUTTE le copie
	voter_array : for i in 0 to m-1 generate
		voter : majority_voter
			Generic map (	width		=> rep*2**(m-1))
		    Port map ( 		clk			=> clock,
							reset_n		=> reset_n,
							data_in		=> voter_in(i),
							majority	=> majority(i));
	end generate;

	-- buffer per il segnale majority: L2 stadi, la latenza del voter di a_m
	pipe_majority(0) <= majority;
	majority_pipe_buffer : for i in 1 to L2 generate
		pipe_buffer : GenericBuffer
		Generic map (	width 		=> m,
						edge		=> '1')
		Port map (		clock 		=> clock,
						reset_n 	=> reset_n,
						load 		=> '1',
						data_in 	=> pipe_majority(i-1),
						data_out	=> pipe_majority(i));
	end generate;

	-- matrice di generazione (invariata)
	generator_matrix_choice_01 : if generator_matrix_01 = true generate
		generator_matrix_generation : for i in 0 to 2**m-1 generate
			signal_assignment : for j in 0 to m generate
				generation_matrix(j)(2**m-i-1) <=  std_logic(to_unsigned(i+2**m, m+1)(m-j));
			end generate;
		end generate;
	end generate;
	generator_matrix_choice_10 : if generator_matrix_01 = false generate
		generator_matrix_generation : for i in 0 to 2**m-1 generate
			signal_assignment : for j in 0 to m generate
				generation_matrix(j)(i) <=  std_logic(to_unsigned(i+2**m, m+1)(m-j));
			end generate;
		end generate;
	end generate;

	-- generazione di am (il bit piu' significativo)
	-- Si tolgono dal segnale ricevuto (tutte le copie) i termini lineari decisi, riga per riga:
	-- do_i = majority(i) and generation_matrix(m-i), replicato su ogni copia.
	-- Cio' che resta e' am*1...1 piu' errori: lo decide un voter da rep*2^m ingressi.
	am_xored_matrix(0) <= buffered_data_in(L1);
	am_matrix_generation : for i in 0 to m-1 generate
		with majority(i) select
		 	am_matrix(i) <= 	generation_matrix(m-i) when '1',
							zero when others;

		am_replication : for c in 0 to rep-1 generate
			am_matrix_rep(i)((c+1)*2**m-1 downto c*2**m) <= am_matrix(i);
		end generate;

		am_xored_matrix(i+1) <= am_xored_matrix(i) xor am_matrix_rep(i);
	end generate;

	am_voter : majority_voter
		Generic map (	width		=> rep*2**m)
		Port map (		clk			=> clock,
						reset_n		=> reset_n,
						data_in		=> am_xored_matrix(m),
						majority	=> majority_m);

	-- buffer di uscita
	buffer_data_out : GenericBuffer
		Generic map (	width 		=> m+1,
						edge		=> '1')
		Port map (		clock 		=> clock,
						reset_n 	=> reset_n,
						load 		=> '1',
						data_in 	=> majority_m & pipe_majority(L2),
						data_out	=> data_out);
end Structural;

--! @}
