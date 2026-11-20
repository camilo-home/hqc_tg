-- ============================================================================
-- keccak_c : nucleo Keccak-f[1600] con estado interno y puerto de escritura
--            por lane (para absorber de 64 en 64 bits).
--
-- Cambios respecto a la version anterior:
--   * Se elimina la FSM interna y la carga de 1600 bits (state_in). Ahora la
--     logica externa (keccak_sponge) hace XOR de un lane de 64 bits por ciclo.
--   * Entrada "clear" para poner el estado a 0 al empezar un mensaje nuevo
--     (antes solo se limpiaba con rst).
--   * El contador de rondas es un contador sincrono interno (ya no se usa
--     cntir / lpm_counter, y no hay aclr asincrono generado combinacionalmente).
--   * state_out expone los 1600 bits (hacen falta >1088 para SHAKE128).
--
-- Convencion de bits (la misma de theta/rho/pi/chi/iota):
--   state_out(64*n + z) = bit z del lane n (n = x + 5*y), z=0 es el LSB del lane.
--   lane_din(z)         = bit z del lane  (vector "downto": indice = peso del bit).
--
-- Temporizacion: start (1 ciclo) -> busy='1' durante 24 ciclos (1 ronda/ciclo)
--   -> done='1' durante 1 ciclo, con el estado final ya en state_out.
--   clear, lane_we y start NO deben activarse mientras busy='1'.
-- ============================================================================
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity keccak_c is
  port(
    clk       : in  std_logic;
    rst       : in  std_logic;                        -- reset asincrono
    clear     : in  std_logic;                        -- estado <= 0
    lane_we   : in  std_logic;                        -- estado(lane) <= estado(lane) xor lane_din
    lane_sel  : in  std_logic_vector(4 downto 0);     -- 0..24
    lane_din  : in  std_logic_vector(63 downto 0);
    start     : in  std_logic;                        -- lanza Keccak-f[1600]
    busy      : out std_logic;
    done      : out std_logic;                        -- pulso de 1 ciclo
    state_out : out std_logic_vector(0 to 1599)
  );
end keccak_c;

architecture rtl of keccak_c is

  component keccak_p is
    port(
      clk            : in  std_logic;
      round_cnt      : in  std_logic_vector(4 downto 0);
      permutation_in : in  std_logic_vector(0 to 1600-1);
      permutation_out: out std_logic_vector(0 to 1600-1)
    );
  end component;

  signal state_reg  : std_logic_vector(0 to 1599);
  signal state_next : std_logic_vector(0 to 1599);
  signal round_cnt  : std_logic_vector(4 downto 0);
  signal running    : std_logic;
  signal done_r     : std_logic;

begin

  gen_keccak_p : keccak_p
    port map (
      clk             => clk,
      round_cnt       => round_cnt,
      permutation_in  => state_reg,
      permutation_out => state_next
    );

  process(clk, rst)
  begin
    if rst = '1' then
      state_reg <= (others => '0');
      round_cnt <= (others => '0');
      running   <= '0';
      done_r    <= '0';
    elsif rising_edge(clk) then
      done_r <= '0';

      if clear = '1' then
        state_reg <= (others => '0');

      elsif running = '1' then
        state_reg <= state_next;                       -- una ronda por ciclo
        if round_cnt = "10111" then                    -- ronda 23 = ultima
          running   <= '0';
          round_cnt <= (others => '0');
          done_r    <= '1';
        else
          round_cnt <= std_logic_vector(unsigned(round_cnt) + 1);
        end if;

      elsif start = '1' then
        running <= '1';

      elsif lane_we = '1' then
        for l in 0 to 24 loop
          if to_integer(unsigned(lane_sel)) = l then
            -- XOR indice a indice (NO usar "xor" entre slices de distinta direccion)
            for z in 0 to 63 loop
              state_reg(64*l + z) <= state_reg(64*l + z) xor lane_din(z);
            end loop;
          end if;
        end loop;
      end if;
    end if;
  end process;

  busy      <= running;
  done      <= done_r;
  state_out <= state_reg;

end rtl;
