library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity wrapper_all_kats is
  port(
    CLOCK_50 : in  std_logic;
    KEY      : in  std_logic_vector(3 downto 0);   -- KEY(0): reset (activo en bajo)
    SW       : in  std_logic_vector(17 downto 0);  -- SW(0): start, SW(1): corrupt_enable
    LEDR     : out std_logic_vector(17 downto 0)
  );
end entity;

architecture rtl of wrapper_all_kats is

  -- Estructura de cada vector KAT (palabras de 64 bits en el orden de tu interfaz)
  type t_kat_entry is record
    seed : std_logic_vector(255 downto 0);
    m    : std_logic_vector(127 downto 0);
    salt : std_logic_vector(127 downto 0);
  end record;

  type t_kat_rom is array (natural range <>) of t_kat_entry;

  -- Cambia este valor al número total de KATs que incluyas en KAT_ROM
constant NUM_KATS : positive := 100;

  constant KAT_ROM : t_kat_rom(0 to NUM_KATS - 1) := (
    0 => (
      seed => x"F808BC4F26657A30" & x"0B6B92BE2EE270F6" & x"D288A84BE5591817" & x"C3040E05600DFCCE",
      m    => x"DEFF1F57F2677C53" & x"8F9163892FA1EC3D",
      salt => x"F57155E386CE1575" & x"0C8626D88406B84B"
    ),
    1 => (
      seed => x"F4B9ED8B8E89365D" & x"623E61C6B7AFB0BE" & x"0E263126E8BB96ED" & x"AADD227EDE2D13E2",
      m    => x"60041F49836F9058" & x"CDC6A6CDF0FFEB42",
      salt => x"26E253076E170A7D" & x"D54F4412A4AC1949"
    ),
    2 => (
      seed => x"60C0B3DCCFE49705" & x"CFA9E44339FF66E0" & x"050DD0E8C56F8D3C" & x"AF3ED015F6261FF8",
      m    => x"0FF9D9EBBEF67A0C" & x"D2EBA32376C977CE",
      salt => x"7947DF93D07B867B" & x"7063CFF1303E60D6"
    ),
    3 => (
      seed => x"1837C34E3261D9CE" & x"78CFE90400E8A840" & x"37A106704FF28A81" & x"6A7C2CE773F22356",
      m    => x"D3AB95C39E50EE6A" & x"B1F5538B1B4E2FD4",
      salt => x"4BD430AF14929A8B" & x"21FA4B8249B54CF7"
    ),
    4 => (
      seed => x"EBF2CCB3B93617A3" & x"0BC539CA295831BF" & x"4C51C8A16BF979F4" & x"E95C55AD682F4807",
      m    => x"E7390D754A6CC376" & x"5C632D7F7FA73890",
      salt => x"D44A71FC27D30A0A" & x"D73A4E2687F5573E"
    ),
    5 => (
      seed => x"F70F965F2E94F1DF" & x"5592DF8D131838AB" & x"2421597215706E35" & x"324BBCA5999D50B4",
      m    => x"EC3F154D686E4860" & x"97FF6E7983967D2A",
      salt => x"629FE189800911AD" & x"A8A443CC8EC61B6B"
    ),
    6 => (
      seed => x"159476F8B00782F4" & x"CCDB308C7DE6785E" & x"97FEDF51374ADAE4" & x"2F22A46D7D1DD749",
      m    => x"46C6C52483987B43" & x"2AA1955429077BEB",
      salt => x"49E840C72043A324" & x"02D195828FB4E450"
    ),
    7 => (
      seed => x"5449C96A32243D69" & x"AAEE55F2534750D0" & x"338EC263B2B2C768" & x"9C32D3AC28612E3D",
      m    => x"64EC84DF3DCC318F" & x"D5E83A6E42765C49",
      salt => x"EDD77A85CEE8002C" & x"A9BE35ADF5264915"
    ),
    8 => (
      seed => x"9283BFF28EDBA993" & x"2B1D219E6E663587" & x"FD22A3993795EF73" & x"9FCE697A58D707B1",
      m    => x"486D7DAE880D55B0" & x"44E9D8200384B5C3",
      salt => x"B8AADAAC6FD4315B" & x"700042B2AABAE566"
    ),
    9 => (
      seed => x"291D60B6F851A875" & x"51F9FAE3F1FF91BF" & x"247A95A3A29AF6DE" & x"0F0B39058474BFA2",
      m    => x"E6F60EE9C508C0C8" & x"98FA775829FD4198",
      salt => x"CE8BB382221C55EC" & x"081F44134CA822E6"
    ),
    10 => (
      seed => x"805691E664523DB5" & x"EF771E66311BE58B" & x"BF4A23EEFA6C87C7" & x"56192EE3BF1698E2",
      m    => x"587702D3E9764AE9" & x"BD36C64B07147A9D",
      salt => x"2A8804B94F843296" & x"7AB702C9CE9DA87D"
    ),
    11 => (
      seed => x"957FC4E9CCF955D0" & x"79EEBADFEE86CCD6" & x"757D9742DEFE4A31" & x"9702261516BD218C",
      m    => x"AEEC09286F2F7131" & x"D31B14D90F189334",
      salt => x"088AFA1F4A4B9168" & x"BD83A19D48D21C04"
    ),
    12 => (
      seed => x"B364C007DE45BD40" & x"CBFC7D6A0A0B1062" & x"6E9B0A5C6ED834FA" & x"DAFECCA73222E46D",
      m    => x"039B362ED6E52DD4" & x"FFBFA0D2B3B9E496",
      salt => x"6B639074F02542AB" & x"972594F6E514ECFB"
    ),
    13 => (
      seed => x"CCE71F8D2C470119" & x"E65CBCE2A59C1428" & x"AD6500A7A23502AD" & x"950BCB214568CD6E",
      m    => x"DEB6185CE2764412" & x"60F67610372C40BE",
      salt => x"7194924387BD61E0" & x"7796246A4C660F8C"
    ),
    14 => (
      seed => x"34A34F8386C2AC1A" & x"1EFDE36C2905450E" & x"883DC10F768E30F3" & x"CCFC0C0C2C78C9AF",
      m    => x"231521536CE900B5" & x"F40DD88F63E05BC9",
      salt => x"ADC3607DA0AF168B" & x"D311CC7EA7CEF390"
    ),
    15 => (
      seed => x"1E016846D02D335E" & x"D885950098F4DDCA" & x"D1DB47E784A8D506" & x"6E7E392B6C1D7A90",
      m    => x"3D0EEE8ACCE74965" & x"C4989BE5E3E3A21B",
      salt => x"88593DF2B9D60CD1" & x"DB20B218014DC15C"
    ),
    16 => (
      seed => x"33AC552A4B8F4E80" & x"0450884018F8C94A" & x"C75550937DEE1288" & x"9CA76940A62A7667",
      m    => x"F4E8AA22ADB265EB" & x"F96F0E3380505F76",
      salt => x"72FB6B31E07BAF6F" & x"2A8654BF83470AD1"
    ),
    17 => (
      seed => x"AEF8AEA8E38E1DAE" & x"B502C728650BAF95" & x"5D4806F729CA9794" & x"58EF872EFF588C33",
      m    => x"0FA79A76493F2171" & x"D6432EB2BFFD9D43",
      salt => x"9CC581DE40E7ABF7" & x"1ADD8141DDC58E98"
    ),
    18 => (
      seed => x"6B8C64FA8D9E086D" & x"D5381AA3E922D895" & x"AD1159BB6ECA305C" & x"20FCCED105DE750B",
      m    => x"98F13F8CB8EA9531" & x"87D099F923E1468B",
      salt => x"C920B87B8DA9B026" & x"D124F14D5AE390DB"
    ),
    19 => (
      seed => x"854C20CB3FF28F2F" & x"ECA07939513C7C1B" & x"ADEADB670D59A486" & x"AD6B489476D7616D",
      m    => x"A2614DFA0E981B23" & x"EF3C1948FF2F47C0",
      salt => x"1CD6B61C7A9836C3" & x"A8AABCBA1BBB6718"
    ),
    20 => (
      seed => x"B7C3F8910EF10DDD" & x"88B524A6FE84B8B3" & x"B7A22F26961BE8A3" & x"C55B02E62160C229",
      m    => x"CD560E1BCAFEC983" & x"B317D613D68BC035",
      salt => x"CA37992B0EE2B22D" & x"4ECB73AE7E0AB4D6"
    ),
    21 => (
      seed => x"B67E8183B32B4FF4" & x"BDF3C7F437738450" & x"3CD7CE8813ABF06D" & x"02E02439D61E028A",
      m    => x"347A1B8E4F28D8A9" & x"D27E2452FA32440C",
      salt => x"0A63C6BA0825B863" & x"0A38FE0D1EBD7982"
    ),
    22 => (
      seed => x"4760F854EFEED81D" & x"B6ADF140C2B1505B" & x"DC7A41CB8359CF80" & x"7E193BDD520D131D",
      m    => x"EF3B991D818B3B8E" & x"807CBA26F31C2AAA",
      salt => x"7DAC0094FC394B4C" & x"EABA33030475DCCB"
    ),
    23 => (
      seed => x"635F2B6B35882857" & x"3A79524E3CB8FB5F" & x"8623FAF80830A234" & x"26FD3E43C1708586",
      m    => x"E44A9B3AD60D1702" & x"BD23149CE7DE5E6B",
      salt => x"CDA050E76F517B51" & x"490D513F4E4BB390"
    ),
    24 => (
      seed => x"57DF3E3BB2F5E923" & x"EB9146DB776BA14B" & x"D1BC29BC881A4F44" & x"D086F1E29EF6EACB",
      m    => x"63ADBDEFD3437DF4" & x"67FFDC375DDFC9C4",
      salt => x"536DA3F944E0BD86" & x"1571970281282AAF"
    ),
    25 => (
      seed => x"4E9545DD548BDE55" & x"7E7B2A7A00B539A0" & x"4953EED95ECC5196" & x"BE5EE8FAFC5C81ED",
      m    => x"2F5EC35EA0784F53" & x"C29886FD80A1C0F9",
      salt => x"115D910C98DE0A76" & x"B7B221397A292CFB"
    ),
    26 => (
      seed => x"8141199DC434FE7E" & x"AF86DDB11AA8E957" & x"3942B29A84BA7502" & x"0B788EDF3E1B10BC",
      m    => x"FA2AD8E0AD22C571" & x"DF64C28A71944E88",
      salt => x"CC0C0467592B11B2" & x"2FA73FD683274044"
    ),
    27 => (
      seed => x"D1A18B01821B4621" & x"2132A54C94F30738" & x"E4F17B1C4182072A" & x"3D0902FC2136F314",
      m    => x"5F50492AAE4864B9" & x"6EB9733ABF3CDD1F",
      salt => x"4DFC1695DBE9150D" & x"8C83D7F00EC3907D"
    ),
    28 => (
      seed => x"57CE2B087F7B0204" & x"D68D196E86496325" & x"5522025DAEBD6756" & x"8447F5F569AE2CAF",
      m    => x"F6D21E4886AB6785" & x"9D2309956DD89E1D",
      salt => x"6F417655219FA150" & x"8A510DAED95F6AD6"
    ),
    29 => (
      seed => x"D2C9885942412BD0" & x"40840798D3965B8B" & x"EEB3D79295FA1D5D" & x"64A2F16FD3261549",
      m    => x"BD732DD6401A57E6" & x"80F0E4573C1F8D8E",
      salt => x"962DBA95D89A15DF" & x"D02150608519CF74"
    ),
    30 => (
      seed => x"1C79850EC10F1A22" & x"B57433486C7F0909" & x"9FD637CA4FA3E5AD" & x"14E6709D0800B655",
      m    => x"0E96EBDEDBC2075B" & x"5A574627AD769C4A",
      salt => x"CB8C235449F61615" & x"DFE6EBE7DE73FA1F"
    ),
    31 => (
      seed => x"61EF94DECBD681AB" & x"F052C3F6FF7674E4" & x"23A3579C3A2C5FB0" & x"2678295B3699910A",
      m    => x"8778FD4DCC8D4502" & x"6A227288C1C7BC33",
      salt => x"27C9331624CEF480" & x"CBE03E0FFAFDA1A8"
    ),
    32 => (
      seed => x"E51D9FF8882D0240" & x"56F494241334B59B" & x"322DBE2FB84F44AC" & x"04EB4C996FACE569",
      m    => x"B75C8D7F2C2EA2D4" & x"74AA808796684060",
      salt => x"CBE815CDD1335FC8" & x"2AF3C391375F64EE"
    ),
    33 => (
      seed => x"3C424CF3B877B083" & x"86B82B0F1DDC3BCD" & x"730B4CF96EC07CE1" & x"45DE1743E1F9C615",
      m    => x"8F38FB9D9161236A" & x"56E2131A68CEF0AE",
      salt => x"14457F7D209EEBC7" & x"7F3EAB692345582E"
    ),
    34 => (
      seed => x"6D7006B15B7166F4" & x"436D3058EA8D25E3" & x"03470A23F53222B6" & x"2D75DF9C4EBD3F28",
      m    => x"EEC78889705F228D" & x"1551F9A0EC718C3C",
      salt => x"F33FD7A453C8F63A" & x"397164AC0B3814AB"
    ),
    35 => (
      seed => x"3C986EEBF13243F3" & x"6BA10194BF4A97DF" & x"A63FABD140391126" & x"6B286E4B166331B7",
      m    => x"CAE3084B9550CCF2" & x"3243DB5EEF1B9F35",
      salt => x"9114044A9C8DB5D8" & x"832B726E7D1AECD0"
    ),
    36 => (
      seed => x"65FB5BF0604202EA" & x"EC08F15DD6285971" & x"6F40535345B1D046" & x"691149556B9751D8",
      m    => x"111F0B3760B2B590" & x"6DB4C80FC2906950",
      salt => x"A362D847E556F938" & x"A88C531739064421"
    ),
    37 => (
      seed => x"1B669C03E0A04E64" & x"0FA6C1F8735D975A" & x"B9EB9DB212B84F0D" & x"57C1549B264542B2",
      m    => x"C08828E5B52F286B" & x"9529DC7A2B0620FE",
      salt => x"C723735DA4E20EFF" & x"514B4A8B5CC2DF48"
    ),
    38 => (
      seed => x"81837273DCC223FB" & x"602629F02BF002E2" & x"CFBD5142A17A3EDB" & x"0356FF17264426A7",
      m    => x"F42CAC629686AAC4" & x"2FA77953177F6F9F",
      salt => x"7034E3E11F5BF97E" & x"59EC7013D22B69DD"
    ),
    39 => (
      seed => x"4701BCB9331667EA" & x"54C6F20BACA34C52" & x"F3A45E1CF8DE40CE" & x"68BF9BFBC53C71B7",
      m    => x"19B396A083E70E07" & x"EA35107E725D4188",
      salt => x"72BDA2130D417614" & x"60B857E4DFB7E054"
    ),
    40 => (
      seed => x"8AC7F26FD460C307" & x"546AB1CC76824229" & x"7AE59AD694337763" & x"F2FEF2FF55FD14E3",
      m    => x"C7B5C6B071415880" & x"28DF39EAEC2CF9A7",
      salt => x"33CB2376517E80CB" & x"3FD4EDE2B28EF5B9"
    ),
    41 => (
      seed => x"38DFC2C50167A7D8" & x"100659EC93A40A97" & x"4C0F0FEE524F3476" & x"E966F9521FFEFDF4",
      m    => x"6B2AC9A2968B7BE8" & x"AD5476632F5C9D87",
      salt => x"1C7703EBEE3FAA31" & x"29EFF1B6FBCA946C"
    ),
    42 => (
      seed => x"7282882D4F702E3B" & x"3ADAB85624F325F7" & x"0E4BC0143195E694" & x"19A309DE199138E2",
      m    => x"E8F5EFFFD4588D1F" & x"90F762C40089AB67",
      salt => x"B63F349D815F93CB" & x"2D58C3BE1ED96766"
    ),
    43 => (
      seed => x"4349CCE74AA1043B" & x"285622389FDD83AF" & x"681AC268D6FBE3EC" & x"DF8585DC8B4A21C6",
      m    => x"CAF4B32BB487A090" & x"9FA3460F6302AB8A",
      salt => x"61771786CE81628D" & x"4337C2FBB326D878"
    ),
    44 => (
      seed => x"12588FB8A9DFBF81" & x"DEA15056D0BCE3A0" & x"B206A7A873A19851" & x"051C05D0449447D4",
      m    => x"0871DCE3F4C12231" & x"E33B9615270B49B2",
      salt => x"6114FF3D9424B504" & x"966D50101B34CFE3"
    ),
    45 => (
      seed => x"73C27628BC523F18" & x"68A6DA21393C9141" & x"86D010403A9D6833" & x"9B993FC52E8BCABE",
      m    => x"A12D8573AA9BD481" & x"3B7A5F6DA232EF85",
      salt => x"AF114AA2D0372AC6" & x"239F47267AD22158"
    ),
    46 => (
      seed => x"C39863B165F265B4" & x"44AD4E854054D689" & x"2E50C154F1513A38" & x"2BF69C8A445CB4C2",
      m    => x"8E9D7F2A477AB20C" & x"30940E282698B4A9",
      salt => x"CAAF894DADE1124B" & x"7CB72F58601FD7F2"
    ),
    47 => (
      seed => x"E548F47E322052D3" & x"8102D3840FD05652" & x"B509098451FE6532" & x"35AD91E0A02BE5BD",
      m    => x"358956BFCA3F916C" & x"56E22AB0459868D0",
      salt => x"A1A17DEA8733B067" & x"1980A41CAB11F639"
    ),
    48 => (
      seed => x"F92B8E5125D01746" & x"83A1F6FDFD91311B" & x"1AE9B3D47B5EB6E7" & x"E75E34F36CF58E59",
      m    => x"1E55F15702849CDD" & x"D1158403C5516A48",
      salt => x"CECCA6311074A27E" & x"A293C000148ABA19"
    ),
    49 => (
      seed => x"0698866DC186E8FA" & x"67D533B676C86BBC" & x"C48A9B73F6133FED" & x"D2A2EF72486AAE53",
      m    => x"7E59A02481137441" & x"4BD7BB68B700137D",
      salt => x"67C7FB728BA63D76" & x"A6BBFE3A6A486813"
    ),
    50 => (
      seed => x"A6851C37AF7D1676" & x"DB02ABCE94D9C986" & x"F2FFB0F52D95E84E" & x"A30FBAFC9307B934",
      m    => x"4FB07C1A695BD2A7" & x"1AF8018517F95129",
      salt => x"AB5B252CB8E0D37E" & x"185437A54F1210C3"
    ),
    51 => (
      seed => x"F7336CDF86E76DDE" & x"4C471BACB7158157" & x"5A2CD825D5EEF814" & x"380690F89CEB6A77",
      m    => x"B221CE3E11AC2045" & x"0C4D94690AA5D0DC",
      salt => x"F5F9178AC85C52E4" & x"6D96A89B47789345"
    ),
    52 => (
      seed => x"308D7950CC319911" & x"A5CD3F62B212CA39" & x"06CA90148DC60F17" & x"61896F3BECFA2C55",
      m    => x"F48AAEC521991322" & x"FEA1D3649CC62AEE",
      salt => x"8DA477AC104449E3" & x"31EA2C1A1D63D2C1"
    ),
    53 => (
      seed => x"890C904FAE7DCE78" & x"82767ED2180857ED" & x"84A56949524A1AA8" & x"80EA821A8D0661D3",
      m    => x"CBF6BFCBC1D40AF4" & x"88999E0A7E7B483F",
      salt => x"B61181EAF1985520" & x"FED43F349CF78EB5"
    ),
    54 => (
      seed => x"750019D745321F2D" & x"2BCC7442C0C7C2E7" & x"04858F1D5186DB84" & x"B5790538E3352A11",
      m    => x"90E07FB494C71417" & x"F05DA209119F916D",
      salt => x"07FC99BDD29953D2" & x"8DDB606CD3CEDB03"
    ),
    55 => (
      seed => x"C254DCB9213B448B" & x"5CE8E4087B6D72FC" & x"CBF5F0A5464773A4" & x"3DFD2051D028973A",
      m    => x"E625F7C81E93E31A" & x"F8F24759CA2E3FDC",
      salt => x"4C8EDA6CC2C14A06" & x"44C6D9FAB26D143A"
    ),
    56 => (
      seed => x"776BEA46A4AA8174" & x"226C2EB9EA2CCE84" & x"69C54EDAE70DAEB1" & x"02273152A7BB152E",
      m    => x"AEC2641E7517D4C8" & x"6AD69A6EF18872C5",
      salt => x"CE06ADC86CD73321" & x"9D6DC5BC48D9B9D7"
    ),
    57 => (
      seed => x"0B3B21730240924E" & x"A77BCED22099CA21" & x"E8F4AF7148803AF1" & x"C7A1E316A5EE3FA8",
      m    => x"2314BE6CF78851E3" & x"734AEF72E6672E41",
      salt => x"F26271C446247155" & x"A3EF7C784275D888"
    ),
    58 => (
      seed => x"9F1A9FC6B38BB49C" & x"3C2F74C94AFDF7BA" & x"41CF14C2A35CD2DD" & x"D9871C380A0D54A0",
      m    => x"C1D0A88C9FDC0BAB" & x"8808C015D5BD569A",
      salt => x"9221EEEBC0766B3F" & x"278EBE06B230A327"
    ),
    59 => (
      seed => x"B8B71D9306685259" & x"D09274D5AE00B15C" & x"24697E4306281874" & x"A6F0EF1BD0028B2C",
      m    => x"E26EEE890BE76383" & x"79F2CD42A39565C2",
      salt => x"6BC50ECCE5213B21" & x"843DC4929FAF44D2"
    ),
    60 => (
      seed => x"E00F3C9B587B2577" & x"DC8A401B6F348ED9" & x"41C3508E9B3C6A1C" & x"973E4FCBBBDBF98C",
      m    => x"E993E67CAB02FDA3" & x"95EE546935393161",
      salt => x"4825BD64159D3A6B" & x"5DB59B543D0B0A4A"
    ),
    61 => (
      seed => x"28A896CE2878F52F" & x"2BF3661544697424" & x"1109E46D0A80B7CE" & x"E9DD18CAA86FAE58",
      m    => x"CFD7171FC1D7DAFD" & x"EAB031A57F8DD6A9",
      salt => x"A3F8276E029A27EB" & x"BA89696ED13FF9BC"
    ),
    62 => (
      seed => x"205CEB61AE193670" & x"6EEBE25FBA2CB5EB" & x"2C6242CFC12138D0" & x"A443FD8CC95C6069",
      m    => x"3446D0C70E435EB3" & x"5867FB11BED22AD4",
      salt => x"6742A3A3ABCBF78D" & x"BBF0E6C627426CC2"
    ),
    63 => (
      seed => x"72F753A2425FC164" & x"8224765553A8AA41" & x"67D2611B4CB857EB" & x"AE13AD518D128F5D",
      m    => x"EEB36BDC58EE38F2" & x"905E7D9677DDCAD7",
      salt => x"D41A8F1DEA442230" & x"4A4294AAAE51B95F"
    ),
    64 => (
      seed => x"A16127F120302C74" & x"6133F7BA9A0B7F68" & x"F8D11FD5C3E3B002" & x"A761C958162B09C8",
      m    => x"DBD284DA8CDDA5A2" & x"C65DF736FB2D6105",
      salt => x"D30BA34F77D2B757" & x"CDAAD655C0BE6FFB"
    ),
    65 => (
      seed => x"7B74D27BB64FCA4A" & x"17B921F586456999" & x"6F7F0DB5F2A3B4A5" & x"A9348F3727C1D66F",
      m    => x"3C8CF419096C1E85" & x"80DAB9B6B845BC89",
      salt => x"6C1DC555FFEEDF87" & x"0BADE90F18CB93BA"
    ),
    66 => (
      seed => x"B595308199A369D4" & x"91C077744378F442" & x"1AE6D4A8F9A0CB97" & x"908D210054A0950F",
      m    => x"66BE07B0ACE39F7E" & x"877255C9CEB0827C",
      salt => x"45D3A35E384641E6" & x"85F09F15B621C726"
    ),
    67 => (
      seed => x"073D53EE75F97F5F" & x"589080D43C2BDA5F" & x"D6F20A2C8055371B" & x"454A56F95FC569D5",
      m    => x"8E8C283BCC46E4D7" & x"BDC5FEDD2841AF96",
      salt => x"1D6F1DBCFFC1CD8E" & x"04926475151E53C9"
    ),
    68 => (
      seed => x"029BF9BCC0EF15D3" & x"E545F63F34C0FF1C" & x"13A27F3816577C36" & x"5113C48F25332BA2",
      m    => x"4D5A41AE5E65F753" & x"F29E243A784A93CC",
      salt => x"56B92D228D56432D" & x"D8F55378B95B7CD8"
    ),
    69 => (
      seed => x"254279D6AE143A9D" & x"26E1D3CBBFA17179" & x"C436C62DE9032FF8" & x"EB65CC66DC18F951",
      m    => x"FB029DC12A51ECC8" & x"81596B681EB7D447",
      salt => x"566C9AB6A753C12B" & x"F56C068C25AC6E49"
    ),
    70 => (
      seed => x"E148F5BA9E4F5A9D" & x"F225B3D30D14242F" & x"14FBC6405B230B89" & x"118FCEBAD89CE1C7",
      m    => x"BA78CC115DD9434D" & x"C07D869FF49A89EF",
      salt => x"F21EF5BF6286FE6D" & x"A00359713CC9E08A"
    ),
    71 => (
      seed => x"E03D1C83E2CB2173" & x"17B5696E3207B211" & x"45A71FD07E723708" & x"C10E4D3D37ADF540",
      m    => x"D4CBF3FEB30A8632" & x"0691960CDBED7017",
      salt => x"413B1FFBE4BDD1E8" & x"F23D02B0F1645F64"
    ),
    72 => (
      seed => x"E0C8889AC58902A1" & x"CA2BD1118FAC43E3" & x"3484FDD4F79A15BF" & x"0A0403332F8A3E38",
      m    => x"5A55D5CA552AF37C" & x"4BC6D9D402801217",
      salt => x"8B69F5C9256AE069" & x"1BE4AB4F6AE029DB"
    ),
    73 => (
      seed => x"CE34538AFC80C68F" & x"781AF9A501B0131F" & x"4B41D11EC9379AFD" & x"BE83DE808ACFF9B1",
      m    => x"8D1E72989804FBCB" & x"74B7F22D6FC9842F",
      salt => x"CD4426DD6CB7B583" & x"AE3F3E1FF7DC6A27"
    ),
    74 => (
      seed => x"AA3417E4C891CA6F" & x"155ED24A1C8E6AF8" & x"235811AA10A20AC7" & x"92A9EE75B8B0FE5B",
      m    => x"21C9A8A5A30E0E30" & x"3BD7FA8BC2047E19",
      salt => x"DF98365C8F3E9878" & x"39EEBEDFE5A8A421"
    ),
    75 => (
      seed => x"AE89D2C2F9108553" & x"04E602209E23CAA4" & x"F1A75B7FA3AA12FB" & x"AC7F5544D54836BD",
      m    => x"E0F0FC6E29E541D5" & x"E59D7B28D14CAF9C",
      salt => x"1B9724C7D0980D09" & x"F59A5893984E400D"
    ),
    76 => (
      seed => x"FA1845E97874D5DC" & x"C1DDFB0C520F8FB6" & x"5B6743B577372A06" & x"9395F0173865BDB4",
      m    => x"0FA81CFF28B79720" & x"630FB09AEA857AF6",
      salt => x"A77424F03876326A" & x"5BA2229E3493A224"
    ),
    77 => (
      seed => x"0E169486FCEC2C52" & x"AABF6134F9BC327C" & x"8C3CE9177BEFAEAC" & x"FC65A83B04465CBD",
      m    => x"4C1E84891B7F6D7D" & x"263DAEC59189DB6A",
      salt => x"41FB9E0C3A691642" & x"19521F94F7F1F043"
    ),
    78 => (
      seed => x"28305027F14FE407" & x"E53A4C0D2CF454A3" & x"362B8FCFF5CD04F5" & x"EFA8DF7EA0057D36",
      m    => x"E104B3B8CB122D1E" & x"F0F08EDC5D79AF73",
      salt => x"DE9378C4A360345F" & x"61C737C88AF0F8ED"
    ),
    79 => (
      seed => x"6106D514858C35AA" & x"A99B5AAC5CC6CE1D" & x"88F7039188C5407C" & x"97FEF0813EB5A7FA",
      m    => x"F37D67693D9FA4DA" & x"3E4E59C7D4921484",
      salt => x"04F13ABABF7BAA97" & x"3765342D4C8BEE2C"
    ),
    80 => (
      seed => x"63D3441FBD2AD161" & x"434E9D8419CD2009" & x"5EC37F30F27D5617" & x"F34D3E9312FA1FFA",
      m    => x"E9B5B654FEF959FA" & x"D32DDA8322C5FBA5",
      salt => x"0E24F23DE68C68D9" & x"5F76DC0DB6F0DB08"
    ),
    81 => (
      seed => x"DCF4410CB3684D94" & x"BEF844253A5CDB7D" & x"D13C1BDB51F6CBE1" & x"3118E59DE2FD4706",
      m    => x"2AC757C82E4D99D0" & x"D7C5DA8FE2CA76A6",
      salt => x"012A63A9C7193948" & x"D6397DEF3B5BB2D1"
    ),
    82 => (
      seed => x"27B36CE16522FD1B" & x"B2E62542C53F1594" & x"DB21C7F9DB275D6A" & x"F5BC44C982CEEFBB",
      m    => x"1F43C36080352CA6" & x"3E1D7EC973202F78",
      salt => x"B1B050CCA0BC9CD2" & x"3457A53D31C10560"
    ),
    83 => (
      seed => x"948208CCF5882D64" & x"4729039B9E34C789" & x"77BE6D598F0927DB" & x"D5C89A3CCBD090F2",
      m    => x"F23C7D2B68FE171E" & x"87DF9A0A81092C6C",
      salt => x"B1955C9F3782F853" & x"27B927763F8B1FAF"
    ),
    84 => (
      seed => x"61BE1710D0F56141" & x"C564CF9090F29670" & x"EE9ED264BBFE6706" & x"687E1EDD3007F013",
      m    => x"3B1C8D20B386AED8" & x"5AA9614BED023E0A",
      salt => x"74ADDEE33322A5EF" & x"734D64119C58D90B"
    ),
    85 => (
      seed => x"78A7621729778DCC" & x"8CDB6C2FE07FB692" & x"AB88892B2C0DF1B5" & x"00933B8AA29CCF77",
      m    => x"76DE87BBBD24125C" & x"88C459C5D5F71E56",
      salt => x"DCAAA452E0F9059F" & x"10BE297FC85D8B3A"
    ),
    86 => (
      seed => x"D9BF5339ADD2D6CE" & x"6AAD791C36C903CD" & x"7C8E062E307D6CC2" & x"BC65CF28495B1F83",
      m    => x"E321D950C4CF5800" & x"B1709B92264D1418",
      salt => x"90C2E577E6F82C2B" & x"9F1AA6C752DC26B5"
    ),
    87 => (
      seed => x"D808680397BBD214" & x"05A24F824CF4884E" & x"FC62E1CAB69BABA8" & x"F18E56F2D65C9960",
      m    => x"DB0D4B9BD3A107F6" & x"454E7AB3660DB871",
      salt => x"90FF5302FD03AA39" & x"FE9DA5C787B2BB19"
    ),
    88 => (
      seed => x"5BDAFD6C8B4CD5F8" & x"FD21383268C72A49" & x"5E194D91591E4175" & x"2D1E7B55B7E3E7CE",
      m    => x"A746758CBADB257D" & x"7AF61FF659AFCA36",
      salt => x"962D13557AC49AB5" & x"1DEB6D2951455008"
    ),
    89 => (
      seed => x"9DF6C8950DA58A23" & x"BC7D108B698CA135" & x"53E5AFFC022FB929" & x"F6821E1497895B00",
      m    => x"96474D3005022575" & x"67F94F9F6545FD45",
      salt => x"396D64842D523F5D" & x"83D40EC9CA4966DE"
    ),
    90 => (
      seed => x"5C3A9D8D692B838B" & x"0D5AC9CFE964C418" & x"3C1E9EADBE4D283B" & x"7D954DB2CE7A7BD9",
      m    => x"1FCDC2FC049199AE" & x"149E3389B83E9F3F",
      salt => x"DECE885AE8CAADB2" & x"FE240887732C9C08"
    ),
    91 => (
      seed => x"7A4A37ABDE9CCAE7" & x"5F5608C2EA3ACC5A" & x"D6FF0561B4C640E4" & x"8A58CDA3B2364893",
      m    => x"B27AFC386E1FE430" & x"1A6EFFB24E490958",
      salt => x"EDC0F41DEAD1B05F" & x"F8AF9DE8080D5454"
    ),
    92 => (
      seed => x"C431C35A901B57B6" & x"2A4AB88E5D0E93A4" & x"3F9455C9DC57492C" & x"755A5DC1968C5120",
      m    => x"ACB77D63678A4AC8" & x"406863A8E00A2C39",
      salt => x"2DAD2B1A1AA640F3" & x"6D213264C38F4EE7"
    ),
    93 => (
      seed => x"832BD2CD043FA0C4" & x"94BAF59185A29740" & x"2B23EA83164813EA" & x"AE1EAF59E9976B8C",
      m    => x"02D3F6497019724B" & x"BB3932AA0FE68E71",
      salt => x"F53D1FB68C8EA274" & x"D99F4028609DC7FB"
    ),
    94 => (
      seed => x"4A05BA6EBE33E6A3" & x"C28C2B5CFCA93F4D" & x"D1092D7BEA0C666F" & x"F77D061D4F3FF89C",
      m    => x"0F1B0A487420A0BC" & x"0A1FDD805A750DBF",
      salt => x"C97A053EB8C8B9A0" & x"7A13A2896CD407A4"
    ),
    95 => (
      seed => x"4B16CB672573C777" & x"F5A25A749C037F02" & x"D8BB6DCCE17F5802" & x"752D28E5CC4CAB30",
      m    => x"3E35D7034AB23D52" & x"002582E82137C3F1",
      salt => x"366652BA03FA7250" & x"AB7EAD31FAF16ACD"
    ),
    96 => (
      seed => x"52EC21B6FB5E52DE" & x"3D6FDB65313C994B" & x"6C46A67C03321259" & x"A1A3BF4AFCACCDD0",
      m    => x"20FD670E906D3E63" & x"4C35222902F0E0C4",
      salt => x"ADA893778F1EB1C4" & x"B47FA93745F78AC9"
    ),
    97 => (
      seed => x"6A72E126CD67B67C" & x"E37F6D0239F4B1C3" & x"9F0C79D8D8F5F6CC" & x"EB31D91765265C6F",
      m    => x"44E0A360D14C35EB" & x"8E80AA960425E57E",
      salt => x"2CDF986E61809F41" & x"51852675B73B9423"
    ),
    98 => (
      seed => x"D83486920095226C" & x"71B2659BCCB958FE" & x"7E76217E6BEBA246" & x"AD74F3A7D72FAAF8",
      m    => x"52CB23AE47458EEC" & x"607B573CB026FE20",
      salt => x"2492A2D00376EBA4" & x"5E5BA3802EA778A4"
    ),
    99 => (
      seed => x"4BF2C18A1F67F419" & x"AD100C82EA692041" & x"B26F8CDD8B4503C5" & x"1AAAE4A291DDD57C",
      m    => x"1325DFD6F2382E37" & x"AAB576C0CE78D1CF",
      salt => x"CE86EFED9BF5A169" & x"E5448858EE46FF30"
    )
  );

  -- Control, sincronización e índice del KAT activo
  signal rst          : std_logic;
  signal sw0_sync     : std_logic_vector(1 downto 0) := (others => '0');
  signal sw1_sync     : std_logic_vector(1 downto 0) := (others => '0');
  signal start_pulse  : std_logic := '0';
  signal done_latched : std_logic := '0';
  signal kat_idx      : integer range 0 to NUM_KATS - 1 := 0;
  signal kat_idx_slv  : std_logic_vector(3 downto 0);

  -- Señales del núcleo hqc_kem_pipeline
  signal pipeline_ready         : std_logic;
  signal pipeline_done          : std_logic;
  signal result_k_words         : std_logic_vector(255 downto 0);
  signal result_ss_encaps_words : std_logic_vector(255 downto 0);
  signal decaps_reenc_match     : std_logic;
  signal result_k_equal         : std_logic;
  signal result_error           : std_logic;
  signal result_decaps_error    : std_logic;
  signal cycles_keygen          : unsigned(31 downto 0);
  signal cycles_encaps          : unsigned(31 downto 0);
  signal cycles_decaps          : unsigned(31 downto 0);
  signal cycles_total           : unsigned(31 downto 0);
  signal state_code             : std_logic_vector(7 downto 0);

  -- Evita que Quartus pode las señales observadas en SignalTap
  attribute keep : boolean;
  attribute keep of start_pulse            : signal is true;
  attribute keep of pipeline_ready         : signal is true;
  attribute keep of pipeline_done          : signal is true;
  attribute keep of kat_idx_slv            : signal is true;
  attribute keep of result_k_words         : signal is true;
  attribute keep of result_ss_encaps_words : signal is true;
  attribute keep of decaps_reenc_match     : signal is true;
  attribute keep of result_k_equal         : signal is true;
  attribute keep of result_error           : signal is true;
  attribute keep of result_decaps_error    : signal is true;
  attribute keep of cycles_keygen          : signal is true;
  attribute keep of cycles_encaps          : signal is true;
  attribute keep of cycles_decaps          : signal is true;
  attribute keep of cycles_total           : signal is true;
  attribute keep of state_code             : signal is true;

  attribute preserve : boolean;
  attribute noprune  : boolean;
  attribute preserve of result_k_words         : signal is true;
  attribute noprune  of result_k_words         : signal is true;
  attribute preserve of result_ss_encaps_words : signal is true;
  attribute noprune  of result_ss_encaps_words : signal is true;
  attribute preserve of cycles_total           : signal is true;
  attribute noprune  of cycles_total           : signal is true;

  function xor_reduce(v : std_logic_vector) return std_logic is
    variable r : std_logic := '0';
  begin
    for i in v'range loop
      r := r xor v(i);
    end loop;
    return r;
  end function;

begin

  rst         <= not KEY(0);
  kat_idx_slv <= std_logic_vector(to_unsigned(kat_idx, 4));

  -- Sincronizadores, pulso de start y avance de KAT al finalizar cada ejecución
  process(CLOCK_50)
  begin
    if rising_edge(CLOCK_50) then
      if rst = '1' then
        sw0_sync     <= (others => '0');
        sw1_sync     <= (others => '0');
        start_pulse  <= '0';
        done_latched <= '0';
        kat_idx      <= 0;
      else
        sw0_sync <= sw0_sync(0) & SW(0);
        sw1_sync <= sw1_sync(0) & SW(1);

        start_pulse <= '0';
        if sw0_sync = "01" and pipeline_ready = '1' then
          start_pulse  <= '1';
          done_latched <= '0';
        elsif pipeline_done = '1' then
          done_latched <= '1';
          if kat_idx = NUM_KATS - 1 then
            kat_idx <= 0;
          else
            kat_idx <= kat_idx + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  u_hqc_kem_pipeline : entity work.hqc_kem_pipeline
    port map (
      clk                    => CLOCK_50,
      rst                    => rst,
      start                  => start_pulse,
      pipeline_ready         => pipeline_ready,
      pipeline_done          => pipeline_done,
      seed_kem_words         => KAT_ROM(kat_idx).seed,
      m_words                => KAT_ROM(kat_idx).m,
      salt_words             => KAT_ROM(kat_idx).salt,
      corrupt_enable         => sw1_sync(1),
      corrupt_word_index     => to_unsigned(0, 10),
      corrupt_bit_index      => to_unsigned(0, 6),
      result_k_words         => result_k_words,
      result_ss_encaps_words => result_ss_encaps_words,
      decaps_reenc_match     => decaps_reenc_match,
      result_k_equal         => result_k_equal,
      result_error           => result_error,
      result_decaps_error    => result_decaps_error,
      cycles_keygen          => cycles_keygen,
      cycles_encaps          => cycles_encaps,
      cycles_decaps          => cycles_decaps,
      cycles_total           => cycles_total,
      state_code             => state_code,
      mem_read_request       => '0',
      mem_read_select        => '0',
      mem_read_address       => (others => '0'),
      mem_read_valid         => open,
      mem_read_data          => open
    );

  -- Indicadores físicos en LEDs rojos
  LEDR(0)           <= pipeline_ready;
  LEDR(1)           <= done_latched;
  LEDR(2)           <= decaps_reenc_match;
  LEDR(3)           <= result_k_equal;
  LEDR(4)           <= result_error;
  LEDR(5)           <= result_decaps_error;
  LEDR(6)           <= xor_reduce(result_k_words) xor
                       xor_reduce(result_ss_encaps_words) xor
                       xor_reduce(std_logic_vector(cycles_keygen)) xor
                       xor_reduce(std_logic_vector(cycles_encaps)) xor
                       xor_reduce(std_logic_vector(cycles_decaps)) xor
                       xor_reduce(std_logic_vector(cycles_total));
  LEDR(9 downto 7)  <= kat_idx_slv(2 downto 0); -- Índice del KAT siguiente en binario
  LEDR(17 downto 10) <= state_code;

end architecture;