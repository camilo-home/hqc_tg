library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;

entity tb_sparse_xor is
end entity;

architecture sim of tb_sparse_xor is

  constant CLK_PERIOD : time    := 10 ns;
  constant POS_W      : integer := 15;
  constant PA_W       : integer := 7;
  constant AW         : integer := 9;
  constant DEPTH      : integer := 277;
  constant N_POS_VAL  : integer := 66; -- k = 00 .. 65

  type pos_array_t is array (0 to N_POS_VAL - 1) of integer range 0 to 2**POS_W - 1;
  type ram_array_t is array (0 to DEPTH - 1) of std_logic_vector(63 downto 0);

  -- Las 66 posiciones de x (k = 00 .. 65)
  constant X_POS_INIT : pos_array_t := (
     0 =>  8665,  1 => 13884,  2 => 15174,  3 => 13965,  4 =>  8606,  5 => 10571,
     6 => 10263,  7 =>  8439,  8 => 14479,  9 =>   193, 10 => 10264, 11 =>  6288,
    12 => 12375, 13 =>  9022, 14 => 13393, 15 =>  1576, 16 =>  1418, 17 => 16034,
    18 => 12265, 19 =>  3167, 20 => 14020, 21 => 16463, 22 => 14490, 23 => 15563,
    24 =>  6253, 25 => 12059, 26 =>  8013, 27 =>  1554, 28 =>  5264, 29 =>  1035,
    30 =>  8639, 31 =>  6286, 32 => 10041, 33 => 12613, 34 => 11460, 35 => 15762,
    36 => 12894, 37 =>  2047, 38 =>  4075, 39 => 10431, 40 =>  4497, 41 =>   922,
    42 => 16092, 43 => 17352, 44 => 10046, 45 =>  5899, 46 => 13513, 47 =>  7888,
    48 => 11913, 49 =>  9354, 50 => 16231, 51 => 17092, 52 =>  4490, 53 => 11979,
    54 =>  8554, 55 => 15553, 56 => 15967, 57 =>  4035, 58 =>  5666, 59 =>   445,
    60 =>  8795, 61 =>  7837, 62 => 14403, 63 =>  2767, 64 =>   533, 65 => 10126
  );

  -- Vector y*h organizado en 277 palabras de 64 bits en Little Endian
  constant YH_INIT : ram_array_t := (
      0 => x"05A1BA0EDD026FBF",   1 => x"A770377044896E9A",   2 => x"E955B2E0F9DA9644",   3 => x"B98F1BC677B51678",
      4 => x"052C67DBA8113D9F",   5 => x"65C554C3704B48AF",   6 => x"31083C090B0DAE18",   7 => x"478835D8BF4B13F1",
      8 => x"7664E29A747180F1",   9 => x"56FBA34C4A302CDD",  10 => x"81737640B0CAD421",  11 => x"3F0BBA0BAA33449B",
     12 => x"098FEFB87215FF9D",  13 => x"E5AC46129983CC38",  14 => x"BC899F7C57842586",  15 => x"DD1FF976E01C3193",
     16 => x"5D5FDFB819C652B9",  17 => x"6F7149E37B6615D4",  18 => x"BF28C8E6ABAA1EF9",  19 => x"AA9FC9F503E452DF",
     20 => x"CCACE2F3C86FC355",  21 => x"3EF38FEEC07494C3",  22 => x"03EB4BC1195AE10E",  23 => x"1060A5B45C85141E",
     24 => x"8D7343A08620A4A7",  25 => x"3C701F958C35DF0F",  26 => x"890BA352AA198B48",  27 => x"59745D9D636D174C",
     28 => x"883AA79BB59B7B72",  29 => x"54C56F4A2D3860E5",  30 => x"9B8FF8B80D8AE024",  31 => x"0D25064CC99E80F5",
     32 => x"26051904CC25FABD",  33 => x"EF10933DE346C403",  34 => x"99C383C6B8980404",  35 => x"BD7B5F26BF9B56C7",
     36 => x"C12EC6DC51857D58",  37 => x"73863DB796E947F1",  38 => x"7F636C03E2FEF474",  39 => x"CB698ABE1BB8B968",
     40 => x"8716FD79A5FCF619",  41 => x"DE7107B2B49C94EF",  42 => x"97BA68DDCC5184EB",  43 => x"D2091BBEECDCD5CE",
     44 => x"B55432A7775E2615",  45 => x"AE0857D089AE2BED",  46 => x"D5799F4D6670E198",  47 => x"8D5AC68A0001FA93",
     48 => x"4A24C1D637136674",  49 => x"5CFED477D8754A27",  50 => x"633286A0F1B88BB3",  51 => x"E5AE82B035F29F09",
     52 => x"5F38064BA57E105A",  53 => x"1025D8ED32266656",  54 => x"21E3E59987A0559A",  55 => x"DAF194F2EB2F860E",
     56 => x"CC68D0B887582684",  57 => x"D960082BD1281E96",  58 => x"BB4F8885D28C4D63",  59 => x"27255902B293B681",
     60 => x"69F012C08FA6E6E6",  61 => x"41663E6D6585AE47",  62 => x"92DE0D5BA9BDEF40",  63 => x"C43E6D38EED80253",
     64 => x"C5350E979981D848",  65 => x"83B87CEF62D9C6CF",  66 => x"EE7FCEA55A5048C2",  67 => x"940900CD66789FD8",
     68 => x"3F49B8B012EAC728",  69 => x"F408684ED44A8021",  70 => x"353CF3E71C91E427",  71 => x"528354C3340399D3",
     72 => x"47AF24185E9C3110",  73 => x"C85B3C1476736F1D",  74 => x"5C3A9B90383D541F",  75 => x"008FD44CF9CA90B7",
     76 => x"0D71DBEC4AC44E57",  77 => x"B65181AF83EF6B3E",  78 => x"05D70906529D66CD",  79 => x"EDD446D6E77A59C6",
     80 => x"BFAF9E950E0ADBAB",  81 => x"14A4BFD086413EBB",  82 => x"E955A39E1827D939",  83 => x"C03FB8B82D0FC686",
     84 => x"636C75ED52058286",  85 => x"84EF01E48C957BBB",  86 => x"6DA5034440E6D6C7",  87 => x"03D627D774BBD707",
     88 => x"6091A7CE4234DCA4",  89 => x"1A40BA2832DFFBF5",  90 => x"0E5475B6325E3EC2",  91 => x"EBC576CD07115C19",
     92 => x"B5E874D5C5B16A89",  93 => x"AC5A134BD3247E96",  94 => x"DCCAA6EAF61DCEF5",  95 => x"834B6821C561F59E",
     96 => x"C1915035BCDDB0E5",  97 => x"6702AFB8AD5259C1",  98 => x"1D0708710C4FD0A7",  99 => x"AE55DE1743D91FCD",
    100 => x"A0782F7AEC859DBD", 101 => x"A4AE6471F0767F0C", 102 => x"83D750592D3360FE", 103 => x"6B14D1A5350EED8F",
    104 => x"FED89C3BBCA2924A", 105 => x"56F8BC850A07853F", 106 => x"D2F08BB15FA52912", 107 => x"8FA01E8A3C0EF4C0",
    108 => x"D1084920B7D4142A", 109 => x"8D18620566430533", 110 => x"52C1568509F8E625", 111 => x"934F8D5F0D9ECBF5",
    112 => x"84F7AF46992F7BFE", 113 => x"831E6D8FC7499E7B", 114 => x"E403EB2393AEAFFE", 115 => x"5B8A533F9852AD83",
    116 => x"FC78613AD2B9A701", 117 => x"287B1EB6DDF88852", 118 => x"56051AD74B97554A", 119 => x"8AE241232FD7E80A",
    120 => x"4F520572A2D20970", 121 => x"D9BE552CADDBF744", 122 => x"BD480B9C6BD5B9E8", 123 => x"BBC35E8CE1E0D94B",
    124 => x"B6F7C3C48A7ED61B", 125 => x"83811A2E1105521E", 126 => x"BB0366D6BF60B7AF", 127 => x"0799CA47879ECF54",
    128 => x"6598A7251A58A901", 129 => x"DC58098BBCC23A3F", 130 => x"4B84B0AE92EBDEB3", 131 => x"E9795CA8E9001F1D",
    132 => x"32B157DB7FB427C1", 133 => x"CD7D34756608F1DB", 134 => x"D0B1483ECCC1E26E", 135 => x"754147F6B6E9B19A",
    136 => x"CF5AA16CEAA4503D", 137 => x"8964C336AF57AF1C", 138 => x"7CEE79361344814F", 139 => x"64DDA1DFF0085428",
    140 => x"BA5AE496A192F582", 141 => x"C685DB287D55A407", 142 => x"653B35D8FDE830F0", 143 => x"F4E7F2C7B46902D5",
    144 => x"1C655364144463C9", 145 => x"2F6705AE44D12BFE", 146 => x"43C9DE4B806650EE", 147 => x"A169818B2F8C518B",
    148 => x"77F36543D06B8816", 149 => x"F184E565C45D7790", 150 => x"1B045059C89C8CE9", 151 => x"DE408D1A778E655C",
    152 => x"C4FDC11F4B4FA218", 153 => x"A5A62014B9C9FD02", 154 => x"C1C79C2A459ACA06", 155 => x"A5BAD549E575B157",
    156 => x"F65CA0E2E914965C", 157 => x"5DFDF374E6105621", 158 => x"12EE1425AC5BF6AB", 159 => x"E56D61B1AAC5B00C",
    160 => x"C8482B313E06174B", 161 => x"28241EE4545AC026", 162 => x"2ADC248F28B04F79", 163 => x"75D32B4A0445C427",
    164 => x"860761A2B57F017F", 165 => x"39FD4716F8E3D770", 166 => x"72D7FBB082E0ACDD", 167 => x"640780747C32C2BB",
    168 => x"842719A6A015D765", 169 => x"E3145996EE304AB1", 170 => x"AEDCC92CC7E08B65", 171 => x"D5550DAFB83BD196",
    172 => x"DB0A86594B70589A", 173 => x"C60F98544AC24187", 174 => x"1DF67346B7FA6223", 175 => x"AE432F851AD046A3",
    176 => x"10498108C96A9A5C", 177 => x"B25F2A6BC74235AD", 178 => x"879FBCC77C28680C", 179 => x"3D6E9BCAD643FCAA",
    180 => x"E5738ED11F68CD90", 181 => x"4FF3DF2AAF181A69", 182 => x"9C6E8DC4A24E4F79", 183 => x"747C1D5C12625F31",
    184 => x"A1EDEE17A7371BC2", 185 => x"984F9C5ED7F1F709", 186 => x"5C3D37AE61EA95E5", 187 => x"A389FB58D2A68367",
    188 => x"971B93DD0CAD0AE1", 189 => x"7DC65969A333CCB8", 190 => x"F48DD3CA4945D9CB", 191 => x"EC8F9D394434E03D",
    192 => x"550306CA9EC5F25A", 193 => x"EBF2C074ADA7960A", 194 => x"3737AF5FDEC5525D", 195 => x"E6B9511AD8A712E5",
    196 => x"0B975C1E093DB383", 197 => x"264A1E35C6A00C89", 198 => x"AB30C1B02206C38D", 199 => x"F0A66B0256A1B267",
    200 => x"BD95585534D17C81", 201 => x"E987E41D212C637F", 202 => x"5815D64ED6C91D45", 203 => x"ED0C400CEC9422BB",
    204 => x"8C5659D9D002B5C9", 205 => x"9BE2AB1671F0F3D7", 206 => x"B5937034C04DFB62", 207 => x"7647D7BB4B3A47B4",
    208 => x"D1ECC2C08362E4BC", 209 => x"F7EFB76A8E33603E", 210 => x"3AD556ADCD640F6E", 211 => x"B89774B5887F1C0B",
    212 => x"F145EC497C83E534", 213 => x"6D68C3F967AB6C91", 214 => x"9FE2880E4A977AF7", 215 => x"AFA9F3743DF12F35",
    216 => x"187A4EAAE0DF4977", 217 => x"4AA89A2F166C099B", 218 => x"EB62FA6F52C1A311", 219 => x"FE3AD9FDE1CF2227",
    220 => x"FF372FE1E57CEF5D", 221 => x"235BE2E78494921C", 222 => x"7212803D63472AB2", 223 => x"7139F6B9CFE6A8B8",
    224 => x"94F422E679A665E6", 225 => x"510CC85CF46334C0", 226 => x"12AFAD578700BC30", 227 => x"6A2CC1E664998A61",
    228 => x"033BF0FB3005CB13", 229 => x"3291231D1DFB820F", 230 => x"BC99D105539EB666", 231 => x"7E28A15C877626B3",
    232 => x"628314A46A97AC1E", 233 => x"ABD16CBCE5CBF9BC", 234 => x"93D87211FFA17752", 235 => x"83D5E80F05E47C31",
    236 => x"88547C7698D5BF0B", 237 => x"EC23440D60195426", 238 => x"9DEAF1D69CC9A7F5", 239 => x"B79F6D9BD4FCDD1F",
    240 => x"5577E2CE73AB4E8C", 241 => x"2364DE9C520A6EE6", 242 => x"3986DE60513FC1B4", 243 => x"2CAAA4F9E3BC2DAE",
    244 => x"637567CA74675FCB", 245 => x"87182BE4AE7BC06F", 246 => x"6C1040FF5ED6BB1C", 247 => x"6E5126D2396BB69C",
    248 => x"7008841DFD92EC2A", 249 => x"DB7E5BFB9586DBE2", 250 => x"13D57A94791FB88E", 251 => x"53DE3F945068E020",
    252 => x"13CB406A75FAA27F", 253 => x"95E78B49F03904C3", 254 => x"2EA329DD0B2835C8", 255 => x"16FA4ED5031CBCBB",
    256 => x"69C25CADECC3C41E", 257 => x"0DF6E8855CCC41C3", 258 => x"5EE9A6CD2AB2D349", 259 => x"4B5E09A13C57A422",
    260 => x"F6AE116A495E5959", 261 => x"96701C9B54544A48", 262 => x"8B04C54EAFAAE297", 263 => x"ACE527DAA1BB6E12",
    264 => x"115CF2B204AAC44E", 265 => x"7022602E44CF8F45", 266 => x"45B23593F13AE0FE", 267 => x"EB6B9ADD5D59B993",
    268 => x"4622615DD8922A64", 269 => x"3F5F5600F598A119", 270 => x"103AE9D36A2E704D", 271 => x"2A3262A70BCC9C7A",
    272 => x"8E41C628218E576D", 273 => x"1E00947F16B13387", 274 => x"99520A94FF262A21", 275 => x"1868B91BAAE71BD3",
    276 => x"0000000000000007"
  );

  -- Calcula el modelo de referencia s = (y*h) XOR x
  function compute_expected_s(yh : ram_array_t; pos : pos_array_t) return ram_array_t is
    variable res : ram_array_t := yh;
    variable w   : integer;
    variable b   : integer;
  begin
    for k in pos'range loop
      w := pos(k) / 64;
      b := pos(k) mod 64;
      res(w)(b) := not res(w)(b);
    end loop;
    return res;
  end function;

  constant EXPECTED_S : ram_array_t := compute_expected_s(YH_INIT, X_POS_INIT);

  -- Senales de reloj y control
  signal clk   : std_logic := '0';
  signal rst   : std_logic := '1';
  signal start : std_logic := '0';
  signal n_pos : unsigned(PA_W - 1 downto 0) := to_unsigned(N_POS_VAL, PA_W);
  signal ready : std_logic;
  signal done  : std_logic;

  -- Interfaz position_mem
  signal pos_we      : std_logic := '0';
  signal pos_wr_addr : unsigned(PA_W - 1 downto 0) := (others => '0');
  signal pos_din     : unsigned(POS_W - 1 downto 0) := (others => '0');
  signal sx_pos_addr : unsigned(PA_W - 1 downto 0);
  signal sx_pos_data : unsigned(POS_W - 1 downto 0);

  -- Interfaz ram64_sdp original (y*h)
  signal yh_we    : std_logic := '0';
  signal yh_waddr : unsigned(AW - 1 downto 0) := (others => '0');
  signal yh_wdata : std_logic_vector(63 downto 0) := (others => '0');
  signal yh_raddr : unsigned(AW - 1 downto 0) := (others => '0');
  signal yh_rdata : std_logic_vector(63 downto 0);

  -- Interfaz ram64_sdp resultado (s = y*h XOR x) y multiplexado TB / DUT
  signal res_we    : std_logic;
  signal res_waddr : unsigned(AW - 1 downto 0);
  signal res_wdata : std_logic_vector(63 downto 0);
  signal res_raddr : unsigned(AW - 1 downto 0);
  signal res_rdata : std_logic_vector(63 downto 0);

  signal sx_mem_we   : std_logic;
  signal sx_mem_addr : unsigned(AW - 1 downto 0);
  signal sx_mem_din  : std_logic_vector(63 downto 0);

  signal tb_res_we    : std_logic := '0';
  signal tb_res_waddr : unsigned(AW - 1 downto 0) := (others => '0');
  signal tb_res_wdata : std_logic_vector(63 downto 0) := (others => '0');
  signal tb_res_raddr : unsigned(AW - 1 downto 0) := (others => '0');
  signal dut_active   : std_logic := '0';

  -- Auxiliar para imprimir hexadecimal de 64 bits en VHDL-93/2008
  function to_hstring64(slv : std_logic_vector(63 downto 0)) return string is
    variable result : string(1 to 16);
    variable nibble : integer;
    constant HEX_CHARS : string(1 to 16) := "0123456789ABCDEF";
  begin
    for i in 0 to 15 loop
      nibble := to_integer(unsigned(slv(63 - i*4 downto 60 - i*4)));
      result(i + 1) := HEX_CHARS(nibble + 1);
    end loop;
    return result;
  end function;

begin

  -- Generador de reloj (100 MHz)
  clk <= not clk after CLK_PERIOD / 2;

  -- Mux de acceso a la memoria de resultado (precarga TB vs operacion DUT vs lectura TB)
  res_we    <= sx_mem_we   when dut_active = '1' else tb_res_we;
  res_waddr <= sx_mem_addr when dut_active = '1' else tb_res_waddr;
  res_wdata <= sx_mem_din  when dut_active = '1' else tb_res_wdata;
  res_raddr <= sx_mem_addr when dut_active = '1' else tb_res_raddr;

  -- Instancia 1: Memoria de posiciones dispersas de x
  u_pos_mem : entity work.position_mem
    generic map (
      DATA_WIDTH => POS_W,
      ADDR_WIDTH => PA_W
    )
    port map (
      clk     => clk,
      we      => pos_we,
      wr_addr => pos_wr_addr,
      din     => pos_din,
      rd_addr => sx_pos_addr,
      dout    => sx_pos_data
    );

  -- Instancia 2: Memoria densa con el vector original y*h (referencia intacta)
  u_ram_yh : entity work.ram64_sdp
    generic map (
      DATA_WIDTH => 64,
      DEPTH      => DEPTH,
      ADDR_W     => AW
    )
    port map (
      clk   => clk,
      we    => yh_we,
      waddr => yh_waddr,
      wdata => yh_wdata,
      raddr => yh_raddr,
      rdata => yh_rdata
    );

  -- Instancia 3: Memoria densa de resultado (precargada con y*h y actualizada a s = y*h XOR x)
  u_ram_res : entity work.ram64_sdp
    generic map (
      DATA_WIDTH => 64,
      DEPTH      => DEPTH,
      ADDR_W     => AW
    )
    port map (
      clk   => clk,
      we    => res_we,
      waddr => res_waddr,
      wdata => res_wdata,
      raddr => res_raddr,
      rdata => res_rdata
    );

  -- Instancia 4: DUT sparse_xor
  u_dut : entity work.sparse_xor
    generic map (
      POS_W => POS_W,
      PA_W  => PA_W,
      AW    => AW
    )
    port map (
      clk      => clk,
      rst      => rst,
      start    => start,
      n_pos    => n_pos,
      ready    => ready,
      done     => done,
      pos_addr => sx_pos_addr,
      pos_data => sx_pos_data,
      mem_we   => sx_mem_we,
      mem_addr => sx_mem_addr,
      mem_din  => sx_mem_din,
      mem_dout => res_rdata
    );

  -- Proceso principal de estimulos y verificacion
  stim_proc : process
    variable cycles     : integer := 0;
    variable err_count  : integer := 0;
    variable mod_count  : integer := 0;
    variable L          : line;
  begin
    -- 1. Reset inicial
    rst        <= '1';
    dut_active <= '0';
    wait for 3 * CLK_PERIOD;
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    -- 2. Cargar position_mem con las 66 posiciones de x
    write(L, string'("[TB] Cargando 66 posiciones de x en position_mem..."));
    writeline(output, L);

    for k in 0 to N_POS_VAL - 1 loop
      pos_we      <= '1';
      pos_wr_addr <= to_unsigned(k, PA_W);
      pos_din     <= to_unsigned(X_POS_INIT(k), POS_W);
      wait until rising_edge(clk);
    end loop;
    pos_we <= '0';

    -- 3. Cargar y*h tanto en u_ram_yh (referencia) como en u_ram_res (memoria destino)
    write(L, string'("[TB] Cargando 277 palabras de y*h en ram64_sdp..."));
    writeline(output, L);

    for i in 0 to DEPTH - 1 loop
      yh_we        <= '1';
      yh_waddr     <= to_unsigned(i, AW);
      yh_wdata     <= YH_INIT(i);

      tb_res_we    <= '1';
      tb_res_waddr <= to_unsigned(i, AW);
      tb_res_wdata <= YH_INIT(i);

      wait until rising_edge(clk);
    end loop;
    yh_we     <= '0';
    tb_res_we <= '0';
    wait until rising_edge(clk);

    -- 4. Ceder control de u_ram_res a sparse_xor y lanzar pulso start
    assert ready = '1'
      report "Error: sparse_xor no esta en estado READY antes de start"
      severity failure;

    dut_active <= '1';
    n_pos      <= to_unsigned(N_POS_VAL, PA_W);
    start      <= '1';
    wait until rising_edge(clk);
    start      <= '0';

    write(L, string'("[TB] Ejecutando sparse_xor..."));
    writeline(output, L);

    -- 5. Esperar hasta que done se active y medir latencia en ciclos
    cycles := 1;
    while done /= '1' loop
      wait until rising_edge(clk);
      cycles := cycles + 1;
      assert cycles < 2000
        report "Timeout esperando senal done de sparse_xor"
        severity failure;
    end loop;

    write(L, string'("[TB] done='1' recibido en ") & integer'image(cycles) &
             string'(" ciclos (esperado: ") & integer'image(3 * N_POS_VAL + 3) & string'(")."));
    writeline(output, L);

    wait until rising_edge(clk);
    dut_active <= '0';

    -- 6. Leer u_ram_yh y u_ram_res palabra por palabra y verificar s = (y*h) XOR x
    for i in 0 to DEPTH - 1 loop
      yh_raddr     <= to_unsigned(i, AW);
      tb_res_raddr <= to_unsigned(i, AW);
      wait until rising_edge(clk);
      wait for 1 ns; -- esperar salida registrada (latencia 1 ciclo)

      if yh_rdata /= res_rdata then
        mod_count := mod_count + 1;
        write(L, string'("  Word[") & integer'image(i) & string'("] modificada: y*h=0x") &
                 to_hstring64(yh_rdata) & string'(" -> s=0x") & to_hstring64(res_rdata));
        writeline(output, L);
      end if;

      if res_rdata /= EXPECTED_S(i) then
        err_count := err_count + 1;
        report "MISMATCH en direccion " & integer'image(i) &
               " | Leido: 0x" & to_hstring64(res_rdata) &
               " | Esperado: 0x" & to_hstring64(EXPECTED_S(i))
          severity error;
      end if;
    end loop;

    -- 7. Reporte final
    write(L, string'("------------------------------------------------------------"));
    writeline(output, L);
    write(L, string'("[TB] Palabras modificadas: ") & integer'image(mod_count) &
             string'(" de 277 | Errores: ") & integer'image(err_count));
    writeline(output, L);

    assert err_count = 0
      report "SIMULACION FALLIDA: se encontraron discrepancias en el resultado."
      severity failure;

    write(L, string'("[TB] SIMULACION EXITOSA: s = (y*h) XOR x verificado correctamente."));
    writeline(output, L);
    wait;
  end process;

end architecture;