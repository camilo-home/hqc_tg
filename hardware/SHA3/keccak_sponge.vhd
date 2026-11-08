-- ============================================================================
-- keccak_sponge : absorb / padding / squeeze sobre el nucleo keccak_c.
--                 Entrada y salida de 64 bits con handshake valid/ready.
--
-- Protocolo de entrada (in_valid / in_ready / in_data):
--   1) Primera palabra  = COMANDO (ver keccak_sponge_pkg.make_cmd):
--        [1:0]   modo   00 SHAKE128 | 01 SHAKE256 | 10 SHA3-256 | 11 SHA3-512
--        [31:8]  longitud del mensaje en bytes  (puede ser 0)
--        [63:32] longitud de la salida en bytes (solo SHAKE; en SHA3 se ignora)
--   2) ceil(msg_len/8) palabras de mensaje. Los bytes no validos de la ultima
--      palabra se ignoran (pueden valer cualquier cosa).
--
-- Protocolo de salida (out_valid / out_ready / out_data / out_last):
--   ceil(out_len/8) palabras. out_last marca la ultima. En la ultima palabra
--   los bytes sobrantes salen a 0. Al terminar, el modulo vuelve a esperar un
--   comando (in_ready='1'). No se acepta un comando nuevo mientras haya salida
--   pendiente.
--
-- Orden de bits/bytes de las palabras de 64 bits (BIG_ENDIAN_WORDS = false):
--   byte j del flujo -> in_data(8*(j mod 8)+7 downto 8*(j mod 8))   (byte 0 en [7:0])
--   bit k del byte   -> bit k del byte  (LSB = bit 0)
--   => in_data(z) es directamente el bit z del lane de Keccak. Es la misma
--   convencion de la especificacion de Keccak/HQC (bytes en orden de memoria,
--   little-endian). Con BIG_ENDIAN_WORDS = true se intercambian los 8 bytes de
--   cada palabra de DATOS (el comando nunca se intercambia); los bits dentro
--   de cada byte NO se tocan.
--
-- Latencia: 1 permutacion = 26 ciclos aprox. (start + 24 rondas + done).
-- ============================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.keccak_sponge_pkg.all;

entity keccak_sponge is
  generic (
    BIG_ENDIAN_WORDS : boolean := false
  );
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;

    in_valid  : in  std_logic;
    in_ready  : out std_logic;
    in_data   : in  std_logic_vector(63 downto 0);

    out_valid : out std_logic;
    out_ready : in  std_logic;
    out_data  : out std_logic_vector(63 downto 0);
    out_last  : out std_logic
  );
end keccak_sponge;

architecture rtl of keccak_sponge is

  component keccak_c is
    port(
      clk       : in  std_logic;
      rst       : in  std_logic;
      clear     : in  std_logic;
      lane_we   : in  std_logic;
      lane_sel  : in  std_logic_vector(4 downto 0);
      lane_din  : in  std_logic_vector(63 downto 0);
      start     : in  std_logic;
      busy      : out std_logic;
      done      : out std_logic;
      state_out : out std_logic_vector(0 to 1599)
    );
  end component;

  type state_type is (S_CMD, S_ABSORB, S_PAD1, S_PAD2, S_PSTART, S_PWAIT, S_SQUEEZE);
  signal state     : state_type;
  signal ret_state : state_type;       -- a donde volver tras una permutacion

  -- configuracion latcheada del comando
  signal rate_lanes : integer range 0 to 21;
  signal suffix     : std_logic_vector(7 downto 0);
  signal bytes_left : unsigned(23 downto 0);   -- bytes de mensaje por absorber
  signal out_left   : unsigned(31 downto 0);   -- bytes de salida por entregar

  signal lane_idx   : integer range 0 to 24;   -- lane que se escribe / se lee
  signal pad_lane   : integer range 0 to 24;   -- lane donde va el byte de sufijo
  signal pad_off    : integer range 0 to 7;    -- byte dentro de ese lane

  -- hacia el nucleo
  signal c_clear, c_we, c_start, c_busy, c_done : std_logic;
  signal c_sel      : std_logic_vector(4 downto 0);
  signal c_din      : std_logic_vector(63 downto 0);
  signal c_state    : std_logic_vector(0 to 1599);

  signal in_w       : std_logic_vector(63 downto 0);
  signal cur_lane   : std_logic_vector(63 downto 0);
  signal out_w      : std_logic_vector(63 downto 0);

  function bswap(v : std_logic_vector(63 downto 0)) return std_logic_vector is
    variable r : std_logic_vector(63 downto 0);
  begin
    for b in 0 to 7 loop
      r(8*b+7 downto 8*b) := v(8*(7-b)+7 downto 8*(7-b));
    end loop;
    return r;
  end function;

begin

  gen_core : keccak_c
    port map (
      clk       => clk,
      rst       => rst,
      clear     => c_clear,
      lane_we   => c_we,
      lane_sel  => c_sel,
      lane_din  => c_din,
      start     => c_start,
      busy      => c_busy,
      done      => c_done,
      state_out => c_state
    );

  -- conversion de endianness de palabra (solo datos)
  in_w     <= bswap(in_data) when BIG_ENDIAN_WORDS else in_data;
  out_data <= bswap(out_w)   when BIG_ENDIAN_WORDS else out_w;

  in_ready  <= '1' when (state = S_CMD or state = S_ABSORB) else '0';
  out_valid <= '1' when state = S_SQUEEZE else '0';
  out_last  <= '1' when (state = S_SQUEEZE and out_left <= 8) else '0';

  ---------------------------------------------------------------------------
  -- Lectura del lane actual (squeeze) y enmascarado de la ultima palabra
  ---------------------------------------------------------------------------
  process(c_state, lane_idx)
  begin
    cur_lane <= (others => '0');
    for l in 0 to 20 loop
      if lane_idx = l then
        for z in 0 to 63 loop
          cur_lane(z) <= c_state(64*l + z);
        end loop;
      end if;
    end loop;
  end process;

  process(cur_lane, out_left)
    variable w : std_logic_vector(63 downto 0);
  begin
    w := cur_lane;
    if out_left < 8 then
      for b in 0 to 7 loop
        if b >= to_integer(out_left(2 downto 0)) then
          w(8*b+7 downto 8*b) := (others => '0');
        end if;
      end loop;
    end if;
    out_w <= w;
  end process;

  ---------------------------------------------------------------------------
  -- Control combinacional hacia el nucleo
  ---------------------------------------------------------------------------
  process(state, in_valid, in_w, bytes_left, lane_idx, pad_lane, pad_off, suffix, rate_lanes)
    variable nb : integer range 0 to 7;
    variable m  : std_logic_vector(63 downto 0);
  begin
    c_clear <= '0';
    c_we    <= '0';
    c_start <= '0';
    c_sel   <= (others => '0');
    c_din   <= (others => '0');

    case state is

      when S_CMD =>
        if in_valid = '1' then
          c_clear <= '1';                       -- estado a 0 al aceptar el comando
        end if;

      when S_ABSORB =>
        if in_valid = '1' then
          c_we  <= '1';
          c_sel <= std_logic_vector(to_unsigned(lane_idx, 5));
          m := in_w;
          if bytes_left(23 downto 3) = 0 then   -- quedan 1..7 bytes: enmascarar
            nb := to_integer(bytes_left(2 downto 0));
            for b in 0 to 7 loop
              if b >= nb then
                m(8*b+7 downto 8*b) := (others => '0');
              end if;
            end loop;
          end if;
          c_din <= m;
        end if;

      when S_PAD1 =>                            -- byte de sufijo (0x1F / 0x06)
        c_we  <= '1';
        c_sel <= std_logic_vector(to_unsigned(pad_lane, 5));
        c_din <= std_logic_vector(shift_left(resize(unsigned(suffix), 64), 8*pad_off));

      when S_PAD2 =>                            -- bit final 0x80 en el ultimo byte del rate
        c_we  <= '1';
        c_sel <= std_logic_vector(to_unsigned(rate_lanes - 1, 5));
        c_din(63) <= '1';

      when S_PSTART =>
        c_start <= '1';

      when others =>
        null;
    end case;
  end process;

  ---------------------------------------------------------------------------
  -- FSM
  ---------------------------------------------------------------------------
  process(clk, rst)
  begin
    if rst = '1' then
      state      <= S_CMD;
      ret_state  <= S_CMD;
      rate_lanes <= 17;
      suffix     <= x"1F";
      bytes_left <= (others => '0');
      out_left   <= (others => '0');
      lane_idx   <= 0;
      pad_lane   <= 0;
      pad_off    <= 0;

    elsif rising_edge(clk) then
      case state is

        -----------------------------------------------------------------
        when S_CMD =>
          if in_valid = '1' then
            lane_idx   <= 0;
            bytes_left <= unsigned(in_data(31 downto 8));
            out_left   <= unsigned(in_data(63 downto 32));
            if in_data(1 downto 0) = MODE_SHAKE128 then
              rate_lanes <= 21;  suffix <= x"1F";
            elsif in_data(1 downto 0) = MODE_SHAKE256 then
              rate_lanes <= 17;  suffix <= x"1F";
            elsif in_data(1 downto 0) = MODE_SHA3_256 then
              rate_lanes <= 17;  suffix <= x"06";
              out_left   <= to_unsigned(32, 32);
            else
              rate_lanes <= 9;   suffix <= x"06";
              out_left   <= to_unsigned(64, 32);
            end if;

            if unsigned(in_data(31 downto 8)) = 0 then
              pad_lane <= 0;
              pad_off  <= 0;
              state    <= S_PAD1;               -- mensaje vacio
            else
              state    <= S_ABSORB;
            end if;
          end if;

        -----------------------------------------------------------------
        when S_ABSORB =>
          if in_valid = '1' then
            if bytes_left(23 downto 3) /= 0 then          -- palabra completa (>= 8 bytes)
              bytes_left <= bytes_left - 8;
              if lane_idx = rate_lanes - 1 then           -- bloque lleno -> permutar
                lane_idx <= 0;
                state    <= S_PSTART;
                if bytes_left = 8 then                    -- mensaje terminado justo en el limite
                  ret_state <= S_PAD1;
                  pad_lane  <= 0;
                  pad_off   <= 0;
                else
                  ret_state <= S_ABSORB;
                end if;
              else
                lane_idx <= lane_idx + 1;
                if bytes_left = 8 then
                  pad_lane <= lane_idx + 1;
                  pad_off  <= 0;
                  state    <= S_PAD1;
                end if;
              end if;
            else                                          -- ultima palabra parcial (1..7 bytes)
              bytes_left <= (others => '0');
              pad_lane   <= lane_idx;
              pad_off    <= to_integer(bytes_left(2 downto 0));
              state      <= S_PAD1;
            end if;
          end if;

        -----------------------------------------------------------------
        when S_PAD1 =>
          state <= S_PAD2;

        when S_PAD2 =>
          lane_idx <= 0;
          if out_left = 0 then
            state <= S_CMD;                               -- nada que sacar
          else
            ret_state <= S_SQUEEZE;
            state     <= S_PSTART;
          end if;

        -----------------------------------------------------------------
        when S_PSTART =>
          state <= S_PWAIT;

        when S_PWAIT =>
          if c_done = '1' then
            state <= ret_state;
          end if;

        -----------------------------------------------------------------
        when S_SQUEEZE =>
          if out_ready = '1' then
            if out_left <= 8 then
              out_left <= (others => '0');
              state    <= S_CMD;
            else
              out_left <= out_left - 8;
              if lane_idx = rate_lanes - 1 then           -- rate agotado -> otra permutacion
                lane_idx  <= 0;
                ret_state <= S_SQUEEZE;
                state     <= S_PSTART;
              else
                lane_idx <= lane_idx + 1;
              end if;
            end if;
          end if;

      end case;
    end if;
  end process;

end rtl;
