-- Testbench de sample_vect. Vectores generados con hqc128.py (referencia).
-- Dos llamadas encadenadas sobre un mismo flujo; se comprueba la BRAM completa
-- (incluido el enmascarado del ultimo byte) y las palabras consumidas (277 por llamada, memoria de 64 bits).
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_sample_vect is
end tb_sample_vect;

architecture sim of tb_sample_vect is

  constant K     : integer := 2;
  constant TOTAL : integer := 558;
  constant W64   : integer := 277;

  type word_array is array (0 to TOTAL-1) of std_logic_vector(63 downto 0);
  type mem_array  is array (0 to W64-1) of std_logic_vector(63 downto 0);
  type mem_matrix is array (0 to K-1, 0 to W64-1) of std_logic_vector(63 downto 0);
  type cum_array  is array (0 to K-1) of integer;

  constant STREAM : word_array := (
    x"c7a0d2d420b83db9", x"438467b4ad5a6292", x"0319338e1c095876", x"08554148ac90d912",
    x"4c2c8046ac706b15", x"4fc28752904de87d", x"f4081e34273a9477", x"e4b2a5f1a2daf3a1",
    x"3e9263f1aed966ea", x"dd6bc53f54013627", x"5c40e9c8b8df4883", x"d74251166c6189bd",
    x"150bf5882b0a140a", x"00722872803ed457", x"9fed20eff2984618", x"0017ddcd4a6c7324",
    x"026341cea43fc665", x"e9d2ab521fa30bc4", x"e7dfa71331b35e03", x"072cb55635ea4ca2",
    x"a0b3a460025a8c88", x"6a85b396125a8e27", x"96ca48f188ac8787", x"794ec881aa974372",
    x"7b6a5d4738881ed0", x"9d71a435d5092d72", x"3190ef87ef71b16e", x"024806df09af9cfc",
    x"ec8219bf4aae1453", x"c72d15e0e948b512", x"21ca4b9e387899c9", x"f6e73e4fdbb3bffa",
    x"f64bb840fd1d7379", x"764504100bfacccc", x"9797c1d5e1b1bf7c", x"1fc6843d96ecb8ae",
    x"210a008214ad9ad0", x"188ba781ddb44a52", x"b193de0b0b5ecda1", x"1700435caf32aada",
    x"53ee5e5985d5b99c", x"d2e890fe84f444c0", x"7123c3c328da7bda", x"e83c6108eecffb94",
    x"73f3922f11f581e3", x"541f029650900c15", x"be8f997be273f7c6", x"b40bb70e4d7b693e",
    x"6cdc9f101959b500", x"45f395433d92904b", x"f933b3d086e223fc", x"4b5745b59431fd2a",
    x"16cb2e2efe8dacbe", x"0cee5752a1487b78", x"f5e57c5b9d6a3b79", x"d03cf25c36c8332b",
    x"bb7a7db6a4e1de55", x"29d11f4f1d5b8e78", x"375a485ec8cd0dc3", x"e2c41447f43840b8",
    x"927ccc2adc37ee18", x"00481f26927f792d", x"0fd8969ea2ba6731", x"16b0ed13d707808b",
    x"0e397b75e4b0ec33", x"250f3985d77f9630", x"b718cb80e08fd781", x"3cd757eb596d1109",
    x"e0bd186f55b7882c", x"a1554eb801fd3192", x"3c322022d6e835e8", x"37d909af296c18e8",
    x"adcd8927d53f2fe0", x"d519bfed475f2d96", x"532eb8bed1cb004c", x"1d79ee251ab7cc4d",
    x"f34f1cbeb85707cf", x"6eff2a73a6557518", x"fe479e151ee15b09", x"0e82e4e44a25b40d",
    x"8089abda332e56dc", x"0048c92db922754e", x"42bcff9d2a83bef3", x"acc93647d4ba4be5",
    x"56bf1ca9fc1227d5", x"d2775a3f69b16540", x"5bc32d247a758bde", x"66056ad8251f42a7",
    x"50cdbd7b361b93d6", x"0c1110ca13144161", x"ccc8cb83bc7c8d7f", x"50fc3e230f6f09c4",
    x"babc2811fff4b745", x"50d9908c18cee9ba", x"c54867bcc2ebd693", x"db233e4cf20e43b5",
    x"7f1699e848ef4169", x"551f6761b95068ef", x"b0cedcdd8c89f271", x"4f8d6a7009ba8966",
    x"0acbdd25d8bf786a", x"ffcd746fcd84ee60", x"47b55ae5a8dcc673", x"1c4dccfe1d9395e2",
    x"b32b04c724d6f3cd", x"50a7cd5ae9422834", x"83c6cfc9ceb3ddd4", x"89f5a46e999deb1c",
    x"9ce339705b6ae848", x"2c87cc0f3e7b5852", x"4249eee03e622c6c", x"fe0b21499e84f3d9",
    x"64beaeb3e9bb0f8f", x"986685f766cda8ae", x"128df840531bd4d7", x"c652f9bb2957e90f",
    x"07918bff091fcc49", x"73aa96aa854671ae", x"5ba470969a565bc6", x"7b93c143022e4033",
    x"a403b9c621c32b57", x"c9fcd8a20adb8ea6", x"b608d581578b87ff", x"dc964229f388f821",
    x"c8e1b94a0a708449", x"e8bc17c3003ab699", x"3fee89886ec773b8", x"fb60fae9fec6d5f3",
    x"8207ae3cf15d742f", x"1430c82a6c7cb115", x"bf8915b84b1137f8", x"1eb22e703bb134e7",
    x"f71495b0447f39ca", x"0d1d1c2ce36a433f", x"7ca421d2b2cf2a92", x"d9666864e960389c",
    x"fb7741e1a9452ce7", x"b12699a132528c9a", x"18ca558845a3f946", x"c0c8f31d421d6a2d",
    x"7c6b9b2c9ea33e4a", x"696a2431804ffb42", x"6a1ca56d25289190", x"d5fb4c807b275656",
    x"04f112e713777c8e", x"03bfb19878778db5", x"e23bf6dec5b50698", x"3cb1debec3912278",
    x"4aa2e9501090bc28", x"29b5a7b714e55b48", x"4e712eb696d27e6c", x"60703c26ccbe64e4",
    x"703ae96aa4c1221a", x"c478a591a99ce6c6", x"e7ec493071ecf23c", x"053585d6b967b905",
    x"db818489eb666c94", x"6091064ef953efc9", x"f68f9093092f1f2d", x"9eb2258c6cbacd2b",
    x"252ca85129a23485", x"da8f99d25c7d0e30", x"a93b2ac37ce4b63e", x"0184a25316410162",
    x"5477acf0ba0913d5", x"e5f385ec671959ad", x"78b4897457f0ae74", x"86b5ec3c056ab56e",
    x"254df425f0254225", x"4c94b10198f37430", x"9936b5a13b4b4402", x"3010ac72bc68c444",
    x"cf90665ca81b2857", x"5572b2217b18cccc", x"ef6b3feba036f775", x"04ed4d294646fdfd",
    x"0d3ef79de3bbfb7c", x"f31c04f1071bb8ae", x"133e925b114b0bcc", x"ddf46e512532f0cc",
    x"6cadafa932de421c", x"da6909fda9f37160", x"77fae675a94f1e41", x"6a718ca8ef632ce5",
    x"383d6830be0da023", x"fdcf0174cac490d1", x"213a43b05cac1c5c", x"bf55de2c104e8326",
    x"b0c96866a5912780", x"3d18f3bdf73b5cfc", x"05205ac49d6c10f6", x"fac614bc26000399",
    x"17e60c06d7d3ce3b", x"16d55bfb226941de", x"8095997290a3ae99", x"3597cae953edc438",
    x"f3d1ddbd9e92c849", x"09f8f70a93319f8d", x"94a069ce96a7c6d1", x"7f93589cc062d2d3",
    x"7cd286bd80511c13", x"d30a848e0b817f9d", x"c521b4cb5c480654", x"27573cd030be1dc1",
    x"099aeb1f9594cea9", x"69baa117b6aede0b", x"b0c84cda5412f261", x"d5e7626df534fe5d",
    x"42b6aa90ca747700", x"259ed43ae98476c7", x"3abc8811eaa45950", x"229daba589af966a",
    x"6ab7e5ff4a47dac5", x"c8a1dd83937a3a00", x"ac5feb5d73ce3e2b", x"ef6732dae2074597",
    x"05e7e955e8382768", x"aeb4fd9467957779", x"436519ed346e2e22", x"818815aa03ab7b7d",
    x"5b9aed2f82142cfc", x"12f9807d14c59837", x"5bf08f9edef76356", x"19f685539a81834f",
    x"9b226f0cafc80fdd", x"ec0fb5b7853aaf58", x"ce23e665f076c46a", x"416e41e7afb160b8",
    x"690c0c59f2a92213", x"429b38ee9ecdc181", x"d11e7343f39f179d", x"e2258bac1145cca1",
    x"c8f68342f284e225", x"8c87f385fa2bcd54", x"1b6a04758db2f75f", x"d8da486043ec9a9e",
    x"77542a50122cf483", x"6dea5870529a7eac", x"4502deb531120645", x"e700f8a3ba146a8a",
    x"7960344719f9e208", x"2ccbb2c12d96f81a", x"67392a6a255ad3a9", x"46c3e620828423d8",
    x"3825812ec0712363", x"4ca18cf306dfc265", x"c0236a10359c77ec", x"ec18d1dabf79fca8",
    x"1f01652b97a42c37", x"32dce92d6339a64c", x"8e4b3faeb7c67848", x"bfa3027de4fe8b7c",
    x"2f39c76bc4b558e3", x"1b5d7f0178f7ed19", x"cc79fbe004b08514", x"d4f6320015900034",
    x"b6752e0490625fd6", x"146eed2d0a957d9c", x"080456d376d872ce", x"7ef3808abea4f57b",
    x"b9dfcc633f44212a", x"5cd356232497f76a", x"ae90f394239335ec", x"6b663b5d432c37e2",
    x"8da9274875cd75f8", x"348cda5e43fde374", x"0946f0df35976cc3", x"059232db36625011",
    x"0e320a6fa7b38ffe", x"3733b1bca2d65ea2", x"a2f1a98cb338ac09", x"e96bf79baae49b79",
    x"e9ae32ecec1a4e9e", x"fe3cb136fd46290e", x"1c1c6120d80369d1", x"03967de12d617d2f",
    x"ea9e5a716fe3b9ca", x"9deb7147e37375ee", x"483c6d9078b2b1fa", x"66259cb40888121e",
    x"dc84a49d8e2f5c88", x"0afa75d5b1d220c6", x"976313cc429a419e", x"6889a5f8c55669c3",
    x"c65072c976170dc8", x"01afb3b3365a26b8", x"53bb0b05755e9717", x"bb79ec1318059d8c",
    x"8be30e75a23fcbbd", x"7b4d88fdd8ced3b1", x"366718aa2f0d8182", x"883221c622d6cae4",
    x"e260f7deddf6daad", x"8e6fde72b2c7ae42", x"cbdf5accdd94d452", x"e179d9a726c48db2",
    x"c19999d2a9571e68", x"27a6102d0bc94c2d", x"9cc024d6bf511ba5", x"d581882959ab534a",
    x"d6fbbafc82ab3de0", x"4ae66e229e1244fb", x"e10439a710022656", x"ff873165783b4bdc",
    x"9ba301eb63dbb169", x"71cdcbd313c4258b", x"ec070ca0cb1b32e0", x"cda7961ed5ed0ffd",
    x"d461f2afc54847ab", x"cc18b5418be74fac", x"f0ccf8d3c954b042", x"b9d8c1111b413c80",
    x"f80234f015a13e53", x"85f684324a8066cd", x"3454271c35a5edd3", x"2dd5bd26d6cbf853",
    x"465ca1d025d73f56", x"762a72076410e740", x"a4c1f9ed383c23ec", x"c4d9b8280ba53dbb",
    x"f1356cad11b2c6c2", x"d3359aa7d0b5a831", x"1c3de88804a0c271", x"a36b9ddc010ab4ab",
    x"517110cb0353e0ef", x"22a5159a23b2a618", x"fb88c29e9db8cf23", x"c64b73d4c1fbf5c8",
    x"ca96460b8e981f28", x"e69e8b8915ad03e1", x"839508a797fe5a36", x"a88c3f77c37f05ec",
    x"662bc5d2aa11d80e", x"1b82abec7400b383", x"0b5367c463d114c8", x"409d730b0af4925a",
    x"480571b87dd21109", x"029898440c1fd6e9", x"667004c2ecf25986", x"e06e534c68720dad",
    x"bd959ce9cf45bba6", x"e4ee703106e80745", x"a50b66b14a00c39a", x"2cb864de372ccd69",
    x"ed91726816e29572", x"142cca825f03da2e", x"042cda1f7888b841", x"bc1a97e6531315e6",
    x"3c2b8b96f598934f", x"4cbb0ac7f7291737", x"388cd5c522a92f9e", x"aac8129f3b0fc056",
    x"4318be86f995400c", x"afee699671980611", x"5fb77a8d8d01bdc7", x"14a7d38b7748e2e8",
    x"e4ed42c0a2dc4822", x"5b707d06837b45b4", x"2188503b4af9002c", x"1266173b8f65bddc",
    x"c693dc2c72152e3d", x"ab37d5c5b34a8457", x"c618499ae78c54ba", x"d9f1e14b146856c3",
    x"773b545d614d0f3d", x"63846818bce197da", x"a90c74cc5d3683a7", x"010b04be1eec87c8",
    x"e602b7232a1d1a70", x"f60a4684495d127a", x"d16596d47d5c02b6", x"187ff79c1f291b25",
    x"f73fab9c8cff2b56", x"b2c9fd0a017f38eb", x"c2062ea1e3fef63f", x"4aa3048c728cb9c6",
    x"a0af4bed5a213bcc", x"9eba057cc1d3c77c", x"2e29a45508fa57d6", x"b796df21a39e8e99",
    x"a18dd46f3a21fbd4", x"f8249ae5dbb8e464", x"3a361c8a2843cdbf", x"fe48f6ca3cae2b08",
    x"ab555e38e6dedded", x"1ad633d6307107fe", x"904db5fd1c046185", x"cbb107b76bf8fd3b",
    x"3ff369aa34de161f", x"7fc7d653b8930c17", x"26cbff617146c8bf", x"7ece52bf0585c527",
    x"d772e54edfb3e29e", x"162d29e411eff9d2", x"ae321b263863aa44", x"e28384db34835962",
    x"5800dea24ddf03e9", x"4174fcdfc59d5b46", x"3176e3eb76be6d40", x"100c45a03a947489",
    x"fa5d06eaf6ab36cf", x"7081c5949415fe0e", x"12b50194654fd4c0", x"0a935d32a56dcff6",
    x"7f16b0f67cb7ac2a", x"511ec40423f384b9", x"6bac3aa2039a839c", x"f2f7b3a2885fd9b4",
    x"0ac8c474d712745b", x"4d45dba2cad9230a", x"5a9d4c051a70b347", x"8bb26aab3e37beeb",
    x"99d510b1ae3111d6", x"197e38a04de0c0da", x"77370a6c50869ce9", x"9690bfc91d8a08e8",
    x"c6f10eddecccb553", x"7dd84fefae2d3b1c", x"3c2e461a1d309ccf", x"2278c223b3c0948d",
    x"9f6208520b147f8e", x"2878546f9a45b4fc", x"a4a613abe002db92", x"15bf5df977407236",
    x"e3b434cbe828fafc", x"16ad9e404c782b8a", x"ad069e976fbc1a85", x"ca19af476653757c",
    x"09e6737b22b9ccd1", x"902cd117b3f22a69", x"a8847548e01519c8", x"62282f328c07f7c7",
    x"59266a6eef9937c9", x"0f0b61a0014d5ef4", x"dc44af3cb57c8daf", x"a5f9f57f2da79d19",
    x"99ac8e540268acaf", x"159b40c6e7cc9060", x"a1bd5f98fee151cc", x"d569260e2089c852",
    x"c73c4ce38253e1df", x"b39706fa72154598", x"8078ec4b4cb49149", x"b1786e104c79286c",
    x"b2d8cefa040f5b35", x"00f982826ef6bfc7", x"a8763d3fc0529691", x"d7c9ca41f6580ef9",
    x"9cdc58eb709fe458", x"254b318070744e73", x"b180f773cdc65477", x"d233acfa7a61cc70",
    x"a0f96cc0a9f71775", x"7821535f1dfbfc6a", x"7ffe473f12373e33", x"35aa6059cc6b19bf",
    x"9b3c53f31519ed32", x"af678463ac24841e", x"de5fedc2ec0a6c2c", x"b474893617ca5078",
    x"e67bb1e420a66119", x"bbb9b03607e71816", x"ca87080bbbed5dc3", x"c5dfa6958a2662f0",
    x"4235911461ef8282", x"bd8a3a02a3da362b", x"51478a443e93732e", x"9ef8598b732269fc",
    x"4e06da3e082ec24f", x"bee1df555d560af0", x"8c32abdcb07abba2", x"f357553f2d6bb303",
    x"67638efec4547d63", x"b7c80a50c51da6c5", x"efbe12bd09ca6cdc", x"4553ffe3fe0ec138",
    x"4abc6f031d4029f7", x"4a18b22cc71e5490", x"304bd00cb68be0aa", x"3ffd8a8813427c49",
    x"f606168aefc990f3", x"e1fb0f504c594498", x"aa1ccf6b4fcc211b", x"7f1308b41352abc4",
    x"14ea9ee4bc4d5865", x"f0f11052c883ce0e", x"bce0371761ec465c", x"04fdf7b264acf4bb",
    x"2633146011205f81", x"e55255f6f00563ca", x"3e99e208d5014d0d", x"0c03219214569db6",
    x"015d46a19043a476", x"74f9f2101b31a7c6", x"99c8340b210f49d8", x"ca02ad76ed68e6a5",
    x"4813cb3108e0d1e2", x"cee587887ef177e6", x"190e48d9f2fdf330", x"30c44d0269c20cd8",
    x"03c089ac8eba54ae", x"b5efd64b2e844295", x"19f21fd9a72099f0", x"03370e27d6774d83",
    x"d11b59a3971446dd", x"a9651e7aa0e69e07", x"ddc081c03f3e1be5", x"20e6278b80e01fc7",
    x"5a534a3643fc4371", x"22376f5c1be34768", x"f56e5c174c82bbad", x"2db7ef3a00a0f63a",
    x"08809c7299deb91a", x"34c4778ea92271f9", x"c003765ea2b5a4bd", x"2da9c89dbd7d1afa",
    x"fe7812f03cc00e22", x"f11e43c1c1767edf", x"b27489d304aca990", x"b70af284d9f96211",
    x"93f4db3409681e04", x"f8f3ca9d87fc8ba2", x"5cb9e8e4f2974346", x"d10c95f2a41026a7",
    x"4147caccd648110d", x"8d2b709e48dcd2c7", x"de41b34352748e29", x"086b766e8ad25775",
    x"27cc8edaf9a70cdf", x"e417764471b1169a", x"eaa25e5e02694812", x"0f4ddbbd88bce011",
    x"bcb9dc4b1f98e007", x"6b41257c28d6ec63", x"08087d63ea922503", x"2a0a06fc7dc5a74b",
    x"39890a446aaf2227", x"5158c7b3a38c04d3", x"911cf2cd7867ff04", x"40f797b2b32e42e2",
    x"c65121d229d03286", x"2194156d69f6c80b", x"a2c05294a5963416", x"8bb28195f5ca136c",
    x"0100a7c217beb869", x"566d502d005cc4f5", x"68379ee87770d77a", x"3ce456934ba1ade3",
    x"ba0d5f0916f10253", x"2200bbe8f2036a2b", x"bdf34e9e3de16ab8", x"bd35c21382044ebd",
    x"28bfab8c6b859b5e", x"b12c5ba71f25094c", x"efbeaddeefbeadde", x"efbeaddeefbeadde",
    x"efbeaddeefbeadde", x"efbeaddeefbeadde"
  );

  constant EXP : mem_matrix := (
    (
      x"c7a0d2d420b83db9", x"438467b4ad5a6292", x"0319338e1c095876", x"08554148ac90d912",
      x"4c2c8046ac706b15", x"4fc28752904de87d", x"f4081e34273a9477", x"e4b2a5f1a2daf3a1",
      x"3e9263f1aed966ea", x"dd6bc53f54013627", x"5c40e9c8b8df4883", x"d74251166c6189bd",
      x"150bf5882b0a140a", x"00722872803ed457", x"9fed20eff2984618", x"0017ddcd4a6c7324",
      x"026341cea43fc665", x"e9d2ab521fa30bc4", x"e7dfa71331b35e03", x"072cb55635ea4ca2",
      x"a0b3a460025a8c88", x"6a85b396125a8e27", x"96ca48f188ac8787", x"794ec881aa974372",
      x"7b6a5d4738881ed0", x"9d71a435d5092d72", x"3190ef87ef71b16e", x"024806df09af9cfc",
      x"ec8219bf4aae1453", x"c72d15e0e948b512", x"21ca4b9e387899c9", x"f6e73e4fdbb3bffa",
      x"f64bb840fd1d7379", x"764504100bfacccc", x"9797c1d5e1b1bf7c", x"1fc6843d96ecb8ae",
      x"210a008214ad9ad0", x"188ba781ddb44a52", x"b193de0b0b5ecda1", x"1700435caf32aada",
      x"53ee5e5985d5b99c", x"d2e890fe84f444c0", x"7123c3c328da7bda", x"e83c6108eecffb94",
      x"73f3922f11f581e3", x"541f029650900c15", x"be8f997be273f7c6", x"b40bb70e4d7b693e",
      x"6cdc9f101959b500", x"45f395433d92904b", x"f933b3d086e223fc", x"4b5745b59431fd2a",
      x"16cb2e2efe8dacbe", x"0cee5752a1487b78", x"f5e57c5b9d6a3b79", x"d03cf25c36c8332b",
      x"bb7a7db6a4e1de55", x"29d11f4f1d5b8e78", x"375a485ec8cd0dc3", x"e2c41447f43840b8",
      x"927ccc2adc37ee18", x"00481f26927f792d", x"0fd8969ea2ba6731", x"16b0ed13d707808b",
      x"0e397b75e4b0ec33", x"250f3985d77f9630", x"b718cb80e08fd781", x"3cd757eb596d1109",
      x"e0bd186f55b7882c", x"a1554eb801fd3192", x"3c322022d6e835e8", x"37d909af296c18e8",
      x"adcd8927d53f2fe0", x"d519bfed475f2d96", x"532eb8bed1cb004c", x"1d79ee251ab7cc4d",
      x"f34f1cbeb85707cf", x"6eff2a73a6557518", x"fe479e151ee15b09", x"0e82e4e44a25b40d",
      x"8089abda332e56dc", x"0048c92db922754e", x"42bcff9d2a83bef3", x"acc93647d4ba4be5",
      x"56bf1ca9fc1227d5", x"d2775a3f69b16540", x"5bc32d247a758bde", x"66056ad8251f42a7",
      x"50cdbd7b361b93d6", x"0c1110ca13144161", x"ccc8cb83bc7c8d7f", x"50fc3e230f6f09c4",
      x"babc2811fff4b745", x"50d9908c18cee9ba", x"c54867bcc2ebd693", x"db233e4cf20e43b5",
      x"7f1699e848ef4169", x"551f6761b95068ef", x"b0cedcdd8c89f271", x"4f8d6a7009ba8966",
      x"0acbdd25d8bf786a", x"ffcd746fcd84ee60", x"47b55ae5a8dcc673", x"1c4dccfe1d9395e2",
      x"b32b04c724d6f3cd", x"50a7cd5ae9422834", x"83c6cfc9ceb3ddd4", x"89f5a46e999deb1c",
      x"9ce339705b6ae848", x"2c87cc0f3e7b5852", x"4249eee03e622c6c", x"fe0b21499e84f3d9",
      x"64beaeb3e9bb0f8f", x"986685f766cda8ae", x"128df840531bd4d7", x"c652f9bb2957e90f",
      x"07918bff091fcc49", x"73aa96aa854671ae", x"5ba470969a565bc6", x"7b93c143022e4033",
      x"a403b9c621c32b57", x"c9fcd8a20adb8ea6", x"b608d581578b87ff", x"dc964229f388f821",
      x"c8e1b94a0a708449", x"e8bc17c3003ab699", x"3fee89886ec773b8", x"fb60fae9fec6d5f3",
      x"8207ae3cf15d742f", x"1430c82a6c7cb115", x"bf8915b84b1137f8", x"1eb22e703bb134e7",
      x"f71495b0447f39ca", x"0d1d1c2ce36a433f", x"7ca421d2b2cf2a92", x"d9666864e960389c",
      x"fb7741e1a9452ce7", x"b12699a132528c9a", x"18ca558845a3f946", x"c0c8f31d421d6a2d",
      x"7c6b9b2c9ea33e4a", x"696a2431804ffb42", x"6a1ca56d25289190", x"d5fb4c807b275656",
      x"04f112e713777c8e", x"03bfb19878778db5", x"e23bf6dec5b50698", x"3cb1debec3912278",
      x"4aa2e9501090bc28", x"29b5a7b714e55b48", x"4e712eb696d27e6c", x"60703c26ccbe64e4",
      x"703ae96aa4c1221a", x"c478a591a99ce6c6", x"e7ec493071ecf23c", x"053585d6b967b905",
      x"db818489eb666c94", x"6091064ef953efc9", x"f68f9093092f1f2d", x"9eb2258c6cbacd2b",
      x"252ca85129a23485", x"da8f99d25c7d0e30", x"a93b2ac37ce4b63e", x"0184a25316410162",
      x"5477acf0ba0913d5", x"e5f385ec671959ad", x"78b4897457f0ae74", x"86b5ec3c056ab56e",
      x"254df425f0254225", x"4c94b10198f37430", x"9936b5a13b4b4402", x"3010ac72bc68c444",
      x"cf90665ca81b2857", x"5572b2217b18cccc", x"ef6b3feba036f775", x"04ed4d294646fdfd",
      x"0d3ef79de3bbfb7c", x"f31c04f1071bb8ae", x"133e925b114b0bcc", x"ddf46e512532f0cc",
      x"6cadafa932de421c", x"da6909fda9f37160", x"77fae675a94f1e41", x"6a718ca8ef632ce5",
      x"383d6830be0da023", x"fdcf0174cac490d1", x"213a43b05cac1c5c", x"bf55de2c104e8326",
      x"b0c96866a5912780", x"3d18f3bdf73b5cfc", x"05205ac49d6c10f6", x"fac614bc26000399",
      x"17e60c06d7d3ce3b", x"16d55bfb226941de", x"8095997290a3ae99", x"3597cae953edc438",
      x"f3d1ddbd9e92c849", x"09f8f70a93319f8d", x"94a069ce96a7c6d1", x"7f93589cc062d2d3",
      x"7cd286bd80511c13", x"d30a848e0b817f9d", x"c521b4cb5c480654", x"27573cd030be1dc1",
      x"099aeb1f9594cea9", x"69baa117b6aede0b", x"b0c84cda5412f261", x"d5e7626df534fe5d",
      x"42b6aa90ca747700", x"259ed43ae98476c7", x"3abc8811eaa45950", x"229daba589af966a",
      x"6ab7e5ff4a47dac5", x"c8a1dd83937a3a00", x"ac5feb5d73ce3e2b", x"ef6732dae2074597",
      x"05e7e955e8382768", x"aeb4fd9467957779", x"436519ed346e2e22", x"818815aa03ab7b7d",
      x"5b9aed2f82142cfc", x"12f9807d14c59837", x"5bf08f9edef76356", x"19f685539a81834f",
      x"9b226f0cafc80fdd", x"ec0fb5b7853aaf58", x"ce23e665f076c46a", x"416e41e7afb160b8",
      x"690c0c59f2a92213", x"429b38ee9ecdc181", x"d11e7343f39f179d", x"e2258bac1145cca1",
      x"c8f68342f284e225", x"8c87f385fa2bcd54", x"1b6a04758db2f75f", x"d8da486043ec9a9e",
      x"77542a50122cf483", x"6dea5870529a7eac", x"4502deb531120645", x"e700f8a3ba146a8a",
      x"7960344719f9e208", x"2ccbb2c12d96f81a", x"67392a6a255ad3a9", x"46c3e620828423d8",
      x"3825812ec0712363", x"4ca18cf306dfc265", x"c0236a10359c77ec", x"ec18d1dabf79fca8",
      x"1f01652b97a42c37", x"32dce92d6339a64c", x"8e4b3faeb7c67848", x"bfa3027de4fe8b7c",
      x"2f39c76bc4b558e3", x"1b5d7f0178f7ed19", x"cc79fbe004b08514", x"d4f6320015900034",
      x"b6752e0490625fd6", x"146eed2d0a957d9c", x"080456d376d872ce", x"7ef3808abea4f57b",
      x"b9dfcc633f44212a", x"5cd356232497f76a", x"ae90f394239335ec", x"6b663b5d432c37e2",
      x"8da9274875cd75f8", x"348cda5e43fde374", x"0946f0df35976cc3", x"059232db36625011",
      x"0e320a6fa7b38ffe", x"3733b1bca2d65ea2", x"a2f1a98cb338ac09", x"e96bf79baae49b79",
      x"e9ae32ecec1a4e9e", x"fe3cb136fd46290e", x"1c1c6120d80369d1", x"03967de12d617d2f",
      x"000000000000000a"
    ),
    (
      x"9deb7147e37375ee", x"483c6d9078b2b1fa", x"66259cb40888121e", x"dc84a49d8e2f5c88",
      x"0afa75d5b1d220c6", x"976313cc429a419e", x"6889a5f8c55669c3", x"c65072c976170dc8",
      x"01afb3b3365a26b8", x"53bb0b05755e9717", x"bb79ec1318059d8c", x"8be30e75a23fcbbd",
      x"7b4d88fdd8ced3b1", x"366718aa2f0d8182", x"883221c622d6cae4", x"e260f7deddf6daad",
      x"8e6fde72b2c7ae42", x"cbdf5accdd94d452", x"e179d9a726c48db2", x"c19999d2a9571e68",
      x"27a6102d0bc94c2d", x"9cc024d6bf511ba5", x"d581882959ab534a", x"d6fbbafc82ab3de0",
      x"4ae66e229e1244fb", x"e10439a710022656", x"ff873165783b4bdc", x"9ba301eb63dbb169",
      x"71cdcbd313c4258b", x"ec070ca0cb1b32e0", x"cda7961ed5ed0ffd", x"d461f2afc54847ab",
      x"cc18b5418be74fac", x"f0ccf8d3c954b042", x"b9d8c1111b413c80", x"f80234f015a13e53",
      x"85f684324a8066cd", x"3454271c35a5edd3", x"2dd5bd26d6cbf853", x"465ca1d025d73f56",
      x"762a72076410e740", x"a4c1f9ed383c23ec", x"c4d9b8280ba53dbb", x"f1356cad11b2c6c2",
      x"d3359aa7d0b5a831", x"1c3de88804a0c271", x"a36b9ddc010ab4ab", x"517110cb0353e0ef",
      x"22a5159a23b2a618", x"fb88c29e9db8cf23", x"c64b73d4c1fbf5c8", x"ca96460b8e981f28",
      x"e69e8b8915ad03e1", x"839508a797fe5a36", x"a88c3f77c37f05ec", x"662bc5d2aa11d80e",
      x"1b82abec7400b383", x"0b5367c463d114c8", x"409d730b0af4925a", x"480571b87dd21109",
      x"029898440c1fd6e9", x"667004c2ecf25986", x"e06e534c68720dad", x"bd959ce9cf45bba6",
      x"e4ee703106e80745", x"a50b66b14a00c39a", x"2cb864de372ccd69", x"ed91726816e29572",
      x"142cca825f03da2e", x"042cda1f7888b841", x"bc1a97e6531315e6", x"3c2b8b96f598934f",
      x"4cbb0ac7f7291737", x"388cd5c522a92f9e", x"aac8129f3b0fc056", x"4318be86f995400c",
      x"afee699671980611", x"5fb77a8d8d01bdc7", x"14a7d38b7748e2e8", x"e4ed42c0a2dc4822",
      x"5b707d06837b45b4", x"2188503b4af9002c", x"1266173b8f65bddc", x"c693dc2c72152e3d",
      x"ab37d5c5b34a8457", x"c618499ae78c54ba", x"d9f1e14b146856c3", x"773b545d614d0f3d",
      x"63846818bce197da", x"a90c74cc5d3683a7", x"010b04be1eec87c8", x"e602b7232a1d1a70",
      x"f60a4684495d127a", x"d16596d47d5c02b6", x"187ff79c1f291b25", x"f73fab9c8cff2b56",
      x"b2c9fd0a017f38eb", x"c2062ea1e3fef63f", x"4aa3048c728cb9c6", x"a0af4bed5a213bcc",
      x"9eba057cc1d3c77c", x"2e29a45508fa57d6", x"b796df21a39e8e99", x"a18dd46f3a21fbd4",
      x"f8249ae5dbb8e464", x"3a361c8a2843cdbf", x"fe48f6ca3cae2b08", x"ab555e38e6dedded",
      x"1ad633d6307107fe", x"904db5fd1c046185", x"cbb107b76bf8fd3b", x"3ff369aa34de161f",
      x"7fc7d653b8930c17", x"26cbff617146c8bf", x"7ece52bf0585c527", x"d772e54edfb3e29e",
      x"162d29e411eff9d2", x"ae321b263863aa44", x"e28384db34835962", x"5800dea24ddf03e9",
      x"4174fcdfc59d5b46", x"3176e3eb76be6d40", x"100c45a03a947489", x"fa5d06eaf6ab36cf",
      x"7081c5949415fe0e", x"12b50194654fd4c0", x"0a935d32a56dcff6", x"7f16b0f67cb7ac2a",
      x"511ec40423f384b9", x"6bac3aa2039a839c", x"f2f7b3a2885fd9b4", x"0ac8c474d712745b",
      x"4d45dba2cad9230a", x"5a9d4c051a70b347", x"8bb26aab3e37beeb", x"99d510b1ae3111d6",
      x"197e38a04de0c0da", x"77370a6c50869ce9", x"9690bfc91d8a08e8", x"c6f10eddecccb553",
      x"7dd84fefae2d3b1c", x"3c2e461a1d309ccf", x"2278c223b3c0948d", x"9f6208520b147f8e",
      x"2878546f9a45b4fc", x"a4a613abe002db92", x"15bf5df977407236", x"e3b434cbe828fafc",
      x"16ad9e404c782b8a", x"ad069e976fbc1a85", x"ca19af476653757c", x"09e6737b22b9ccd1",
      x"902cd117b3f22a69", x"a8847548e01519c8", x"62282f328c07f7c7", x"59266a6eef9937c9",
      x"0f0b61a0014d5ef4", x"dc44af3cb57c8daf", x"a5f9f57f2da79d19", x"99ac8e540268acaf",
      x"159b40c6e7cc9060", x"a1bd5f98fee151cc", x"d569260e2089c852", x"c73c4ce38253e1df",
      x"b39706fa72154598", x"8078ec4b4cb49149", x"b1786e104c79286c", x"b2d8cefa040f5b35",
      x"00f982826ef6bfc7", x"a8763d3fc0529691", x"d7c9ca41f6580ef9", x"9cdc58eb709fe458",
      x"254b318070744e73", x"b180f773cdc65477", x"d233acfa7a61cc70", x"a0f96cc0a9f71775",
      x"7821535f1dfbfc6a", x"7ffe473f12373e33", x"35aa6059cc6b19bf", x"9b3c53f31519ed32",
      x"af678463ac24841e", x"de5fedc2ec0a6c2c", x"b474893617ca5078", x"e67bb1e420a66119",
      x"bbb9b03607e71816", x"ca87080bbbed5dc3", x"c5dfa6958a2662f0", x"4235911461ef8282",
      x"bd8a3a02a3da362b", x"51478a443e93732e", x"9ef8598b732269fc", x"4e06da3e082ec24f",
      x"bee1df555d560af0", x"8c32abdcb07abba2", x"f357553f2d6bb303", x"67638efec4547d63",
      x"b7c80a50c51da6c5", x"efbe12bd09ca6cdc", x"4553ffe3fe0ec138", x"4abc6f031d4029f7",
      x"4a18b22cc71e5490", x"304bd00cb68be0aa", x"3ffd8a8813427c49", x"f606168aefc990f3",
      x"e1fb0f504c594498", x"aa1ccf6b4fcc211b", x"7f1308b41352abc4", x"14ea9ee4bc4d5865",
      x"f0f11052c883ce0e", x"bce0371761ec465c", x"04fdf7b264acf4bb", x"2633146011205f81",
      x"e55255f6f00563ca", x"3e99e208d5014d0d", x"0c03219214569db6", x"015d46a19043a476",
      x"74f9f2101b31a7c6", x"99c8340b210f49d8", x"ca02ad76ed68e6a5", x"4813cb3108e0d1e2",
      x"cee587887ef177e6", x"190e48d9f2fdf330", x"30c44d0269c20cd8", x"03c089ac8eba54ae",
      x"b5efd64b2e844295", x"19f21fd9a72099f0", x"03370e27d6774d83", x"d11b59a3971446dd",
      x"a9651e7aa0e69e07", x"ddc081c03f3e1be5", x"20e6278b80e01fc7", x"5a534a3643fc4371",
      x"22376f5c1be34768", x"f56e5c174c82bbad", x"2db7ef3a00a0f63a", x"08809c7299deb91a",
      x"34c4778ea92271f9", x"c003765ea2b5a4bd", x"2da9c89dbd7d1afa", x"fe7812f03cc00e22",
      x"f11e43c1c1767edf", x"b27489d304aca990", x"b70af284d9f96211", x"93f4db3409681e04",
      x"f8f3ca9d87fc8ba2", x"5cb9e8e4f2974346", x"d10c95f2a41026a7", x"4147caccd648110d",
      x"8d2b709e48dcd2c7", x"de41b34352748e29", x"086b766e8ad25775", x"27cc8edaf9a70cdf",
      x"e417764471b1169a", x"eaa25e5e02694812", x"0f4ddbbd88bce011", x"bcb9dc4b1f98e007",
      x"6b41257c28d6ec63", x"08087d63ea922503", x"2a0a06fc7dc5a74b", x"39890a446aaf2227",
      x"5158c7b3a38c04d3", x"911cf2cd7867ff04", x"40f797b2b32e42e2", x"c65121d229d03286",
      x"2194156d69f6c80b", x"a2c05294a5963416", x"8bb28195f5ca136c", x"0100a7c217beb869",
      x"566d502d005cc4f5", x"68379ee87770d77a", x"3ce456934ba1ade3", x"ba0d5f0916f10253",
      x"2200bbe8f2036a2b", x"bdf34e9e3de16ab8", x"bd35c21382044ebd", x"28bfab8c6b859b5e",
      x"000000000000000c"
    )
  );

  constant CUM : cum_array := (277, 554);

  signal clk         : std_logic := '0';
  signal finished    : boolean   := false;
  signal rst         : std_logic := '1';
  signal start       : std_logic := '0';
  signal din         : std_logic_vector(63 downto 0) := (others => '0');
  signal din_valid   : std_logic := '0';
  signal din_ready   : std_logic;
  signal wr_en       : std_logic;
  signal wr_addr     : unsigned(8 downto 0);
  signal wr_data     : std_logic_vector(63 downto 0);
  signal sample_done : std_logic;

  signal idx   : integer := 0;
  signal n_acc : integer := 0;
  signal mem   : mem_array := (others => (others => 'U'));

begin

  clkgen : process
  begin
    while not finished loop
      clk <= '0'; wait for 5 ns;
      clk <= '1'; wait for 5 ns;
    end loop;
    wait;
  end process;

  dut : entity work.sample_vect
    port map (
      clk => clk, rst => rst, start => start,
      din => din, din_valid => din_valid, din_ready => din_ready,
      wr_en => wr_en, wr_addr => wr_addr, wr_data => wr_data,
      sample_done => sample_done);

  src : process(clk)
    variable lfsr : unsigned(15 downto 0) := x"ACE1";
    variable nxt  : integer;
  begin
    if rising_edge(clk) then
      lfsr := lfsr(14 downto 0) & (lfsr(15) xor lfsr(13) xor lfsr(12) xor lfsr(10));
      nxt := idx;
      if din_valid = '1' and din_ready = '1' then
        nxt := idx + 1;
        n_acc <= n_acc + 1;
      end if;
      idx <= nxt;
      if nxt < TOTAL then
        din <= STREAM(nxt);
      else
        din <= (others => '0');
      end if;
      if din_valid = '1' and din_ready = '0' then
        din_valid <= '1';
      elsif nxt < TOTAL and (lfsr(0) = '1' or lfsr(3) = '1') then
        din_valid <= '1';
      else
        din_valid <= '0';
      end if;
    end if;
  end process;

  mon : process(clk)
  begin
    if rising_edge(clk) then
      if start = '1' then
        mem <= (others => (others => 'U'));
      elsif wr_en = '1' then
        mem(to_integer(wr_addr)) <= wr_data;
      end if;
    end if;
  end process;

  stim : process
    variable e    : integer;
    variable errs : integer := 0;
  begin
    wait for 50 ns;
    wait until rising_edge(clk);
    rst <= '0';
    for c in 0 to K-1 loop
      wait until rising_edge(clk);
      start <= '1';
      wait until rising_edge(clk);
      start <= '0';
      wait until rising_edge(clk) and sample_done = '1';
      e := 0;
      for j in 0 to W64-1 loop
        if mem(j) /= EXP(c, j) then
          e := e + 1;
        end if;
      end loop;
      if n_acc /= CUM(c) then
        report "llamada " & integer'image(c) & ": palabras consumidas = " & integer'image(n_acc) &
               ", esperado " & integer'image(CUM(c)) severity error;
        e := e + 1;
      end if;
      if e = 0 then
        report "OK    : llamada " & integer'image(c) severity note;
      else
        report "FALLO : llamada " & integer'image(c) & " (" & integer'image(e) & " diferencias)" severity error;
      end if;
      errs := errs + e;
    end loop;
    if errs = 0 then
      report "TODAS LAS LLAMADAS OK" severity note;
    else
      report "HAY ERRORES: " & integer'image(errs) severity error;
    end if;
    finished <= true;
    wait;
  end process;

  watchdog : process
  begin
    wait until finished for 50 ms;
    if not finished then
      report "TIMEOUT" severity failure;
    end if;
    wait;
  end process;

end sim;
