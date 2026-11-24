-- ============================================================================
-- poly_mul2 : producto disperso x denso en F2[x]/(x^N - 1), canalizado, palabras de 64 bits,
--             DOS productos a la vez con el mismo disperso (r2*h y r2*s), o uno solo (DUAL=false).
--
--   resA = sparse * denseA      resB = sparse * denseB      (bits >= N a 0)
--
-- ESTE MODULO NO INSTANCIA MEMORIAS: solo expone su interfaz. Las memorias se instancian en el top:
--   * posiciones        : position_mem (lectura registrada, latencia 1)     -> pos_addr / pos_data
--   * densos A y B      : ram64_sdp, MISMA direccion dense_addr             -> dense_*_data
--   * acumuladores A,B  : ram64_tdp (DEPTH = 2*WORDS = 554), una por canal; ambas se
--                         direccionan igual (acc_addr1/2, acc_we1/2) y solo cambian los datos
--   * resultados A y B  : ram64_sdp, MISMA direccion y we (res_*)
--
-- SIN LIMPIEZA: el acumulador no se pone a cero nunca. Durante la PRIMERA pasada (primera
-- posicion) las palabras que esa posicion cubre se ESCRIBEN sin leer (acc = f) y las 276
-- palabras que no cubre se ponen a cero por el puerto 1, que en esa pasada esta libre.
-- Asi no hay barrido tras reset, ready='1' nada mas salir de reset, y la memoria puede
-- contener basura de la multiplicacion anterior.
--
-- Arquitectura (verificada con un modelo ciclo a ciclo contra hqc128.py:vect_mul, incluido el KAT 0):
--  FASE 1 (por posicion p = 64*off + b): 1 palabra por ciclo, 4 etapas
--     t   : dense_addr = k                       (k = 0..WORDS; k = WORDS es la palabra "0")
--     t+1 : dense_data -> funnel f = (D[k] << b) | (D[k-1] >> (64-b)) ; lectura acc[off+k] (puerto 1)
--     t+2 : accn = (primera pasada ? 0 : acc_dout) xor f
--     t+3 : acc[off+k] <= accn                   (puerto 2)
--     PASS_LEN = WORDS+4 ciclos por posicion (con WORDS+2 falla); la posicion siguiente se
--     lee por adelantado durante la pasada.
--  FASE 2 (pliegue en el bit N, no en limite de palabra; N = 64*FOLD_W + SH):
--     res[j] = L[j] xor ( L[FOLD_W+j] >> SH | L[FOLD_W+1+j] << (64-SH) ),  res[WORDS-1] &= (1<<SH)-1
--     2 lecturas por ciclo (puertos 1 y 2), sin escrituras en el acumulador.
--
-- Latencia start -> done:  n_pos*(WORDS+4) + (WORDS+6)     (HQC-128: n_pos*281 + 283)
--
-- Protocolo: start (pulso de 1 ciclo, solo con ready='1') captura n_pos (>= 1);
--            done = pulso de 1 ciclo, con los resultados ya escritos en las memorias de resultado.
-- Orden de bits: bit i del vector = bit (i mod 64) de la palabra i/64 (igual que sample_vect).
-- Los vectores densos deben tener a 0 los bits >= N (sample_vect ya lo hace).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity poly_mul2 is
  generic(
    N      : integer := 17669;   -- N mod 64 /= 0 (HQC-128/192/256 lo cumplen)
    DUAL   : boolean := true;    -- false: un solo producto (canal B inactivo)
    POS_W  : integer := 15;      -- bits de una posicion
    PA_W   : integer := 7;       -- bits de direccion de position_mem
    AW     : integer := 9;       -- bits de direccion de un vector   (2**AW     >= WORDS)
    ACC_AW : integer := 10       -- bits de direccion del acumulador (2**ACC_AW >= 2*WORDS)
  );
  port(
    clk   : in  std_logic;
    rst   : in  std_logic;

    start : in  std_logic;
    n_pos : in  unsigned(PA_W - 1 downto 0);
    ready : out std_logic;
    done  : out std_logic;

    -- memoria de posiciones (lectura, latencia 1)
    pos_addr : out unsigned(PA_W - 1 downto 0);
    pos_data : in  unsigned(POS_W - 1 downto 0);

    -- memorias densas A y B (lectura, latencia 1, misma direccion)
    dense_addr   : out unsigned(AW - 1 downto 0);
    dense_a_data : in  std_logic_vector(63 downto 0);
    dense_b_data : in  std_logic_vector(63 downto 0);

    -- memorias de acumulador A y B (ram64_tdp): control compartido, datos por canal
    acc_addr1  : out unsigned(ACC_AW - 1 downto 0);   -- puerto 1: lecturas (y puesta a cero inicial)
    acc_we1    : out std_logic;
    acc_din1   : out std_logic_vector(63 downto 0);   -- siempre 0 (conectar a din_1 de ambas RAM)
    acc_addr2  : out unsigned(ACC_AW - 1 downto 0);   -- puerto 2: escrituras (y lectura alta en el pliegue)
    acc_we2    : out std_logic;
    accA_din2  : out std_logic_vector(63 downto 0);
    accB_din2  : out std_logic_vector(63 downto 0);
    accA_dout1 : in  std_logic_vector(63 downto 0);
    accB_dout1 : in  std_logic_vector(63 downto 0);
    accA_dout2 : in  std_logic_vector(63 downto 0);
    accB_dout2 : in  std_logic_vector(63 downto 0);

    -- memorias de resultado A y B (escritura; misma direccion y we)
    res_we     : out std_logic;
    res_addr   : out unsigned(AW - 1 downto 0);
    res_a_data : out std_logic_vector(63 downto 0);
    res_b_data : out std_logic_vector(63 downto 0)
  );
end entity;

architecture rtl of poly_mul2 is

  function make_mask(sh : integer) return std_logic_vector is
    variable r : std_logic_vector(63 downto 0) := (others => '0');
  begin
    for i in 0 to 63 loop
      if i < sh then
        r(i) := '1';
      end if;
    end loop;
    return r;
  end function;

  function nch_of(d : boolean) return integer is
  begin
    if d then return 2; else return 1; end if;
  end function;

  constant WORDS    : integer := (N + 63) / 64;            -- 277
  constant SH       : integer := N mod 64;                 -- 5
  constant FOLD_W   : integer := N / 64;                   -- 276
  constant PASS_LEN : integer := WORDS + 4;                -- ciclos por posicion
  constant ZN       : integer := WORDS - 1;                -- palabras que NO cubre una posicion: 2*WORDS-(WORDS+1)
  constant MASK_LAST: std_logic_vector(63 downto 0) := make_mask(SH);
  constant NCH      : integer := nch_of(DUAL);

  type arr64 is array (0 to NCH - 1) of std_logic_vector(63 downto 0);

  type state_t is (S_IDLE, S_LP0, S_LP1, S_ACC, S_FOLD, S_DONE);
  signal state : state_t := S_IDLE;

  signal pidx : integer range 0 to 2**PA_W - 1 := 0;
  signal npos : integer range 0 to 2**PA_W - 1 := 0;
  signal m    : integer range 0 to PASS_LEN - 1 := 0;
  signal ft   : integer range 0 to WORDS + 2 := 0;

  signal pa    : unsigned(PA_W - 1 downto 0) := (others => '0');
  signal off, off_n : unsigned(ACC_AW - 1 downto 0) := (others => '0');
  signal bsh, bsh_n : integer range 0 to 63 := 0;

  -- primera pasada: puesta a cero de las palabras que la posicion 0 no cubre
  signal fp : std_logic := '0';
  signal za : unsigned(ACC_AW - 1 downto 0) := (others => '0');
  signal zc : integer range 0 to ZN := 0;

  -- canalizacion de la fase 1
  signal v1, first1, last1, fp1 : std_logic := '0';
  signal v2, fp2, v3            : std_logic := '0';
  signal a1, a2, a3             : unsigned(ACC_AW - 1 downto 0) := (others => '0');
  signal prev_r, f1_r, accn_r   : arr64 := (others => (others => '0'));

  -- pliegue
  signal prevb_r, rr_r : arr64 := (others => (others => '0'));
  signal rv : std_logic := '0';
  signal rj : integer range 0 to WORDS - 1 := 0;

  signal dense_d, dout1_d, dout2_d : arr64;

begin

  assert (N mod 64) /= 0 report "poly_mul2: N mod 64 debe ser distinto de 0" severity failure;
  assert 2**AW >= WORDS report "poly_mul2: AW demasiado pequeno" severity failure;
  assert 2**ACC_AW >= 2 * WORDS report "poly_mul2: ACC_AW demasiado pequeno" severity failure;

  ---------------------------------------------------------------------------
  -- Salidas y entradas por canal
  ---------------------------------------------------------------------------
  ready      <= '1' when state = S_IDLE else '0';
  done       <= '1' when state = S_DONE else '0';
  pos_addr   <= pa;
  dense_addr <= to_unsigned(m, AW) when m < WORDS else to_unsigned(WORDS - 1, AW);
  res_we     <= rv;
  res_addr   <= to_unsigned(rj, AW);
  res_a_data <= rr_r(0);
  acc_din1   <= (others => '0');

  dense_d(0) <= dense_a_data;
  dout1_d(0) <= accA_dout1;
  dout2_d(0) <= accA_dout2;

  gen_dual : if DUAL generate
    dense_d(NCH - 1)  <= dense_b_data;
    dout1_d(NCH - 1)  <= accB_dout1;
    dout2_d(NCH - 1)  <= accB_dout2;
    res_b_data        <= rr_r(NCH - 1);
  end generate;
  gen_single : if not DUAL generate
    res_b_data <= (others => '0');
  end generate;

  ---------------------------------------------------------------------------
  -- Control combinacional de los puertos de las memorias de acumulador
  ---------------------------------------------------------------------------
  process(state, fp, zc, za, a1, a3, v3, accn_r, ft)
    variable zv : boolean;
  begin
    acc_we1   <= '0';
    acc_we2   <= '0';
    acc_addr1 <= (others => '0');
    acc_addr2 <= (others => '0');
    accA_din2 <= (others => '0');
    accB_din2 <= (others => '0');

    case state is

      when S_ACC =>
        zv := (fp = '1' and zc < ZN);          -- primera pasada: poner a cero lo no cubierto
        if zv then
          acc_addr1 <= za;
          acc_we1   <= '1';                    -- (acc_din1 = 0)
        else
          acc_addr1 <= a1;                     -- lectura de la etapa 1
        end if;
        acc_addr2 <= a3;                       -- escritura de la etapa 3
        acc_we2   <= v3;
        accA_din2 <= accn_r(0);
        if DUAL then
          accB_din2 <= accn_r(NCH - 1);
        end if;

      when S_FOLD =>                           -- solo lecturas
        if ft >= 1 and ft <= WORDS then        -- puerto 1: palabras bajas 0 .. WORDS-1
          acc_addr1 <= to_unsigned(ft - 1, ACC_AW);
        end if;
        if ft <= WORDS then                    -- puerto 2: palabras altas FOLD_W .. FOLD_W+WORDS
          acc_addr2 <= to_unsigned(FOLD_W + ft, ACC_AW);
        end if;

      when others =>
        null;
    end case;
  end process;

  ---------------------------------------------------------------------------
  -- FSM + camino de datos
  ---------------------------------------------------------------------------
  process(clk)
    variable curw, prevw, hj : unsigned(63 downto 0);
    variable j : integer;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= S_IDLE;
        m  <= 0;
        ft <= 0;
        v1 <= '0'; v2 <= '0'; v3 <= '0';
        first1 <= '0'; last1 <= '0';
        fp <= '0'; fp1 <= '0'; fp2 <= '0';
        rv   <= '0';
        pidx <= 0;
        pa   <= (others => '0');

      else
        case state is

          -------------------------------------------------------------------
          when S_IDLE =>
            rv <= '0';
            if start = '1' then
              npos  <= to_integer(n_pos);
              pidx  <= 0;
              pa    <= (others => '0');
              v1 <= '0'; v2 <= '0'; v3 <= '0';
              state <= S_LP0;
            end if;

          when S_LP0 =>                           -- pos_addr = 0 presentada
            state <= S_LP1;

          when S_LP1 =>                           -- pos_data = posicion 0
            off <= resize(pos_data(POS_W - 1 downto 6), ACC_AW);
            bsh <= to_integer(pos_data(5 downto 0));
            m   <= 0;
            pa  <= to_unsigned(1, PA_W);          -- adelantar la posicion 1
            fp  <= '1';                           -- primera pasada: inicializa el acumulador
            zc  <= 0;
            if pos_data(POS_W - 1 downto 6) /= 0 then
              za <= (others => '0');              -- palabras sin cubrir: 0 .. off-1, off+WORDS+1 .. 2*WORDS-1
            else
              za <= to_unsigned(WORDS + 1, ACC_AW);
            end if;
            state <= S_ACC;

          -------------------------------------------------------------------
          -- Fase 1: una palabra por ciclo
          -------------------------------------------------------------------
          when S_ACC =>
            -- etapa 0: emision (dense_addr sale de m; la direccion del acumulador se registra)
            if m <= WORDS then
              v1 <= '1';
              a1 <= off + to_unsigned(m, ACC_AW);
            else
              v1 <= '0';
            end if;
            if m = 0 then first1 <= '1'; else first1 <= '0'; end if;
            if m = WORDS then last1 <= '1'; else last1 <= '0'; end if;
            fp1 <= fp;

            -- etapa 1: desplazamiento funnel de la palabra densa
            if v1 = '1' then
              for c in 0 to NCH - 1 loop
                if last1 = '1' then
                  curw := (others => '0');
                else
                  curw := unsigned(dense_d(c));
                end if;
                if first1 = '1' then
                  prevw := (others => '0');
                else
                  prevw := unsigned(prev_r(c));
                end if;
                f1_r(c)   <= std_logic_vector(shift_left(curw, bsh) or shift_right(prevw, 64 - bsh));
                prev_r(c) <= std_logic_vector(curw);
              end loop;
            end if;
            v2  <= v1;
            a2  <= a1;
            fp2 <= fp1;

            -- etapa 2: XOR con el acumulador (primera pasada: el acumulador se ignora)
            for c in 0 to NCH - 1 loop
              if fp2 = '1' then
                accn_r(c) <= f1_r(c);
              else
                accn_r(c) <= dout1_d(c) xor f1_r(c);
              end if;
            end loop;
            v3 <= v2;
            a3 <= a2;
            -- etapa 3: escritura (puerto 2) en el bloque combinacional de arriba

            -- primera pasada: avanzar la puesta a cero (1 palabra por ciclo, saltando lo cubierto)
            if fp = '1' and zc < ZN then
              zc <= zc + 1;
              if za + 1 = off then
                za <= off + to_unsigned(WORDS + 1, ACC_AW);
              else
                za <= za + 1;
              end if;
            end if;

            -- posicion siguiente (adelantada)
            if m = 1 then
              off_n <= resize(pos_data(POS_W - 1 downto 6), ACC_AW);
              bsh_n <= to_integer(pos_data(5 downto 0));
            end if;

            -- fin de pasada
            if m = PASS_LEN - 1 then
              if pidx = npos - 1 then
                state <= S_FOLD;
                ft    <= 0;
              else
                pidx <= pidx + 1;
                off  <= off_n;
                bsh  <= bsh_n;
                m    <= 0;
                pa   <= to_unsigned(pidx + 2, PA_W);
                fp   <= '0';
              end if;
            else
              m <= m + 1;
            end if;

          -------------------------------------------------------------------
          -- Fase 2: pliegue en el bit N (solo lecturas del acumulador)
          -------------------------------------------------------------------
          when S_FOLD =>
            for c in 0 to NCH - 1 loop
              prevb_r(c) <= dout2_d(c);
            end loop;

            rv <= '0';
            if ft >= 2 and ft <= WORDS + 1 then
              j := ft - 2;
              for c in 0 to NCH - 1 loop
                hj := shift_right(unsigned(prevb_r(c)), SH) or
                      shift_left(unsigned(dout2_d(c)), 64 - SH);
                if j = WORDS - 1 then
                  rr_r(c) <= std_logic_vector((unsigned(dout1_d(c)) xor hj) and unsigned(MASK_LAST));
                else
                  rr_r(c) <= std_logic_vector(unsigned(dout1_d(c)) xor hj);
                end if;
              end loop;
              rj <= j;
              rv <= '1';
            end if;

            if ft = WORDS + 2 then
              state <= S_DONE;
            else
              ft <= ft + 1;
            end if;

          -------------------------------------------------------------------
          when S_DONE =>
            state <= S_IDLE;

        end case;
      end if;
    end if;
  end process;

end rtl;
