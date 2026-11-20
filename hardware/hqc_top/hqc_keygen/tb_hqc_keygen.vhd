-- Testbench de hqc_keygen con el KAT 0 (seed 9EF877FD...F505).
--   seed_kem = primeros 32 bytes que lee keygen del PRNG de hqc128.py (prng_init(seed) = SHAKE256(seed||00)):
--     CEFC0D60050E04C3171859E54BA888D2F670E22EBE926B0B307A65264FBC08F8
--   Esperado (hqc128.py:keygen): ek = seed_ek || s (2241 B) -> 281 palabras ; dk_extra = seed_dk||sigma||seed_kem
--   -> 10 palabras ; dk = ek || dk_extra (2321 B).  pk[0..15] = 4053237912EA281C51C4456A5096589E
-- El TB entrega la semilla con huecos aleatorios y frena la salida con out_ready intermitente, comprueba
-- todas las palabras, los out_last / out_part, e informa de los ciclos de calculo y de la latencia total.
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_hqc_keygen is
end tb_hqc_keygen;

architecture sim of tb_hqc_keygen is

  constant N0 : integer := 281;
  constant N1 : integer := 10;

  type seed_vec is array (0 to 3)    of std_logic_vector(63 downto 0);
  type w0_vec   is array (0 to N0-1) of std_logic_vector(63 downto 0);
  type w1_vec   is array (0 to N1-1) of std_logic_vector(63 downto 0);

  constant SEEDK : seed_vec := (
    x"c3040e05600dfcce", x"d288a84be5591817", x"0b6b92be2ee270f6", x"f808bc4f26657a30"
  );
  constant EXP0 : w0_vec := (
    x"1c28ea1279235340", x"9e5896506a45c451", x"f9001e651902d2c9", x"aef984cff0784170",
    x"05a1ba0edd026fbf", x"a770377044896e9a", x"e955b2e0f9da9644", x"b98f1bc677b5167a",
    x"052c67dba8113d9f", x"65c554c3704b48af", x"11083c090b0dae18", x"478835d8bf4b13f1",
    x"7664e29a745180f1", x"56fba34c4a302cdd", x"81737640b0cad421", x"3f0bba0baa33449b",
    x"098fefb87215ff9d", x"e5ac46129983cc38", x"bc899f7c53842586", x"dd1ff976e01c3193",
    x"5d5fdfb819c65ab9", x"6f7149e37b6615d4", x"bf28c8e6abaa1ef9", x"aa9fc9f503e452df",
    x"ccace2f3c86fc355", x"3ef38feec07494c3", x"03eb4bc1195ae50e", x"1060a5b45c85141e",
    x"8d7342a08624a4a7", x"3c701f958c35df0f", x"890ba352aa198b48", x"59745d9d636d174c",
    x"883aa79bb59b7b72", x"54c56f4a2d3860e5", x"9b8ff8b80d8ae024", x"8d25064cc99e80f5",
    x"26051904cc25fabd", x"ef10933de346c403", x"99c383c6b8980404", x"bd7b5f26bf9b56c7",
    x"c12ec6dc51857d58", x"73863db796e947f1", x"7f636c03e2fef474", x"cb698abe1bb8b968",
    x"8716fd79a5fcf619", x"de7107b2b49c94ef", x"97ba68ddcc5184eb", x"d2091bbeecdc55ce",
    x"b55432a7775e2615", x"ae0857d089ae2bed", x"d5799f4d6670e198", x"8d5ac68a0001fa93",
    x"4a24c1d637136674", x"5cfed47758754a27", x"633286a0f1b88bb3", x"e5ae82b035f29f09",
    x"5f38064ba57e105a", x"1025d8ed32266656", x"21e3e59987a0559a", x"daf194f2eb2f860e",
    x"cc68d0b887582684", x"d960082bd1281e96", x"bb4f8885d28c4d63", x"27255902b293b681",
    x"69f012c08fa6e6e6", x"41663e6d6585ae47", x"92de0d5ba9bdef40", x"c43e6538eed8025b",
    x"c5350e979981d848", x"83b87cef62d9c6cf", x"ee7fcea55a5048c2", x"940900cd66789fd8",
    x"3f49b8b012eac728", x"f408684ed44a8021", x"353cf3e71c93e027", x"528354c3340399d3",
    x"47af24185e9c3110", x"c85b3c1476736f1d", x"5c3a9b90383d541f", x"008fd44cf9ca90b7",
    x"0d71dbec4ac44e57", x"b65181af83ef6b3e", x"05d70906529d66cd", x"edd446d6e77a59c6",
    x"bfaf9e950e0adbab", x"14a4bfd086413ebb", x"e955a39e1826d939", x"c03fb8b82d0fc686",
    x"636c75ed52058286", x"84ef01e48c957bbb", x"6da5034440e6d6c7", x"03d627d774bbd707",
    x"6091a7ca4234dca4", x"1a40ba2832dffbf5", x"0e5475b6325e3ec2", x"ebc576cd07115c19",
    x"b5e874d5c5b16289", x"ac5a134bd3247e96", x"dccaa6eaf61dcef5", x"834b6821c561f59e",
    x"c1915035bcddb0e5", x"67028fb8ad5259c1", x"1d0708710c4e90a7", x"ae55de1743d91fcd",
    x"a0782f7aec859dbd", x"a4ae6471f0767f0c", x"83d750592d3360fe", x"6b14d1a5350eed8f",
    x"fed89c3bbca2924a", x"56f8bc850a07853f", x"d2f08bb15fa52912", x"8fa01e8a3c0ef4c0",
    x"d1084920b7d4142a", x"8d18620566430533", x"52c1568509f8e625", x"934f8d5f0d9ecbf5",
    x"84f7af46992f7bfe", x"831e6d8fc7499e7b", x"e403eb2393aeaffe", x"5b8a533f9852ad83",
    x"fc78613ad2b9a701", x"287b1eb6ddf88852", x"56051ad74b97554a", x"8ae241232fd7e80a",
    x"4f520572a2d20970", x"d9be552caddbf744", x"bd480b9c4bd5b9e8", x"bbc35e8ce1e1d94b",
    x"b6f7c3c48a7ed61b", x"83811a2e1105721e", x"bb0366d6bf60b7af", x"0799ca47879ecf54",
    x"6598a7251a58a901", x"dc58098bbcc23a3f", x"4b84b0ae92ebdeb3", x"e9f95ca8e9001f1d",
    x"32b157db7fb427c1", x"cd7d30756608f1db", x"50b1483e8cc1e26e", x"754147f6b4e9b19a",
    x"cf5aa16ceaa4503d", x"8964c336a757af1c", x"7cee79361344814f", x"64dda1dff0085428",
    x"fa5ae496a192f582", x"c685db287d55a407", x"653b35d8fde830f0", x"f4e7f2c7b46902d5",
    x"1c655364144463c9", x"2f6705ae44d12bfe", x"43c9de4b806654ee", x"a169818b2f8c518b",
    x"77f36543d06b8816", x"f184e565c45d7790", x"1b045059c89c8ce9", x"de408d1a778e655c",
    x"c4fdc11f4b4fa218", x"a5a62014b9c9fd02", x"c1c79c2a459aca06", x"a5bad549e575b157",
    x"b45ca0e2e914965c", x"5dfdf374e6105621", x"12ee1425ac5bb6ab", x"e56d61b1aac5b00c",
    x"c8482b313f86174b", x"28241ee4545ac026", x"aadc248f28b04f79", x"75d32b4a0445c427",
    x"860761a2b57f017f", x"39fd4716f8e3df70", x"72d7fbb082e0acdd", x"640780747c32c2bb",
    x"842719a6a015d765", x"e3145996ee304ab1", x"aedcc92cc7e08b65", x"d5550dafb83bd196",
    x"db0a86594b70589a", x"c60f98544ac24187", x"1df67346b7fa6223", x"ae432f851ad046a3",
    x"10498108c96a9a5c", x"b25f2a6bc74235ad", x"879fbcc77c28680c", x"3d6e9bcad643fcba",
    x"e5738ed11f68cd90", x"4ff3df2aaf181a69", x"9c6e8dc4a24e4f79", x"747c1d5c12625f31",
    x"a1edee17a7371bc2", x"984f9c5ed7f1f709", x"5c3d37ae61ea97e5", x"a389fb58d2a68b67",
    x"971b93dd04ad0ae1", x"7dc65969a333ccb8", x"f48dd3ca4945d9cb", x"ec8f9f394434e03d",
    x"550306ca9ec5f25a", x"ebf2c074ad27960a", x"3737af5fdec5525d", x"e6b9511ad8a712e5",
    x"0b975c1e093db383", x"264a1e35c6a00ca9", x"ab30c1b02206c38d", x"f0a66b0256a1b267",
    x"bd95585534d17c81", x"e987e41d612c637f", x"5815d64ed6c91d45", x"ed0c400cec9422bb",
    x"8c5659d9d002b5c9", x"9be2ab1671f0f3d7", x"b5937034c04dfb62", x"7647d7bb4b3a47b4",
    x"d1ecc2c08362e4bc", x"f7efb76a8e31603e", x"3ad556adcd640f6e", x"b89774b5887f1e0b",
    x"f145ec497c83e534", x"6d68c3f967ab6c91", x"9fe2880e4a977af7", x"afa9f3743df12f35",
    x"087a4eaae0df4977", x"4aa89a2f166c099b", x"eb62fa6f52c18311", x"fe3ad9fde1cf2237",
    x"ff372fe1e57cef5d", x"235be2e78494921c", x"7212803d63472ab2", x"7139f6b9cfe6a8b8",
    x"94f422e679a665e6", x"510cc85cf46334c8", x"12afad5783003c30", x"6a2cc1e664998a61",
    x"033bf0fb3005cb13", x"3291231d1dfb820f", x"bc99d105539eb666", x"7e28a15c877626b3",
    x"628314a46a97ac1e", x"abd16cbce5cbf9bc", x"93d87211ffa17752", x"83d5e80f05e47c31",
    x"88547c7698d5bf0b", x"ec23440d60195466", x"9deaf1d69cc9a7f5", x"b79f6d9bd4fcdd1f",
    x"5577e2ce73ab4e8c", x"2364de9c520a6ee6", x"3986de60513fc1b4", x"2caaa4f9e3bc25ac",
    x"637567ca74675fcb", x"87182be4ae7bc06f", x"6c1040ff5ed2bb1c", x"6e5126d2396bb69c",
    x"7008841dfd92ec2a", x"db7e5bfb1586dbe2", x"13d57a90791fb88e", x"53de3f944068e020",
    x"13cb406a75faa27f", x"95e78bc9f03904c3", x"2ea329dd0b2835c8", x"16fa4ed5031cbcbb",
    x"69c25cadecc3c41e", x"0df6e8855cccc1c3", x"5ee9a6cd2ab2d349", x"4b5e09a13c57a422",
    x"f6ae116a495e5959", x"96701c9b54544a48", x"8b04c54eafaae297", x"ace527daa1bb6e12",
    x"115cf2b204aac44e", x"7022602e44cf8f45", x"45b23593f13ae0fe", x"eb6b9add5d59b983",
    x"4622615dd8922a64", x"3f5f5600f598a119", x"103ae9d36a2e704d", x"2a3262a70bcc9d7a",
    x"8e41c628218e576d", x"1e00947f16b13387", x"99520a94ff262a21", x"1868b91baae71bd3",
    x"0000000000000007"
  );
  constant EXP1 : w1_vec := (
    x"08fa793fc7104b37", x"d15613f2e41b73d0", x"a5ee0dd1b12e7891", x"7bd9d6b4b3239592",
    x"4cc2ea7c2e5797f3", x"00e8eb22f80950d5", x"c3040e05600dfcce", x"d288a84be5591817",
    x"0b6b92be2ee270f6", x"f808bc4f26657a30"
  );

  signal clk      : std_logic := '0';
  signal finished : boolean := false;
  signal rst      : std_logic := '1';
  signal start    : std_logic := '0';
  signal ready, done : std_logic;

  signal seed_valid : std_logic := '0';
  signal seed_ready : std_logic;
  signal seed_data  : std_logic_vector(63 downto 0) := (others => '0');

  signal out_valid, out_last, out_part : std_logic;
  signal out_ready : std_logic := '0';
  signal out_data  : std_logic_vector(63 downto 0);
  signal cycles    : unsigned(31 downto 0);

  signal got0    : w0_vec := (others => (others => 'U'));
  signal got1    : w1_vec := (others => (others => 'U'));
  signal cnt0, cnt1 : integer := 0;
  signal flags_ok   : boolean := true;

begin

  clkgen : process
  begin
    while not finished loop
      clk <= '0'; wait for 5 ns;
      clk <= '1'; wait for 5 ns;
    end loop;
    wait;
  end process;

  dut : entity work.hqc_keygen
    generic map (
      OVERLAP => true
    )
    port map (
      clk => clk, rst => rst, start => start, ready => ready, done => done,
      seed_valid => seed_valid, seed_ready => seed_ready, seed_data => seed_data,
      out_valid => out_valid, out_ready => out_ready, out_data => out_data,
      out_last => out_last, out_part => out_part, cycles => cycles);

  -- contrapresion aleatoria en la salida (~66 % de ciclos listo)
  ordy : process(clk)
    variable lfsr : unsigned(15 downto 0) := x"BEEF";
  begin
    if rising_edge(clk) then
      lfsr := lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
      if lfsr(0) = '1' or lfsr(5) = '1' then
        out_ready <= '1';
      else
        out_ready <= '0';
      end if;
    end if;
  end process;

  -- captura de cada palabra transferida
  mon : process(clk)
    variable c0, c1 : integer := 0;
  begin
    if rising_edge(clk) then
      if out_valid = '1' and out_ready = '1' then
        if out_part = '0' then
          if c0 < N0 then got0(c0) <= out_data; end if;
          c0 := c0 + 1;
          if (out_last = '1') /= (c0 = N0) then flags_ok <= false; end if;
        else
          if c1 < N1 then got1(c1) <= out_data; end if;
          c1 := c1 + 1;
          if (out_last = '1') /= (c1 = N1) then flags_ok <= false; end if;
        end if;
        cnt0 <= c0;
        cnt1 <= c1;
      end if;
    end if;
  end process;

  stim : process
    variable e : integer := 0;
    variable t0 : time;
    variable lat_total : integer;
    variable lfsr : unsigned(15 downto 0) := x"1D2B";
  begin
    wait for 50 ns;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk) and ready = '1';

    start <= '1';
    wait until rising_edge(clk);
    t0 := now;
    start <= '0';

    -- seed_kem con huecos aleatorios (handshake valid/ready)
    for i in 0 to 3 loop
      lfsr := lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
      if lfsr(0) = '1' then
        wait until rising_edge(clk);
      end if;
      seed_valid <= '1';
      seed_data  <= SEEDK(i);
      wait until rising_edge(clk) and seed_ready = '1';
    end loop;
    seed_valid <= '0';

    wait until rising_edge(clk) and done = '1';
    lat_total := (now - t0) / 10 ns;
    wait until rising_edge(clk);

    for j in 0 to N0-1 loop
      if got0(j) /= EXP0(j) then e := e + 1; end if;
    end loop;
    for j in 0 to N1-1 loop
      if got1(j) /= EXP1(j) then e := e + 1; end if;
    end loop;
    if cnt0 /= N0 or cnt1 /= N1 then
      report "numero de palabras de salida: parte0 = " & integer'image(cnt0) &
             ", parte1 = " & integer'image(cnt1) severity error;
      e := e + 1;
    end if;
    if not flags_ok then
      report "out_last / out_part incorrectos" severity error;
      e := e + 1;
    end if;

    if e = 0 then
      report "OK : KeyGen KAT0 correcto. Ciclos de calculo (start -> s listo) = " & integer'image(to_integer(cycles)) &
             " ; latencia total start -> done = " & integer'image(lat_total) severity note;
    else
      report "FALLO : " & integer'image(e) & " diferencias" severity error;
    end if;
    finished <= true;
    wait;
  end process;

  watchdog : process
  begin
    wait until finished for 20 ms;
    if not finished then
      report "TIMEOUT" severity failure;
    end if;
    wait;
  end process;

end sim;
