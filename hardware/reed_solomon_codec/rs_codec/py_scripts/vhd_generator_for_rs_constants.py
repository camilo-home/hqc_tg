import argparse
from pathlib import Path

import rs_helper_functions as rs


def log(message, verbose=True):
    if verbose:
        print("[rs_constants] " + message, flush=True)

def main():
    parser = argparse.ArgumentParser(description="Generate rs_constants.vhd")
    parser.add_argument("--max-exp", type=int, default=10,
                        help="Maximum GF word length to generate. Default: 10")
    parser.add_argument("--word-length", type=int,
                        help="GF word length whose primitive polynomial should be overridden")
    parser.add_argument("--primitive-polynomial", type=int,
                        help="Primitive polynomial to use for --word-length")
    parser.add_argument("--fcr", type=int, default=0,
                        help="First consecutive root used to generate the generator polynomial. Default: 0")
    parser.add_argument("--output", default="rs_constants.vhd",
                        help="Output VHDL file. Default: rs_constants.vhd")
    args = parser.parse_args()

    generate_rs_constants_codeword(args.max_exp,
                                   word_length=args.word_length,
                                   primitive_polynomial=args.primitive_polynomial,
                                   b=args.fcr,
                                   output=args.output)

def get_primitive_polynomials(exp=10, word_length=None, primitive_polynomial=None):
    primitive_polynomials = [0, 7, 11, 19, 37, 67, 131, 285, 529, 1033]

    if exp > len(primitive_polynomials):
        raise ValueError("exp cannot be greater than " + str(len(primitive_polynomials)))

    if primitive_polynomial is None:
        return primitive_polynomials

    if word_length is None:
        raise ValueError("word_length must be provided when primitive_polynomial is provided")

    if word_length < 2 or word_length > exp:
        raise ValueError("word_length must be in the range 2 to " + str(exp))

    primitive_polynomials[word_length - 1] = primitive_polynomial
    return primitive_polynomials

def generate_rs_constants_codeword(exp=10, word_length=None, primitive_polynomial=None, b=0, output="rs_constants.vhd", verbose=True):
    primitive_polynomials = get_primitive_polynomials(exp, word_length, primitive_polynomial)
    output_path = Path(output)
    log("Generating " + str(output_path), verbose)
    log("max_exp=" + str(exp) + ", fcr=" + str(b), verbose)
    if primitive_polynomial is not None:
        log("Overriding WORD_LENGTH=" + str(word_length) +
            " primitive_polynomial=" + str(primitive_polynomial), verbose)

    f = output_path.open("w+")
    f.write("---------------------------------------------------------------------------\n")
    f.write("-- Universidade Federal de Minas Gerais (UFMG)\n")
    f.write("---------------------------------------------------------------------------\n")
    f.write("-- Project: RS Encoder\n")
    f.write("-- Design: package rs_constants\n")
    f.write("---------------------------------------------------------------------------\n")
    f.write("\n")
    f.write("library IEEE;\n")
    f.write("use IEEE.STD_LOGIC_1164.all;\n")
    f.write("\n") 
    f.write("package RS_CONSTANTS is\n\n")
    #f.write("\ttype std_logic_vector_array is array (natural range <>) of std_logic_vector;\n")
    f.write("\ttype INT_ARRAY is array (integer range <>) of integer;\n")
    
    counter = 0
    array_positions = list()
    array_of_gen_poly = list()
    for x in range(2, exp+1):
        log("Generating generator polynomials for GF(2^" + str(x) + ")", verbose)
        array_positions.append(counter)
        y = 1
        gen_poly = list()
        while (y < 2**x - 1):
            if y == 1 or y % 64 == 0:
                log("  generator polynomial degree " + str(y) +
                    " of " + str(2**x - 2), verbose)
            gen_poly.append(rs.rs_generator_poly(y, b, 2, primitive_polynomials[x-1], 2**x))
            y += 1
            counter += 1
        array_of_gen_poly.append(gen_poly)

    log("Writing generator polynomial indexes", verbose)
    f.write("\tconstant gp_indexes: INT_ARRAY(0 to "+str(len(array_positions)-1)+") := (")
    for x in array_positions:
        if x != array_positions[-1]:
            f.write(str(x)+", ")
        else:
            f.write(str(x)+");\n")

    for y in range(2, exp+1):
        end_range = 2**y - 1;
        log("Generating inverse table gp_inverse_" + str(y) +
            " with " + str(end_range + 1) + " entries", verbose)
        f.write("\tconstant gp_inverse_"+str(y)+": INT_ARRAY(0 to "+str(end_range)+") := (")
        for x in range(0, end_range+1):
            if x != 0 and x % 128 == 0:
                log("  gp_inverse_" + str(y) + " entry " + str(x) +
                    " of " + str(end_range), verbose)
            index = y - 1
            if x == 0:
                f.write("0, ")
            elif x != end_range:
                f.write(str(rs.gf_inverse(x, primitive_polynomials[index], end_range + 1)) +", ")
            else:
                f.write(str(rs.gf_inverse(x, primitive_polynomials[index], end_range + 1)) +");\n")

    for pot in range(2, exp+1):
        end_range = 2**pot - 1;
        log("Generating power table gp_pow_" + str(pot) +
            " with " + str(end_range + 1) + " entries", verbose)
        f.write("\tconstant gp_pow_"+str(pot)+": INT_ARRAY(0 to "+str(end_range)+") := (")
        mult = 1
        for pot_index in range(0, end_range+1):
            if pot_index == 0:
                f.write("1, ")
            elif pot_index != end_range:
                mult = rs.gf_mult_noLUT(mult, 2, primitive_polynomials[pot-1], end_range+1)
                f.write(str(mult) +", ")
            else:
                mult = rs.gf_mult_noLUT(mult, 2, primitive_polynomials[pot-1], end_range+1)
                f.write(str(mult) +");\n")

    log("Writing generator polynomial table gp", verbose)
    f.write("\ttype MULT_TABLE_GP is array (0 to ")
    f.write(str(counter - 1))
    f.write(") of INT_ARRAY(0 to ")
    max_poly_length = len(array_of_gen_poly[-1][-1]) - 1
    f.write(str(max_poly_length)+");\n")
    f.write("\tconstant gp: MULT_TABLE_GP := (\n")
    for polys in array_of_gen_poly:
        for poly in polys:
            f.write("\t\t(")
            for el in reversed(poly[1:]):
                f.write(str(el)+", " )
            if (polys == array_of_gen_poly[-1] and poly == polys[-1]):
                f.write("others => 0)\n")
            else:
                f.write("others => 0),\n")
    f.write("\t);\n")

    for x in range(1, exp+1):
        end = str(2**x-1)
        log("Declaring multiplication table type for " + str(x) + "-bit field", verbose)
        f.write("\ttype MULT_TABLE_"+str(x)+"_BIT is array (0 to "+end+") of INT_ARRAY(0 to "+end+");\n")

    for x in range(1, exp+1):
        end = 2**x
        log("Generating multiplication table mt_" + str(x) +
            " with " + str(end) + "x" + str(end) + " entries", verbose)
        f.write("\tconstant mt_"+str(x)+" : MULT_TABLE_"+str(x)+"_BIT := (\n")
        for y in range(0,end):
            if y == 0 or y == end - 1 or y % 64 == 0:
                log("  mt_" + str(x) + " row " + str(y + 1) +
                    " of " + str(end), verbose)
            f.write("\t\t(")
            for z in range(0,end):
                mult = str(rs.gf_mult_noLUT(z, y, primitive_polynomials[x-1], end))
                if (z == end-1):
                    f.write(mult)
                else:
                    f.write(mult+", ")
            if (y == end-1):
                f.write(")\n")
            else:
                f.write("),\n")
        f.write("\t);\n") 
    f.write("\tfunction f_gp_factor (\n")
    f.write("\t\tlength, num_error_max, term: integer)\n")
    f.write("\t\treturn integer;\n\n")
    f.write("end package RS_CONSTANTS;\n\n")
    f.write("package body RS_CONSTANTS is\n\n")
    f.write("\tfunction f_gp_factor (length, num_error_max, term: integer) return integer is\n")
    f.write("\tbegin\n")
    f.write("\t\treturn gp(gp_indexes(length-2) + num_error_max - 1)(term);\n")
    f.write("\tend f_gp_factor;\n\n")
    f.write("end package body RS_CONSTANTS;")
    f.close()
    log("Finished generating " + str(output_path), verbose)

if __name__ == "__main__":
	main()
