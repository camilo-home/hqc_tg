-- Testbench de keccak_sponge. Vectores esperados generados con hashlib (Python).
-- Mensaje de prueba: byte i = (7*i + 3) mod 256. Los bytes no validos de la ultima palabra
-- se rellenan con 0xA5 a proposito (el modulo debe ignorarlos).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.keccak_sponge_pkg.all;

entity tb_keccak_sponge is
end tb_keccak_sponge;

architecture sim of tb_keccak_sponge is

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '1';
  signal in_valid  : std_logic := '0';
  signal in_ready  : std_logic;
  signal in_data   : std_logic_vector(63 downto 0) := (others => '0');
  signal out_valid : std_logic;
  signal out_ready : std_logic := '0';
  signal out_data  : std_logic_vector(63 downto 0);
  signal out_last  : std_logic;
  signal errors    : integer := 0;

  constant EXP0 : std_logic_vector(255 downto 0) :=
    x"a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a";
  constant EXP1 : std_logic_vector(255 downto 0) :=
    x"46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f";
  constant EXP2 : std_logic_vector(255 downto 0) :=
    x"fffadd0ae913c0947143ac7c6bf1d512c1b265db8ac52100614bd022ae2412d4";
  constant EXP3 : std_logic_vector(1199 downto 0) :=
    x"3c983983487bcbe74feba53b35bb1e05812379cb4116d9761f78d2ce3177866edc88e750bfaf43bd31ccd052078d97406fbfca21145c09c8d9bd1e81cd443e31aa69827bf0f1d9fddf4b028252de8dbfae953870c3b10347251986b7b49b2406d3e625526d331a8ac1b4d02976893c1fd0837dbc3327f2ecb90ddf5b4990faba3d1c6fa76502b431aa5c71daf885783a279b9a1c88a7";
  constant EXP4 : std_logic_vector(511 downto 0) :=
    x"2ec0da5ff440c192d33033c4257eb39dcbd27edd7e41b5ac8db9daf13db501a2ef938151aaddd82f600335654f77512cbcc926ec5abb05b79282ec716d685618";
  constant EXP5 : std_logic_vector(1599 downto 0) :=
    x"d4f73f3b6c4b72d05f45ed1f80b5774409f9cf336fc202bffa42ac38a6d3fbee3d8bdcebc4fbd562270c9d829abb2fd1e0900e3d5e634d4a00d90cb3479128f21f380a7702704e0b74259af6cb5aea9c58c191792f847c801e4a282d2d3f37fd2bd9d4167854d54ae5bdf88a79ea0d15271a4d5dccd1b1572631d1077184a97fef7589e2f8cf6b75b503429287ec4a009f4e2476140ec81b67a033366f10294be1e2a8ecef7a52c1b11bd950157da4015f798dd682d12dcf9a15429f59f8157a224225da82355b65";
  constant EXP6 : std_logic_vector(511 downto 0) :=
    x"e64be7a667154120b00851e8ce8225ea53fc2d65f8e0540ad85d1b0f3c9fe790a8e28418988482f72a639c84ff1d492eab4be88b10f11e4cfa28b6682788a76d";

begin

  clk <= not clk after 5 ns;

  dut : entity work.keccak_sponge
    generic map (BIG_ENDIAN_WORDS => false)
    port map (
      clk => clk, rst => rst,
      in_valid => in_valid, in_ready => in_ready, in_data => in_data,
      out_valid => out_valid, out_ready => out_ready,
      out_data => out_data, out_last => out_last);

  stim : process

    procedure send_word(w : std_logic_vector(63 downto 0)) is
    begin
      in_valid <= '1';
      in_data  <= w;
      wait until rising_edge(clk) and in_ready = '1';
      in_valid <= '0';
    end procedure;

    function msg_byte(i : natural) return std_logic_vector is
    begin
      return std_logic_vector(to_unsigned((i * 7 + 3) mod 256, 8));
    end function;

    procedure run_case(mode    : std_logic_vector(1 downto 0);
                       msg_len : natural;
                       out_len : natural;
                       expected: std_logic_vector;
                       name    : string) is
      variable w     : std_logic_vector(63 downto 0);
      variable idx   : natural;
      variable n_out : natural;
      variable eb    : std_logic_vector(7 downto 0);
      variable local_err : integer := 0;
    begin
      n_out := expected'length / 8;
      -- palabra de comando
      send_word(make_cmd(mode, msg_len, out_len));
      -- mensaje
      for k in 0 to (msg_len + 7) / 8 - 1 loop
        w := (others => '0');
        for b in 0 to 7 loop
          idx := 8 * k + b;
          if idx < msg_len then
            w(8 * b + 7 downto 8 * b) := msg_byte(idx);
          else
            w(8 * b + 7 downto 8 * b) := x"A5";
          end if;
        end loop;
        send_word(w);
      end loop;
      -- salida (con contrapresion: out_ready baja 2 ciclos cada 3 palabras)
      for k in 0 to (n_out + 7) / 8 - 1 loop
        if k mod 3 = 2 then
          out_ready <= '0';
          wait until rising_edge(clk);
          wait until rising_edge(clk);
        end if;
        out_ready <= '1';
        wait until rising_edge(clk) and out_valid = '1';
        for b in 0 to 7 loop
          idx := 8 * k + b;
          if idx < n_out then
            eb := expected(expected'left - 8 * idx downto expected'left - 8 * idx - 7);
            if out_data(8 * b + 7 downto 8 * b) /= eb then
              local_err := local_err + 1;
            end if;
          end if;
        end loop;
        if (k = (n_out + 7) / 8 - 1) /= (out_last = '1') then
          local_err := local_err + 1;
        end if;
      end loop;
      out_ready <= '0';
      if local_err = 0 then
        report "OK    : " & name severity note;
      else
        report "FALLO : " & name severity error;
      end if;
      errors <= errors + local_err;
      wait until rising_edge(clk);
    end procedure;

  begin
    wait for 22 ns;
    rst <= '0';
    wait until rising_edge(clk);
    run_case(MODE_SHA3_256, 0, 0, EXP0, "SHA3-256 msg=0");
    run_case(MODE_SHAKE256, 0, 32, EXP1, "SHAKE256 msg=0 out=32");
    run_case(MODE_SHA3_256, 3, 0, EXP2, "SHA3-256 msg=3");
    run_case(MODE_SHAKE256, 137, 150, EXP3, "SHAKE256 msg=137 out=150");
    run_case(MODE_SHA3_512, 72, 0, EXP4, "SHA3-512 msg=72 (= rate)");
    run_case(MODE_SHAKE128, 168, 200, EXP5, "SHAKE128 msg=168 (= rate) out=200");
    run_case(MODE_SHAKE256, 40, 64, EXP6, "SHAKE256 msg=40 out=64");

    wait for 50 ns;
    report "Fin de la simulacion" severity note;
    wait;
  end process;

end sim;
