-- Testbench de samplefxwtmod  (generado por gen_tb.py)
-- sample_fixed_wt_mod: 3 llamadas seguidas (r2, e, r1) sobre el mismo flujo
--
-- * Instancia position_mem junto al DUT. El SHAKE se simula presentando palabras de 64 bits en
--   shake_din con handshake valid/ready (pass 0: valid siempre alto; pass 1: valid con huecos aleatorios).
-- * Cada caso es un flujo SHAKE real (SHAKE256(seed || 0x01)). Las posiciones esperadas salen del
--   modelo Python validado contra hqc128.py.
-- * Comprueba: (1) posiciones en pos_mem, (2) palabras consumidas al terminar cada llamada
--   (alineacion del flujo), (3) que no se piden palabras de mas, (4) wr_data < N siempre,
--   (5) que el bitmap queda limpio (las llamadas siguientes sobre el mismo DUT siguen siendo correctas).
-- Casos (en orden, semillas del modelo): "dup", "plain", "dup_multi", "dup_multi2"
-- Orden de compilacion: position_mem.vhd, samplefxwtmod.vhd, tb_samplefxwtmod.vhd

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_samplefxwtmod is
end entity;

architecture sim of tb_samplefxwtmod is

  constant N      : integer := 17669;
  constant WT     : integer := 75;
  constant NCASES : integer := 4;
  constant NCALLS : integer := 3;
  constant NWORDS : integer := 160;
  constant CLK_P  : time := 10 ns;

  type word_arr   is array (0 to NWORDS-1) of std_logic_vector(63 downto 0);
  type stream_arr is array (0 to NCASES-1) of word_arr;
  type pos_arr    is array (0 to NCALLS*WT-1) of integer;
  type epos_arr   is array (0 to NCASES-1) of pos_arr;
  type cum_arr    is array (0 to NCALLS-1) of integer;
  type ecum_arr   is array (0 to NCASES-1) of cum_arr;

  -- flujo SHAKE por caso (byte 0 del flujo en bits 7:0 de cada palabra)
  constant STREAM : stream_arr := (
    (
      x"1786232BAC71E942",
      x"0CD55270C225038B",
      x"79FBCBF0B3554524",
      x"B325E0857C99D824",
      x"E687914DCBFED3E6",
      x"0581E4F210458D3A",
      x"4AD6D48C9186C4C4",
      x"0E7B72F2DEE4AED8",
      x"4A4CBF88EDAF7512",
      x"6937DB977C8F33A1",
      x"2244BD14F63B9B61",
      x"8CC8F534C3EA4376",
      x"08B24A5C78921F50",
      x"D204B5E029C151AD",
      x"FD0ADAB970378808",
      x"4AB5F1DB8D9EDA9C",
      x"6DEE7EAF52203212",
      x"9EB3304105048C0A",
      x"2F8844E165B18786",
      x"BC16ED5C58F750B8",
      x"ECC52E070954E968",
      x"7B4724B07DD803C3",
      x"0C72EC667B312272",
      x"0B6315ADBED65AAC",
      x"9CA41B666EA3CE58",
      x"AC5584A56A6ED6A3",
      x"B827B5EAB2F22A65",
      x"09E96EA4F0DBD5C2",
      x"C7DE4CE81EB206C5",
      x"66C7B9079C3C5E2C",
      x"7A909DBCD3ADD11B",
      x"D665F20ADF78072C",
      x"FC263F17F1916049",
      x"1ECC2CF6EC32F1D5",
      x"5B14D0D862FD074A",
      x"2A850A26B1E1CF01",
      x"54C621232E851CD4",
      x"52498FE662F89C86",
      x"08C65DF396B3A068",
      x"54B8CC0564F26C9C",
      x"34A3D4AAF4EF0548",
      x"44D5FC03B3EA12E4",
      x"E217E10DDF015A5A",
      x"52B4AA0DCA8164AE",
      x"6E01C38E86603C6D",
      x"D2E7014848D1D0C5",
      x"F05D5A553C3CEAB1",
      x"F9CC4813DD658A5A",
      x"33C2920CD1E9FDD2",
      x"88AF92FF3792A6B8",
      x"2A47629051BEAB1E",
      x"A6F8B13A8E8D503F",
      x"B0E4AD377094955B",
      x"6909063DD864429A",
      x"A0A6BB966C6C2BF9",
      x"04AAD8313869F664",
      x"E2AE92CA0BD83DDF",
      x"6F270211498CEF4B",
      x"2F788234C3851FB1",
      x"D690E0CF6577665E",
      x"3C81518AFC9260F5",
      x"233DF75A9446D6F3",
      x"9C7E7CDFBB4205EE",
      x"9F5661A5E3A708FE",
      x"73F83CEBFCB0FE44",
      x"A15D63DBC4360728",
      x"393D15C57B7E906E",
      x"78C3CA2721C2847E",
      x"1A21E2D0766C1CB5",
      x"A7A41464C62B2E36",
      x"584F880003170E63",
      x"7E783D2F29424F09",
      x"33F12F260C402174",
      x"6BE55C4410F48165",
      x"59B014B43DBFC170",
      x"A1FEDFAF1B3245A5",
      x"176B244CC7121D92",
      x"EAC6A81BB0B8ECC7",
      x"D50A33BE18FB39EF",
      x"73D01941B2A0CB87",
      x"4EEAAE8AFCB5301D",
      x"7895D406991B694B",
      x"603CE65189D14E75",
      x"66046CFADF8DA0B3",
      x"9D11DCB9C8D1387A",
      x"C9379B520452F4D9",
      x"320684A80907CC8D",
      x"175DF8641A390517",
      x"E085109FDD8DDAF1",
      x"DAF18E507540C5B9",
      x"410CB1D58E8C0C80",
      x"28E6DC27D42AFA4F",
      x"93076C026431ECD2",
      x"697145B09F16C626",
      x"AEF572FD79F41FB5",
      x"3BB8B172C093108B",
      x"4893D807D6476D42",
      x"7F72EDE2B97E8303",
      x"24012D9B2B6DB210",
      x"ACE7CDC79D675C27",
      x"364BA355A6C18E74",
      x"5A391D5C592CE91E",
      x"B9FEC812B2B12510",
      x"30B7946502EA6A26",
      x"74047CF91D1DD1D0",
      x"64A82828CCC7A571",
      x"2A3285FC2E1F4A99",
      x"86C046AADF1AC3A6",
      x"086179A5113055F8",
      x"C8BA64E92983DC11",
      x"30A97E61D19244FD",
      x"C2294BADA2C1E191",
      x"CFB67900072C5D89",
      x"90D565A085344BE3",
      x"33E5AF0938B7D3AC",
      x"E716E0CC8C68F6F5",
      x"107350BAADBE59DC",
      x"66946E1ADA32BCC6",
      x"0C2BDF65E46A0806",
      x"2E3FD1421B1DB551",
      x"B0F11EB1F12F9D81",
      x"B957F7F2865E36F7",
      x"48F85532EFD3BEC4",
      x"A2C0BFA4400F2F40",
      x"8C18724A6C11C58A",
      x"5ADD6440847454D5",
      x"7587A038ECE083EE",
      x"A358B769CBE5FC16",
      x"BBCEF4FBC2C6A757",
      x"DFAC67BD5D37AE62",
      x"703284A3C0B96E3E",
      x"1D419EE8AEF9DE3D",
      x"CD408C9B38C0B94F",
      x"E1D839BF0B2A4BAA",
      x"A53A1C9367C147E6",
      x"BA2A899E4CD8C6F0",
      x"34769076FFA3A41D",
      x"56787C6428C6431F",
      x"FAD412E26B80A875",
      x"0CDF53B16150AF48",
      x"B3F2FD6858E5F731",
      x"0849295DB13D13A5",
      x"616E5562AD859B2D",
      x"9D736067682E8553",
      x"D9333F9896A4FAF6",
      x"09B681CF37433D6B",
      x"0CA6FF44D2CC6B81",
      x"D30E6B9C7F55CA45",
      x"134C6E7D74F0DAE3",
      x"6C842DCADDB815D0",
      x"0AAE8196B286FCB6",
      x"EE398E7B79D848DB",
      x"EE776C1FF1447CBC",
      x"AF9A9A821BF7C588",
      x"CDB90147183202FC",
      x"A5624354496E4ECE",
      x"3204C3F2E00DED26",
      x"FEDD0C2A71EBF64A",
      x"4B148BA695029565",
      x"55F2586EBE856DA2"),
    (
      x"224F22F9AEF1E5AB",
      x"8B297D6D6BC97544",
      x"EEA1579FEEF945D8",
      x"D7FBF3BF7075FEBD",
      x"28784113A063DE22",
      x"02152BCE0E5E1FA2",
      x"D6673E1457FC34C0",
      x"3B4D5EC031C7A53F",
      x"63282F4FDD8679F4",
      x"93C0019524542361",
      x"BAD52C353CA92F27",
      x"C5C54DD1AADF4A2D",
      x"1E83382F3987A819",
      x"1D817D609FD32F7A",
      x"AE46C8EC3D5D06C1",
      x"8C4CB811B37A912E",
      x"0B726565CA4CF401",
      x"4DA28A252F832C69",
      x"3CA50A595E26BCA5",
      x"12B2E2F6F7C70EE1",
      x"F06C6B031C395CD5",
      x"D3E2D3A1081600D1",
      x"6B4977E629EDF8EC",
      x"A5B97603AE678507",
      x"E7CD148A54E47265",
      x"FBBB4A9E6E42BF92",
      x"FCD2552704400135",
      x"A9E8F40D8C16D44B",
      x"5406C892CF03B710",
      x"450DA7F32DDD1201",
      x"513A7C188304448B",
      x"94A6D24FB7B26EA8",
      x"40B3FBD0B1542506",
      x"C73AAC3B3F28E2C2",
      x"B3CB15F18E4A7962",
      x"D05346294FE7667A",
      x"23634EBAFC40F512",
      x"CBC6ADC19EAACA6B",
      x"BF346557BD5E7E33",
      x"36433038F0E10056",
      x"CF3DED2BF6FF545B",
      x"D01A3A0B4F24A1B4",
      x"5C356CEFE3C90187",
      x"FDE6A4CF299660D7",
      x"AEDD6CE3F5C82999",
      x"76DCA680FCCAC74F",
      x"BFAB44FFA1B49C6B",
      x"EB57F5CF7CEEA8A1",
      x"188C58E75CAD94F8",
      x"6133932B6AE582D8",
      x"18E195E5858D3AF1",
      x"2E5E05A9948122C9",
      x"4986C0421EA1E8E8",
      x"FC1D7AB076DF1590",
      x"D0A86364219ABB4E",
      x"2CEA73CD0E0E7716",
      x"9239398FBEB95A0B",
      x"537D661F5DE04331",
      x"DF5F520FC64F8B88",
      x"0C8B206C607722E8",
      x"882F5ED653A8F827",
      x"7BDB94C354AAAB6F",
      x"8B83791FCDECD942",
      x"362586C651B783B7",
      x"AB4EBCDC7B7D4AC6",
      x"717597A07BDFFA03",
      x"96CC2C8E3DA03622",
      x"A5E3DD0433415D06",
      x"63C7AE3F5ABB3AF4",
      x"192D701FD377359C",
      x"1AEB741FDB39EEC7",
      x"79F1EFCB5283530E",
      x"B825F35493D3992A",
      x"9A2C618517650076",
      x"60A212E95FC6D25C",
      x"A17B883BFABB03F7",
      x"2B67D4ED58BE5308",
      x"08853359436F154C",
      x"A16FEB19407D6410",
      x"E94946B72C8E85B8",
      x"A2F1BE6B2B394D4C",
      x"F3AD72545884E541",
      x"C957AD28F37BD7B4",
      x"7B16BBECD8A01A7E",
      x"EC1344A221C8DEE0",
      x"BEFB92ADF356E690",
      x"77B565D2440ECBE1",
      x"71C08C1E77313A10",
      x"94ABCE20C2DAFD67",
      x"6FE481A76B0545D3",
      x"82DFA7E6E6D1C8FA",
      x"38C497E3DF25DD9A",
      x"5AA9DEA590D8DB7A",
      x"8641C12BC6E31E4E",
      x"5826F5529CA58946",
      x"135F3D5AD8322FCE",
      x"B166F32C00BB006E",
      x"C5006B0061EF7E8B",
      x"29E4103EAD81727D",
      x"3711D070AA6F46ED",
      x"4AAB8786D8119495",
      x"A1E776B0A6573DFD",
      x"A253029947F217CC",
      x"4CF868CF84022024",
      x"1708FDF745E1EF0D",
      x"FCC460C72A182C27",
      x"4771E2B90B947790",
      x"49986DF550436F7E",
      x"90CDF9F06F13F59F",
      x"E3DDF3028D9F83A5",
      x"FFE1036797511CCD",
      x"C0AD32C05F79021D",
      x"6012F6D628FA6FCD",
      x"AD4198360803C62A",
      x"8AB8F389A1F7B0AF",
      x"192DE21348E9A045",
      x"966EE9CFC8644166",
      x"13DE44BFCD029BD3",
      x"A8885965D8890A80",
      x"03F9ABC28FE6BB16",
      x"1A2AFC8400F01C27",
      x"819A255A8A5F7CBD",
      x"489DDD0D9E53DB82",
      x"D57A05C93CF512CD",
      x"15026F5432F36C86",
      x"E8275E92FD1FD46B",
      x"C2C1434371FF237A",
      x"260180580616138B",
      x"56E546D26B9ED998",
      x"544249DB5741FC2E",
      x"30A1696AADF57FEC",
      x"3EEB749CD532BECB",
      x"EBED6564B5C82E11",
      x"AEFAF409535C7DDD",
      x"494B8ED554091659",
      x"CCC796325C1BDC0A",
      x"90A37A9EF68FD58B",
      x"0F35B05B58E92BCE",
      x"5B9F4AFA3578830A",
      x"7CEA2603A4B428DD",
      x"4F742FCFB1EC58AA",
      x"EEBBDD56C512B6A1",
      x"970EA3C097ABC02D",
      x"DDF692B0F76ECE60",
      x"58CCCBE4489EB22C",
      x"48D9668F11E33E87",
      x"0F948122FC1F456D",
      x"00DA130B78AAA79E",
      x"A8EA430364B103A8",
      x"9521087BFD18D0EC",
      x"FA0E80FCBFB981ED",
      x"ED9ADB53F6F67543",
      x"7F6A8D1B66E73DF3",
      x"EFC262CD3E0F3C47",
      x"A2E5720BD2E6895E",
      x"4C3153BD0355A46A",
      x"CA2769A4D3827C10",
      x"F80D3908E0D2DA3E",
      x"7A74144DF017BC2E",
      x"39E197AAEDF76D3F"),
    (
      x"6910687009CE3473",
      x"C0DB4A72F13623A8",
      x"B61F48EA5BCD9379",
      x"E944C5B9F2361746",
      x"8AD2F421B2888D20",
      x"FF91B4DBD150EB79",
      x"5CC9BDCBD10C8322",
      x"C485FE725A4C5077",
      x"A26671C4330368E4",
      x"BEC1EC13C5D09AF7",
      x"C13B4FACA25E5A1D",
      x"9E828EC9A7EB0263",
      x"1DAFF69D73F8A4CA",
      x"E50A8397E8270841",
      x"2DEEBF748FE9AC76",
      x"F42BBC7E10ED853C",
      x"9229DF8E96F5A7D0",
      x"3F03D5FF1FDE5B31",
      x"459AFE97BF803874",
      x"E8D3025FF7597C67",
      x"5F0CEF311C31DCDD",
      x"44BD0A7C8148725F",
      x"55F83D13C1D1B935",
      x"524C362AE4B3C74F",
      x"AA7318284F9CD610",
      x"259B903E9216BBF7",
      x"4E58F6EAC69FB1EE",
      x"CFF9930AFE72E4F6",
      x"7A966C9FB118821F",
      x"E57ADD765547C96A",
      x"BB30CA8651E57920",
      x"4F645F0F98E0451C",
      x"282356BAE4995625",
      x"1133219217684663",
      x"9A11DF5744F51B0D",
      x"D9919B07C5858F96",
      x"7BB65C6014C627A3",
      x"FFD2A86C170A14EB",
      x"AC719CCF360A0D98",
      x"78A6893E9FFF4A4A",
      x"8CA5A46235FEFB1D",
      x"28478FA685D5552F",
      x"E536AB12B85461A7",
      x"CD5153194E5BE655",
      x"27D5A86EDFA626BA",
      x"18B8524D1082AC5B",
      x"BA527044A9A49378",
      x"2BF6A4427DCC1898",
      x"C7A1733E52E5BF55",
      x"CE8D5840AA74B56C",
      x"DE7ECE9C76680A44",
      x"78ED2FF79AFB0467",
      x"A26A582EBE7BC48F",
      x"8BBD8A553BCCCE7F",
      x"B73083E8FE3B309D",
      x"C1E6CEF2DBB70AC3",
      x"D0DD399AF8A0AFC9",
      x"4FA7CC7DBC1F5336",
      x"632EF63BF5732208",
      x"E6B414AACC3802A3",
      x"DE82C39E2507FD08",
      x"14A6A0A5002BD94B",
      x"F5CE37996FE89DE6",
      x"5202462C0861C3E5",
      x"8A520D7DD1FA62E2",
      x"B20938F488DA8D40",
      x"AF9A9E184D83D2F0",
      x"6DE5A31A967FC68B",
      x"49CBF65270BFAC47",
      x"62F3DD2CC51FE3A7",
      x"49BA86AB93FEAE6E",
      x"925D8E85DCFD13B1",
      x"4FD9D776869156B1",
      x"EDA0914BDAAEDDC2",
      x"8A79AAA12A5C632A",
      x"BF303175A465C9C0",
      x"E60B72CC56FEFF95",
      x"DB545CC251D2B085",
      x"D88159C91B979AC3",
      x"3BFEB397DD84D48F",
      x"389D0B04CED89824",
      x"7E21BAB5FAC7477E",
      x"5F58D510A35FD709",
      x"007372748C8CDD6E",
      x"B4821B51694976D4",
      x"A8DC8EDBF47BC877",
      x"22D4FA55C36146BF",
      x"3F181094A4197C47",
      x"4697470F89F13D06",
      x"BFF2EB058810BC18",
      x"DAB8D88C4083808A",
      x"E36EFB0EC8F055AB",
      x"2503AB39D89A5A1B",
      x"58CC47BCDD95B5DB",
      x"FE23BBF4FEE74E65",
      x"D1DF4D315B92B0DB",
      x"94A86170716A1748",
      x"E8279C0245B1538F",
      x"E6F9BB632BD6BB3B",
      x"D4E97B02C26051C6",
      x"6DA3D3FD4960B136",
      x"D7987451E5EA69D0",
      x"1474E5070C07FDBF",
      x"5EE1B6B8B17D8C82",
      x"0A4C85B6A840EC06",
      x"19F2A504B1790E16",
      x"6BE67B4DC7B26DBB",
      x"609E8EC8C7DFE4DE",
      x"C23510A390BF1E80",
      x"B55CAC2C1C57CE75",
      x"ADD7726C8EA098CA",
      x"A55D8167659C24C4",
      x"4BAE2E51A24B8037",
      x"A636B26C9D995009",
      x"A23ADB6FA6DED8CE",
      x"73C2FB030242CB12",
      x"0EF377860DA806A3",
      x"6B8E6B403FE21070",
      x"0AD31720874DF4C3",
      x"3AF590A7DE63FE2C",
      x"1D811DC2983D3916",
      x"B8B8BB23EFFAAA15",
      x"6177F051EFA268AA",
      x"93A14E5129BC5F83",
      x"3EF8511863AA948E",
      x"D31360FA4E71D6D8",
      x"B0F8E8541C588552",
      x"E653148B8A7CCFE1",
      x"8AAC48EECAD099C6",
      x"511C9AC74AAD9A50",
      x"F55E28A9F3A4D4FA",
      x"E52ADBC80181C848",
      x"26CB6E429486FDEE",
      x"BD5E6A1CB15B2215",
      x"A652DA81209FCCF4",
      x"4159D2660898492F",
      x"FB7EE4F2DD88133E",
      x"7E6684DFA49D10D8",
      x"2665F1840560C764",
      x"F5E6F71637F2970A",
      x"CE578574EF73E10B",
      x"0F7E1E4ADFB4086A",
      x"8B22B64AC8C89F93",
      x"5465318426719D58",
      x"6E0CB6BB0FE90F28",
      x"BA85043586212F92",
      x"22E36D9E6DF75C92",
      x"63A324D108560A70",
      x"BB889DEEF8340FAE",
      x"4E2AE20EB8E458CD",
      x"633988A0CCA8B94C",
      x"8E67080AAE34A15F",
      x"38AAE13CD233BC52",
      x"B4848A7F10DB0F0F",
      x"FE36DDCD6A33CFD5",
      x"98C82456C5F89B51",
      x"AB1CD5B9BE5D1FAF",
      x"ECB8305F4F4CD016",
      x"940FCA21AB7C0EE0",
      x"BA3A7E0CE9FFABB2"),
    (
      x"163810437D886392",
      x"ED888008CCEA98F6",
      x"D07DA9CC478DF108",
      x"915F3BF7C3E869BE",
      x"768C875F35AADE88",
      x"D1ADF740F6692099",
      x"146C1FC102BCAFEC",
      x"8864F50DE54E1945",
      x"50F42EE082850323",
      x"8871A5B0D291B0E1",
      x"82D854F7F3E675F7",
      x"CA5EF24FB4A38F25",
      x"5A7127566E921824",
      x"41BC8514479F3EC2",
      x"984BAD69EC71D87A",
      x"1C7C17B711B2B50E",
      x"7033F804F14A16A3",
      x"F424FBFE0B2FBC2B",
      x"03E9F38A8B4DB1C5",
      x"842B00951A61ED45",
      x"DB45B208E1E5E522",
      x"3BD83B5467F211CA",
      x"1A9DF0C2C8554AE5",
      x"FEA9C55E294C2BB1",
      x"256D7D33468B2948",
      x"A2DAEF9A7202B5F0",
      x"C5154BB234E86F34",
      x"87464EF69FC807C7",
      x"C26A20D46A1B05FD",
      x"59D464BADF91AEF2",
      x"40B4A68128D40308",
      x"48DC81B23371F8E0",
      x"BC1CC4DC43157A62",
      x"AA27EA4DA8DA801C",
      x"A29A7E386CB46D15",
      x"97A1B86A66BAF25E",
      x"1A1845D1A8334BBD",
      x"AECA488874AE366F",
      x"BE65290DD62F8E84",
      x"3379A5DE972D89A5",
      x"4D9780DDBBA0ADC5",
      x"26735205B1D82E6E",
      x"262FBB0A5F0B54CF",
      x"9263E2875E54A488",
      x"65259D4E5CB2E724",
      x"4E7EF84B2532183D",
      x"D7AF58604CFF5ED5",
      x"7BAB3D1974B7822D",
      x"4416BEB094C39EA1",
      x"580CC9A11DB46A45",
      x"9728F23F011E84FB",
      x"90355DD4417C1431",
      x"08FEF078C92F860B",
      x"2F1A6738477DD508",
      x"21B2C7B14C1AB817",
      x"0F64B4DCC81CA7FB",
      x"9DBE5DA096FAE245",
      x"4E913272F57F967C",
      x"22B9F82C0E476495",
      x"EBB1078DA49D2856",
      x"E7296C18241A1751",
      x"2F9DA100181EA291",
      x"5755BE4CD6207582",
      x"413455EC01B06ACB",
      x"57D8620C1B2760D7",
      x"05CCDF79DCB053AF",
      x"21A070C3B3C9431E",
      x"6E0771760B3CAD3A",
      x"F5D2C0B264B66123",
      x"CD7C996BB04387AA",
      x"8C71A0E5E96EA537",
      x"D7084BEB789CB175",
      x"0AEC6E40E2C0F2D3",
      x"5206D4E07FC12744",
      x"8DD9993DB5632E1E",
      x"F76B6D298953E7A3",
      x"B85BC1266E1C3F65",
      x"037396C0204DF5C9",
      x"1D60363C918CDE9D",
      x"33B62B9ED813B4E0",
      x"A1010CFF480A8DE9",
      x"35AFF51E5A82C5DB",
      x"BE44B2E10DE02F90",
      x"DBD0EE1F7ABEB5AE",
      x"AC0B73C2E4D16E15",
      x"7AEB42E00BDE1FC6",
      x"561BFCDE5469006D",
      x"C380584108BF5967",
      x"A92E727DA5B38372",
      x"C75DEBA437FB8390",
      x"B236C2B014E6467B",
      x"FCA0121AB30BFC31",
      x"BC1C676F3C7C57EE",
      x"DEAFD9B9658ACE9B",
      x"876F84721C566342",
      x"E41825999AD1B220",
      x"5B77712AB8D3463F",
      x"4BF68E1EB4C23F68",
      x"EC3AF2BEBB275201",
      x"5D598C273D9BCAF7",
      x"2F89D4B9BA7E08E7",
      x"BB2B21C0C5351F85",
      x"5A3FB6AF282566A9",
      x"E7BC8498C1997CF6",
      x"BD7CE12C93B454EA",
      x"5918F035C197AF24",
      x"AB15145538AA62FD",
      x"7A618A38E430853C",
      x"BE0DBCD32607C936",
      x"C047B261801E1671",
      x"E73D33428B97BE2F",
      x"3ECE99FD0CFEB9FF",
      x"E1CE57C8D2260AE9",
      x"C77C68974F374F2C",
      x"E05FBFBBA8362965",
      x"F6402C5CA56F3281",
      x"14585BE534CD3C11",
      x"31E61E46478F1E80",
      x"562096EAB4CE2EAD",
      x"4CE030D9AC6F4D1A",
      x"A30E5107680E971E",
      x"2AE73969F33C3D87",
      x"FFEE7170C9C5BECB",
      x"4C865058858EEF27",
      x"59C2C75258039A3C",
      x"F76D84366CAA84B8",
      x"F66BFD335C55E04B",
      x"A3DE75B089E7477B",
      x"CD0FBCDA94D7F41B",
      x"F290088E8DA80200",
      x"50C0753FB8699B3F",
      x"7EBBA67393B6D987",
      x"F3A39DE90D21AB07",
      x"5E04FD90B41C51F9",
      x"B525E2D6C3E1B2E2",
      x"42BE54CAD152C23E",
      x"40AA3A6D2D67E307",
      x"5D234EE74291C1FB",
      x"222AB5ABAA42F72C",
      x"254B9AD5F44245B8",
      x"6F3AF28C917EF18D",
      x"F153FA40AD186CE0",
      x"1D9C3D22AF66C4A1",
      x"E061797D50035842",
      x"CFDA0FF1025DB9BF",
      x"C5111D13C9E44E3F",
      x"0D37CF6D3118EC1C",
      x"4A1F72D642974D0D",
      x"DB558DCD16D950F7",
      x"5C121AF7F2375B5E",
      x"ACFF8ECFE1E3DC2A",
      x"CD6B762FBDDE2F34",
      x"E4D1BF38F24529E8",
      x"BA5B2D683387C33F",
      x"268D93EDB8A8C038",
      x"4200743A9200D938",
      x"FF6A3BAC6F0D595D",
      x"B206718C93087376",
      x"7BF0C3B2DD8125EE",
      x"B490BE9A2B8F6F68"));

  -- posiciones esperadas: NCALLS bloques de WT (indice = direccion de pos_mem)
  constant EXP_POS : epos_arr := (
    (
      11902, 1624, 13400, 888, 12378, 8421, 8602, 7, 14081, 15911, 1132, 390, 10049, 5174, 15385,
      1013, 16406, 5140, 8606, 7273, 16995, 2383, 13527, 9727, 8334, 624, 2903, 14500, 7760, 17465,
      9787, 5178, 5690, 7606, 379, 10966, 7040, 3310, 6165, 12992, 682, 16344, 8707, 8530, 8525,
      902, 13183, 830, 7663, 10830, 7375, 11911, 12366, 12725, 16627, 736, 2167, 13807, 10805, 7129,
      14620, 8491, 15431, 14807, 16676, 17404, 16307, 2184, 6873, 6330, 12298, 2993, 3269, 5899, 6876,
      10401, 606, 6968, 5849, 16905, 3637, 12419, 4756, 15392, 15605, 13978, 5715, 9280, 7600, 5035,
      14559, 4169, 16590, 15283, 17241, 14491, 3589, 3852, 9444, 5658, 2938, 9850, 11533, 7785, 12218,
      14939, 7267, 7501, 11100, 3920, 356, 851, 15649, 5103, 7693, 13504, 3309, 7028, 14816, 17432,
      4210, 10253, 2472, 12937, 10820, 15718, 11016, 17441, 8033, 13555, 11157, 8552, 3994, 2380, 8366,
      8205, 1858, 13691, 11592, 276, 6137, 2903, 8762, 910, 3640, 1235, 7488, 4316, 6237, 1943,
      13739, 1617, 12197, 16204, 1727, 14704, 12330, 7997, 17441, 5453, 10571, 8328, 9517, 6650, 15431,
      7050, 13863, 10847, 316, 13891, 642, 3469, 1829, 1633, 15294, 15499, 8106, 15115, 9850, 4511,
      14648, 2849, 6934, 10161, 10993, 7298, 8436, 12087, 13300, 4151, 14795, 5038, 12814, 8818, 3033,
      2523, 10881, 11949, 11526, 3786, 6187, 6260, 12348, 12851, 254, 3406, 2059, 8038, 14145, 6983,
      3232, 2963, 15406, 9330, 1246, 641, 2920, 13868, 14476, 3414, 11258, 13418, 565, 14350, 9229),
    (
      12074, 2368, 7440, 9606, 16494, 16470, 7765, 14908, 11073, 2800, 1001, 154, 6080, 14800, 3447,
      4104, 15291, 6854, 2522, 10205, 4202, 12900, 11800, 13655, 3989, 2127, 11040, 2060, 4256, 12037,
      12396, 9697, 13969, 821, 3306, 5382, 6521, 4213, 17102, 1326, 1983, 16596, 598, 14631, 2930,
      7431, 12051, 11454, 5891, 16003, 7638, 17375, 344, 17450, 9693, 11745, 14298, 5837, 3213, 4809,
      9072, 5647, 12696, 10286, 12258, 4514, 4408, 13765, 9851, 12429, 5563, 14391, 17411, 2505, 10979,
      13070, 13197, 16625, 3747, 17047, 14304, 5466, 14364, 15722, 6369, 2878, 17524, 16964, 12073, 17447,
      8211, 11166, 13233, 8631, 16244, 6409, 1713, 7390, 6723, 9229, 1739, 10260, 3222, 2138, 5095,
      8220, 17401, 2347, 14407, 1002, 3128, 13172, 10108, 6503, 5788, 13696, 15422, 6684, 906, 5803,
      9420, 5874, 8572, 14222, 9651, 5674, 3777, 8550, 11841, 8577, 7861, 4295, 10431, 3584, 11470,
      6300, 6923, 14606, 1794, 15140, 1916, 5739, 8451, 10231, 12729, 1678, 10669, 6655, 6715, 17306,
      6125, 2996, 4655, 590, 4454, 11144, 3080, 16101, 2989, 11249, 6116, 16819, 16805, 13899, 14953,
      8503, 2345, 16295, 16796, 13186, 4712, 8273, 8238, 7863, 13454, 10271, 7401, 7737, 15933, 9047,
      15405, 3942, 10011, 6278, 13734, 9282, 10825, 6108, 14927, 1373, 90, 12256, 6785, 13606, 11989,
      2928, 11778, 3837, 14920, 5188, 11498, 11193, 5003, 11222, 9137, 5350, 4863, 1641, 2953, 17446,
      856, 4975, 5582, 5124, 7702, 10022, 9804, 15734, 10471, 17660, 6633, 13316, 2888, 6676, 624),
    (
      676, 7252, 16648, 13311, 6338, 12571, 16717, 16100, 12324, 9585, 14448, 17639, 14430, 6412, 6241,
      13567, 3533, 11214, 13657, 13170, 11213, 13341, 11597, 10949, 8017, 2071, 16025, 15811, 9945, 3194,
      1196, 16853, 10432, 10102, 2229, 4375, 13226, 4831, 17073, 16072, 1981, 6586, 8943, 4775, 13387,
      5963, 15789, 5712, 5527, 11780, 10104, 2639, 13720, 5444, 17562, 14364, 12240, 8490, 5924, 15844,
      5693, 12936, 10576, 5523, 15784, 2825, 1675, 1249, 4809, 10661, 13648, 15027, 1499, 8576, 1657,
      0, 11902, 11043, 8328, 3729, 9709, 9239, 2785, 12724, 15821, 5415, 14173, 15437, 2760, 1152,
      1719, 11714, 12864, 8691, 3050, 5735, 13783, 11772, 14260, 8185, 15359, 10706, 8360, 13154, 11220,
      4150, 9658, 17547, 12653, 15169, 13391, 17161, 14422, 12994, 5524, 16942, 6870, 14103, 15927, 2593,
      15363, 57, 1468, 7750, 16967, 626, 5694, 14501, 9571, 9470, 12304, 5389, 12138, 10411, 7618,
      7815, 5136, 13619, 6868, 10241, 5134, 15261, 10130, 9320, 5558, 15103, 16406, 2983, 9591, 11373,
      6004, 15877, 5648, 15138, 1907, 14943, 15289, 4146, 14277, 3914, 17308, 8711, 11280, 6588, 9707,
      46, 7276, 12463, 16874, 11661, 13489, 2422, 11333, 4372, 9531, 4890, 9403, 13254, 4473, 15100,
      13875, 15700, 14954, 2582, 15298, 6151, 17593, 17540, 6344, 14492, 7850, 10277, 4840, 16027, 3062,
      15946, 13426, 14702, 5098, 7595, 15873, 14888, 879, 1460, 54, 6583, 11631, 765, 12266, 1843,
      13796, 7482, 13808, 6707, 10018, 13419, 2014, 12537, 9874, 12020, 7055, 11438, 11227, 5274, 10905),
    (
      8664, 1534, 14143, 16394, 4941, 14390, 13522, 10036, 3710, 8187, 17007, 14473, 200, 1421, 15827,
      9420, 9016, 5599, 14536, 9426, 16834, 9041, 12474, 13972, 7645, 6258, 4962, 4557, 16321, 10523,
      1249, 1993, 16655, 7762, 804, 16852, 9631, 306, 1854, 9141, 15596, 15139, 7199, 4163, 13836,
      1877, 2888, 17576, 4903, 2625, 7896, 11258, 3692, 13614, 11048, 9362, 7356, 13432, 15437, 6238,
      2868, 4511, 3600, 5073, 4677, 13000, 11676, 11766, 7541, 11247, 7132, 10494, 11633, 1866, 8093,
      14783, 13141, 2, 3555, 12951, 5358, 12276, 2659, 6564, 2643, 6516, 10108, 6405, 6988, 2579,
      5428, 5325, 14889, 8065, 8545, 10276, 4714, 2069, 6092, 101, 10443, 4539, 9964, 13891, 648,
      4955, 3276, 5275, 2354, 13819, 1095, 10435, 10901, 16945, 5449, 1023, 2432, 11376, 16270, 2529,
      15959, 1706, 3324, 14786, 6060, 166, 4538, 1920, 6097, 15239, 454, 12425, 2370, 831, 7627,
      6987, 16969, 12184, 14195, 16117, 9722, 8359, 14852, 15658, 819, 8852, 5709, 12540, 9822, 9512,
      7599, 12724, 2231, 241, 10047, 2031, 14914, 3574, 4978, 11115, 6253, 3714, 969, 13135, 14,
      15173, 15794, 11880, 836, 8493, 5839, 5957, 624, 13498, 11445, 11685, 3884, 13766, 1468, 12309,
      12366, 17436, 4199, 12992, 7028, 15374, 1987, 9365, 10700, 15747, 12767, 6339, 12488, 5273, 12929,
      16307, 4287, 6472, 12884, 3320, 13622, 12931, 2814, 6263, 54, 15999, 10218, 13093, 13375, 6187,
      3957, 11828, 15756, 8479, 2679, 13134, 8875, 13287, 9665, 15966, 963, 4388, 14517, 15593, 5518));

  -- palabras acumuladas que deben haberse consumido al terminar cada llamada
  constant EXP_WORDS : ecum_arr := (
    (38, 76, 114),
    (38, 76, 114),
    (38, 76, 114),
    (38, 76, 114));

  signal clk, rst, start : std_logic := '0';
  signal shake_din   : std_logic_vector(63 downto 0);
  signal shake_valid : std_logic := '0';
  signal shake_ready : std_logic;
  signal wr_en       : std_logic;
  signal wr_addr     : unsigned(6 downto 0);
  signal wr_data     : unsigned(14 downto 0);
  signal samp_rd_addr: unsigned(6 downto 0);
  signal tb_rd_addr  : unsigned(6 downto 0) := (others => '0');
  signal mem_rd_addr : unsigned(6 downto 0);
  signal mem_dout    : unsigned(14 downto 0);
  signal sample_done : std_logic;
  signal sampling    : std_logic := '0';

  signal case_sel  : integer range 0 to NCASES-1 := 0;
  signal load      : std_logic := '0';
  signal rand_mode : std_logic := '0';
  signal wp        : integer range 0 to NWORDS := 0;   -- palabras entregadas al DUT
  signal finished  : boolean := false;

begin

  clk <= not clk after CLK_P/2 when not finished;

  -- ===== DUT + memoria =====
  dut : entity work.samplefxwtmod
    port map(
      clk => clk, rst => rst, start => start,
      shake_din => shake_din, shake_valid => shake_valid, shake_ready => shake_ready,
      wr_en => wr_en, wr_addr => wr_addr, wr_data => wr_data,
      rd_addr => samp_rd_addr, rd_data => mem_dout,
      sample_done => sample_done);

  mem : entity work.position_mem
    generic map(DATA_WIDTH => 15, ADDR_WIDTH => 7)
    port map(clk => clk, we => wr_en, wr_addr => wr_addr, din => wr_data,
             rd_addr => mem_rd_addr, dout => mem_dout);

  -- mux de lectura: sampler mientras trabaja, testbench (consumidor) despues
  mem_rd_addr <= samp_rd_addr when sampling = '1' else tb_rd_addr;

  -- ===== modelo de SHAKE: palabra actual en shake_din, valid/ready =====
  shake_din <= STREAM(case_sel)(wp) when wp < NWORDS else (others => '0');

  shake_model : process(clk)
    variable lfsr : unsigned(15 downto 0) := x"ACE1";
    variable xfer : boolean;
    variable nxt  : integer;
  begin
    if rising_edge(clk) then
      lfsr := lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
      if load = '1' then
        wp          <= 0;
        shake_valid <= '0';
      else
        xfer := (shake_valid = '1' and shake_ready = '1');
        nxt  := wp;
        if xfer then
          nxt := wp + 1;
          wp  <= nxt;
        end if;
        -- una vez que valid sube, se mantiene hasta la transferencia
        if shake_valid = '0' or xfer then
          if nxt < NWORDS and (rand_mode = '0' or lfsr(0) = '1' or lfsr(1) = '1') then
            shake_valid <= '1';
          else
            shake_valid <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  -- ===== monitor: ninguna posicion escrita puede ser >= N =====
  monitor : process(clk)
  begin
    if rising_edge(clk) then
      if wr_en = '1' then
        assert wr_data < to_unsigned(N, 15)
          report "wr_data fuera de rango: " & integer'image(to_integer(wr_data)) severity error;
        assert wr_addr < to_unsigned(WT, 7)
          report "wr_addr fuera de rango: " & integer'image(to_integer(wr_addr)) severity error;
      end if;
    end if;
  end process;

  -- ===== estimulos y comprobaciones =====
  stim : process
    variable errors : integer := 0;
    variable v      : integer;
    variable e      : integer;

    procedure tick(n : integer) is
    begin
      for q in 1 to n loop
        wait until rising_edge(clk);
      end loop;
    end procedure;
  begin
    rst <= '1';
    tick(3);
    rst <= '0';
    tick(2);

    for pass in 0 to 1 loop
      if pass = 1 then
        rand_mode <= '1';           -- valid con huecos aleatorios
        rst <= '1'; tick(2); rst <= '0'; tick(2);   -- reset entre pasadas
      end if;

      for c in 0 to NCASES-1 loop
        case_sel <= c;
        load <= '1'; tick(1); load <= '0'; tick(1);

        for call in 0 to NCALLS-1 loop
          sampling <= '1';
          start <= '1'; tick(1); start <= '0';

          wait until sample_done = '1' for 500 us;
          if sample_done /= '1' then
            report "TIMEOUT pass " & integer'image(pass) & " caso " & integer'image(c) &
                   " llamada " & integer'image(call) severity error;
            finished <= true;
            wait;
          end if;
          sampling <= '0';
          tick(8);

          -- alineacion del flujo SHAKE
          if wp /= EXP_WORDS(c)(call) then
            report "pass " & integer'image(pass) & " caso " & integer'image(c) & " llamada " &
                   integer'image(call) & ": palabras consumidas = " & integer'image(wp) &
                   ", esperadas = " & integer'image(EXP_WORDS(c)(call)) severity error;
            errors := errors + 1;
          end if;

          -- contenido de pos_mem (lectura como consumidor)
          for a in 0 to WT-1 loop
            tb_rd_addr <= to_unsigned(a, 7);
            wait until rising_edge(clk);
            wait for 1 ns;
            v := to_integer(mem_dout);
            e := EXP_POS(c)(call*WT + a);
            if v /= e then
              report "pass " & integer'image(pass) & " caso " & integer'image(c) & " llamada " &
                     integer'image(call) & " pos_mem[" & integer'image(a) & "] = " &
                     integer'image(v) & ", esperado " & integer'image(e) severity error;
              errors := errors + 1;
            end if;
          end loop;
        end loop;
      end loop;
    end loop;

    if errors = 0 then
      report "tb_samplefxwtmod: TODAS LAS PRUEBAS OK" severity note;
    else
      report "tb_samplefxwtmod: FALLO, errores = " & integer'image(errors) severity error;
    end if;
    finished <= true;
    wait;
  end process;

end architecture;
