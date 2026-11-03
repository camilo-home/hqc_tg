import argparse
import shutil
from pathlib import Path

import vhd_generator_for_rs_constants as generator


def log(message):
    print("[configure_rs_codec] " + message, flush=True)


def rs_gf_name(word_length):
    return "RS_GF_" + str(2 ** word_length)


def write_testbench_params(path, n, k, word_length, fcr, primitive_polynomial, num_codewords):
    contents = """library IEEE;
use IEEE.STD_LOGIC_1164.all;
library WORK;
use WORK.RS_TYPES.all;

package TB_RS_ENCODER_DECODER_PARAMS is
    constant TB_N : natural := {n};
    constant TB_K : natural := {k};
    constant TB_RS_GF : RSGFSize := {rs_gf};
    constant TB_FCR : natural := {fcr};
    constant TB_PRIMITIVE_POLYNOMIAL : natural := {primitive_polynomial};
    constant TB_NUM_CODEWORDS : natural := {num_codewords};
end package TB_RS_ENCODER_DECODER_PARAMS;
""".format(
        n=n,
        k=k,
        rs_gf=rs_gf_name(word_length),
        fcr=fcr,
        primitive_polynomial=primitive_polynomial,
        num_codewords=num_codewords,
    )
    path.write_text(contents)


def validate_args(args):
    if args.word_length < 2 or args.word_length > args.max_exp:
        raise ValueError("--word-length must be in the range 2 to --max-exp")
    if args.k >= args.n:
        raise ValueError("--k must be smaller than --n")
    if args.n > 2 ** args.word_length - 1:
        raise ValueError("--n must be <= 2**word_length - 1")
    if args.fcr > 2 ** args.word_length - 2:
        raise ValueError("--fcr must be <= 2**word_length - 2")
    if args.primitive_polynomial < 0:
        raise ValueError("--primitive-polynomial must be non-negative")
    if args.num_codewords < 1:
        raise ValueError("--num-codewords must be at least 1")


def main():
    parser = argparse.ArgumentParser(
        description="Configure RS codec constants and encoder/decoder sanity testbench."
    )
    parser.add_argument("--n", type=int, required=True,
                        help="RS codeword length, for example 30 for RS(30,18)")
    parser.add_argument("--k", type=int, required=True,
                        help="RS message length, for example 18 for RS(30,18)")
    parser.add_argument("--word-length", type=int, required=True,
                        help="GF word length m. Use 8 for GF(256)")
    parser.add_argument("--primitive-polynomial", type=int, required=True,
                        help="Primitive polynomial. Use 391 for the UAT GF(256) example")
    parser.add_argument("--fcr", type=int, default=0,
                        help="First consecutive root. Use 120 for the UAT example")
    parser.add_argument("--num-codewords", type=int, default=2,
                        help="Number of generated codewords in the sanity testbench")
    parser.add_argument("--max-exp", type=int, default=10,
                        help="Maximum GF word length emitted in rs_constants.vhd")
    parser.add_argument("--no-backup", action="store_true",
                        help="Do not keep a .bak copy of the previous rs_constants.vhd")
    args = parser.parse_args()
    log("Validating arguments")
    validate_args(args)

    repo_root = Path(__file__).resolve().parents[2]
    rtl_dir = repo_root / "rs_codec" / "rtl"
    sim_dir = repo_root / "rs_codec" / "sim"
    generated_constants = Path(__file__).resolve().parent / "rs_constants.generated.vhd"
    target_constants = rtl_dir / "rs_constants.vhd"
    params_file = sim_dir / "tb_rs_encoder_decoder_params.vhd"

    primitive_override = None if args.primitive_polynomial == 0 else args.primitive_polynomial
    word_length_override = None if primitive_override is None else args.word_length

    log("Configuration: RS(" + str(args.n) + "," + str(args.k) + "), " +
        "WORD_LENGTH=" + str(args.word_length) +
        ", PRIMITIVE_POLYNOMIAL=" + str(args.primitive_polynomial) +
        ", FCR=" + str(args.fcr))
    log("Regenerating rs_constants.vhd. This can take a while for larger GF sizes.")
    generator.generate_rs_constants_codeword(
        exp=args.max_exp,
        word_length=word_length_override,
        primitive_polynomial=primitive_override,
        b=args.fcr,
        output=str(generated_constants),
    )

    if target_constants.exists() and not args.no_backup:
        log("Backing up current rs_constants.vhd to " + str(target_constants) + ".bak")
        shutil.copyfile(str(target_constants), str(target_constants) + ".bak")

    log("Replacing " + str(target_constants))
    shutil.move(str(generated_constants), str(target_constants))

    log("Writing testbench parameter package " + str(params_file))
    write_testbench_params(
        params_file,
        n=args.n,
        k=args.k,
        word_length=args.word_length,
        fcr=args.fcr,
        primitive_polynomial=args.primitive_polynomial,
        num_codewords=args.num_codewords,
    )

    log("Updated " + str(target_constants))
    log("Updated " + str(params_file))
    log("Sanity test command:")
    print("  vsim -c -do rs_codec/sim/run_tb_encoder_decoder.tcl", flush=True)


if __name__ == "__main__":
    main()
