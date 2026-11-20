-- Changelog
-- 13-04-2017 .. 06-11-2026 : version original por mayoria (majority-logic, Reed), con el generic "rep".
-- 19-11-2026 : Reescrito el nucleo de decision. El decodificador por mayoria NO equivale al decodificador de HQC:
--				con el ruido real de HQC-128 (~34 % de bits erroneos en los 384 bits de cada bloque) falla en ~43 % de
--				los simbolos, y el codigo RS de HQC solo corrige 15 de 46 (32 %). La referencia (rm_decode de
--				hqc128.py y del codigo oficial) hace decodificacion ML:
--				  1) s[k] = suma de las rep copias en la posicion k (0..rep)
--				  2) transformada de Hadamard rapida de 2^m puntos, m etapas: s0 = a+b, s1 = a-b, s = s0 & s1
--				  3) s[0] = s[0] - rep*2^(m-1)
--				  4) simbolo = indice del mayor |s[j]| (empate -> indice MENOR); si s[j] > 0, se suma 2^m
--				Mismos generics que la version anterior. Latencia: 2m+2 ciclos (16 para m=7), un bloque por ciclo.
--				No depende de GenericBuffer, ButterflyCell ni MajorityVoter/.
-- 19-11-2026 : Agregado handshake valid/ready (in_valid, in_ready, out_valid, out_ready).
--				Todo el pipeline avanza con un enable global ("advance"): si hay un simbolo valido en la salida
--				y el consumidor no esta listo (out_ready = '0'), el pipeline entero se congela y no se pierde nada.
--				Si la salida esta vacia o se esta consumiendo, avanza y acepta una entrada por ciclo.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief Decodificador ML de RM(1,m) con rep copias (HQC-128: m=7, rep=3).
--!
--! @param m							RM(1,m): salida de m+1 bits, palabra de 2^m bits
--! @param rep							numero de copias de la palabra (HQC-128: 3). data_in tiene rep*2^m bits;
--!										la copia c ocupa data_in((c+1)*2^m-1 downto c*2^m)
--! @param generator_matrix_01			mismo significado que en rm_encoder. HQC usa false (tabla HQC_RM_TAB).
--!										Con true el bit m de la salida se corrige con la paridad de los otros m bits.
--! @param clock						reloj
--! @param reset_n						reset asincrono, activo bajo
--! @param in_valid						'1' = data_in contiene un bloque. Se acepta en el flanco de reloj en que
--!										in_valid = '1' e in_ready = '1'. Mientras in_ready = '0', data_in e in_valid
--!										deben mantenerse estables.
--! @param in_ready						'1' = el decodificador acepta un bloque este ciclo. Depende combinacionalmente
--!										de out_ready (in_ready = not out_valid or out_ready).
--! @param data_in						rep*2^m bits
--! @param out_valid					'1' = data_out contiene un simbolo valido (2m+2 ciclos despues de aceptar el
--!										bloque, si no hubo congelamientos). Se mantiene mientras out_ready = '0'.
--! @param out_ready					'1' = el consumidor toma data_out en este flanco de reloj (out_valid = '1' y
--!										out_ready = '1'). Si no se necesita contrapresion, conectar a '1'.
--! @param data_out						m+1 bits: bit m = a_m (complemento), bits m-1..0 = a_{m-1}..a_0.
--!										Los simbolos salen en el mismo orden en que entraron los bloques.
entity rm_decoder is
	Generic (	m 					: 		natural := 7;
				rep					:		natural := 3;
				generator_matrix_01 : 		boolean := false);
    Port (		clock 				: in	std_logic;
				reset_n 			: in	std_logic;
				in_valid			: in	std_logic;
				in_ready			: out	std_logic;
				data_in 			: in 	std_logic_vector (rep*2**m-1 downto 0);
				out_valid			: out	std_logic;
				out_ready			: in	std_logic;
           		data_out 			: out	std_logic_vector (m downto 0));
end rm_decoder;

architecture Rtl of rm_decoder is

	-- logaritmo en base 2 por exceso
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

	constant n_pts : natural := 2**m;

	-- ancho (con signo) suficiente para |valor| <= rep*2^s, valor de la etapa s de la FHT (s=0: conteo)
	function stage_w (s : natural) return natural is
	begin
		return ceil_log2(rep * 2**s + 1) + 1;
	end function;

	constant w_max : natural := stage_w(m);					-- 10 bits para m=7, rep=3 (|valor| <= 384)
	constant abs_w : natural := ceil_log2(rep * 2**m + 1);	-- 9 bits: |valor| <= 384
	-- entrada del arbol de comparacion: [ idx (m bits) | signo (1 bit) | abs (abs_w bits) ]
	constant ent_w : natural := abs_w + 1 + m;

	-- cuenta los unos de la posicion k en las rep copias
	function count_ones (v : std_logic_vector; k : natural) return natural is
		variable acc : natural := 0;
	begin
		for c in 0 to rep-1 loop
			if v(c*n_pts + k) = '1' then
				acc := acc + 1;
			end if;
		end loop;
		return acc;
	end function;

	-- fht(0) = conteo (combinacional); fht(s), s=1..m = salida registrada de la etapa s
	-- De cada elemento solo se usan los stage_w(s) bits bajos: el resto se elimina en sintesis.
	type fht_row_t is array (0 to n_pts-1) of signed(w_max-1 downto 0);
	type fht_t is array (0 to m) of fht_row_t;
	signal fht : fht_t;

	-- lv(0) = |s[j]| y signo registrados; lv(l), l=1..m = salida del nivel l del arbol de comparacion
	type lvl_row_t is array (0 to n_pts-1) of std_logic_vector(ent_w-1 downto 0);
	type lvl_t is array (0 to m) of lvl_row_t;
	signal lv : lvl_t;

	-- handshake: etapas de pipeline = m (FHT) + 1 (abs) + m (arbol) + 1 (salida)
	constant lat : natural := 2*m + 2;
	-- vld(i) = la etapa i del pipeline (0 = salida de la etapa 1 de la FHT, lat-1 = registro de salida) tiene un bloque valido
	signal vld : std_logic_vector(0 to lat-1);
	-- '1' = el pipeline avanza este ciclo (enable de todos los registros de datos)
	signal advance : std_logic;

begin

	-- ---------------------------------------------------------------
	-- Handshake. El pipeline avanza si la salida esta vacia (o con una burbuja) o si el consumidor la toma.
	-- Los bits de validez viajan en paralelo con los datos y se congelan con el mismo enable.
	-- ---------------------------------------------------------------
	advance   <= (not vld(lat-1)) or out_ready;
	in_ready  <= advance;
	out_valid <= vld(lat-1);

	valid_pipe : process (clock, reset_n)
	begin
		if reset_n = '0' then
			vld <= (others => '0');
		elsif rising_edge(clock) then
			if advance = '1' then
				vld <= in_valid & vld(0 to lat-2);
			end if;
		end if;
	end process;

	-- ---------------------------------------------------------------
	-- Etapa 0: s[k] = numero de copias con un '1' en la posicion k
	-- ---------------------------------------------------------------
	count_gen : for k in 0 to n_pts-1 generate
		fht(0)(k) <= to_signed(count_ones(data_in, k), w_max);
	end generate;

	-- ---------------------------------------------------------------
	-- Etapas 1..m de la transformada rapida de Hadamard (identica a rm_decode):
	--   para p = 0..2^(m-1)-1:  s'[p] = s[2p] + s[2p+1]   ;   s'[2^(m-1)+p] = s[2p] - s[2p+1]
	-- ---------------------------------------------------------------
	fht_stages : for s in 1 to m generate
		process (clock, reset_n)
			variable a, b : signed(stage_w(s)-1 downto 0);
		begin
			if reset_n = '0' then
				for k in 0 to n_pts-1 loop
					fht(s)(k) <= (others => '0');
				end loop;
			elsif rising_edge(clock) and advance = '1' then
				for p in 0 to n_pts/2-1 loop
					a := resize(fht(s-1)(2*p)(stage_w(s-1)-1 downto 0), stage_w(s));
					b := resize(fht(s-1)(2*p+1)(stage_w(s-1)-1 downto 0), stage_w(s));
					fht(s)(p)         <= resize(a + b, w_max);
					fht(s)(n_pts/2+p) <= resize(a - b, w_max);
				end loop;
			end if;
		end process;
	end generate;

	-- ---------------------------------------------------------------
	-- Correccion de s[0], valor absoluto y signo
	--   s[0] = s[0] - rep*2^(m-1)
	--   signo = '1' si s[j] > 0 (estrictamente), como "if z > 0: x += 128" de rm_decode
	-- ---------------------------------------------------------------
	abs_stage : process (clock, reset_n)
		variable v : signed(w_max-1 downto 0);
		variable a : signed(w_max-1 downto 0);
		variable e : std_logic_vector(ent_w-1 downto 0);
	begin
		if reset_n = '0' then
			for j in 0 to n_pts-1 loop
				lv(0)(j) <= (others => '0');
			end loop;
		elsif rising_edge(clock) and advance = '1' then
			for j in 0 to n_pts-1 loop
				v := fht(m)(j);
				if j = 0 then
					v := v - to_signed((n_pts/2)*rep, w_max);
				end if;
				if v < 0 then
					a := -v;
				else
					a := v;
				end if;
				e := (others => '0');
				e(abs_w-1 downto 0) := std_logic_vector(a(abs_w-1 downto 0));
				if v > 0 then
					e(abs_w) := '1';
				end if;
				lv(0)(j) <= e;
			end loop;
		end if;
	end process;

	-- ---------------------------------------------------------------
	-- Arbol de comparacion (argmax de |s[j]|). Se elige el elemento derecho solo si es ESTRICTAMENTE
	-- mayor, por lo que en un empate gana el indice menor (igual que "abs(s[j]) > y" en Python).
	-- El nivel l agrega un bit al indice: bit (l-1) = '1' si gano el derecho.
	-- ---------------------------------------------------------------
	argmax_levels : for l in 1 to m generate
		process (clock, reset_n)
			variable e : std_logic_vector(ent_w-1 downto 0);
		begin
			if reset_n = '0' then
				for q in 0 to n_pts/2**l-1 loop
					lv(l)(q) <= (others => '0');
				end loop;
			elsif rising_edge(clock) and advance = '1' then
				for q in 0 to n_pts/2**l-1 loop
					if unsigned(lv(l-1)(2*q+1)(abs_w-1 downto 0)) > unsigned(lv(l-1)(2*q)(abs_w-1 downto 0)) then
						e := lv(l-1)(2*q+1);
						e(abs_w+l) := '1';
					else
						e := lv(l-1)(2*q);
						e(abs_w+l) := '0';
					end if;
					lv(l)(q) <= e;
				end loop;
			end if;
		end process;
	end generate;

	-- ---------------------------------------------------------------
	-- Salida registrada: { a_m , a_{m-1..0} }
	-- ---------------------------------------------------------------
	output_stage : process (clock, reset_n)
		variable idx : std_logic_vector(m-1 downto 0);
		variable sg  : std_logic;
		variable par : std_logic;
	begin
		if reset_n = '0' then
			data_out <= (others => '0');
		elsif rising_edge(clock) and advance = '1' then
			idx := lv(m)(0)(abs_w+m downto abs_w+1);
			sg  := lv(m)(0)(abs_w);
			if generator_matrix_01 then
				-- con la matriz "01": c = sum d_i*(TAB_i xor 1) xor d_m*1  =>  a_m = d_m xor paridad(d_{m-1..0})
				par := '0';
				for i in 0 to m-1 loop
					par := par xor idx(i);
				end loop;
				sg := sg xor par;
			end if;
			data_out <= sg & idx;
		end if;
	end process;

end Rtl;
