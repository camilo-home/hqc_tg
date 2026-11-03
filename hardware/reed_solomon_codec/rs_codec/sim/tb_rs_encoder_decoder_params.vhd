library IEEE;
use IEEE.STD_LOGIC_1164.all;
library WORK;
use WORK.RS_TYPES.all;

package TB_RS_ENCODER_DECODER_PARAMS is
    constant TB_N : natural := 46;
    constant TB_K : natural := 16;
    constant TB_RS_GF : RSGFSize := RS_GF_256;
    constant TB_FCR : natural := 0;
    constant TB_PRIMITIVE_POLYNOMIAL : natural := 285;
    constant TB_NUM_CODEWORDS : natural := 2;
end package TB_RS_ENCODER_DECODER_PARAMS;
