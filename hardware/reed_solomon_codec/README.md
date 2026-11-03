# rs_codec

This project comprises the RTL development of a parameterizable RS codec. It is one of the most complete open-source IP cores for Reed-Solomon encoding and decoding.

There is a paper that explains all nuances of this project:
https://ietresearch.onlinelibrary.wiley.com/doi/10.1049/cdt2.12009

This project started at Universidade Federal de Minas Gerais (UFMG), and it is open for the community under the license "MIT".
Contact Mateus Silva at matgonsil@gmail.com for questions or partnership proposals.

It provides both RS encoder and decoder, and the following parameters can be adjusted in their instantiation:

- N - Length of the codeword - Range -> 2 to 1023
- K - Number of message/data symbols - Range -> 1 to N-2
- m (RS_GF) - Symbol width / GF exponent, where the field size is 2^m - Range -> 2 to 10
- primitive polynomial - Primitive polynomial used by the Galois Field arithmetic. Use the IP configurator when changing it, so `rs_constants.vhd` and the simulation parameters stay consistent.

If you do not understand the concepts of RS codec, there are plenty of references for learning it. I recommend the following:

- Clarke, C.K.P.: 'Reed-Solomon Error Correction', BBC R\&D White Paper, WHP, 31, 2002
- Geisel, W.A: 'Tutorial on Reed-Solomon Error Correction Coding'. Technical Memorandum 102162, NASA, 1990
- Wicker, S.B., Bhargava, V.K.: 'An Introduction to Reed-Solomon Codes', in Wicker, S.B. (Ed.): 'Reed-Solomon Codes and Their Applications' (Wiley-IEEE Press, 1994, 1st edn.), pp. 1-16

Top level ports:

I - Input
O - Output

clk - I - System clock pin \
rst - I - System reset pin \
i_start_cw - I - Delimiter of input codeword start \
i_end_cw - I - Delimiter of input codeword end \
i_valid - I - Validity of input symbols \ 
i_consume - I - Consumes output of the codec \
i_symbol - I - Input data symbol \
o_start_cw - O - Delimiter of output codeword starting \
o_end_cw - O - Delimiter of output codeword ending \
o_in_ready - O - Readiness to accept new input symbols \
o_valid - O - Validity of output symbols \
o_error - O - Error indicator \
o_symbol - O - Output data symbol


The top level .vhd files are: rs_codec.vhd, rs_decoder.vhd, and rs_encoder.vhd.

If you look the directory structure, inside the projects (rs_decoder and rs_encoder) there are four folders:

rtl - VHDL implementation of the IP \
sim - RTL simulation scripts using Mentor ModelSim Student Edition \
formal - Scripts for formal verification using Cadence JasperGold Apps \
syn - Script for synthesis in FPGA using Quartus Prime Lite Edition 

## IP Configuration

The IP configurator script is the recommended entry point for preparing the codec for a specific RS configuration:

```text
rs_codec/py_scripts/configure_rs_codec.py
```

Run this script whenever you change the RS configuration used by the IP or by the encoder/decoder sanity test. This includes changes to `N`, `K`, the GF word length, the primitive polynomial, or the first consecutive root (FCR).

The script performs three steps:

1. Regenerates `rs_constants.vhd` by calling `vhd_generator_for_rs_constants.py`.
2. Replaces `rs_codec/rtl/rs_constants.vhd` with the generated version.
3. Writes `rs_codec/sim/tb_rs_encoder_decoder_params.vhd`, which is read by `run_tb_encoder_decoder.tcl` and `tb_rs_encoder_decoder.vhd`.

Example:

```text
RS(30,18)
GF(256), so WORD_LENGTH = 8
primitive polynomial = 391
first consecutive root (FCR) = 120
```

Before running this configuration, make sure `rs_full_multiplier_core.vhd` supports `WORD_LENGTH = 8` and `PRIMITIVE_POLYNOMIAL = 391`; otherwise the full multiplier assertion will fail during simulation.

Run:

```sh
python rs_codec/py_scripts/configure_rs_codec.py --n 30 --k 18 --word-length 8 --primitive-polynomial 391 --fcr 120
```

By default, the script keeps a backup of the default rs_constants at:

```text
rs_codec/rtl/rs_constants.vhd.bak
```

Use `--no-backup` if you do not want that backup file.

The script modifies tracked source files in the working tree. Review and commit the generated `rs_constants.vhd` and `tb_rs_encoder_decoder_params.vhd` if you want to keep the configuration.

After configuration, run the sanity test:

```sh
vsim -c -do rs_codec/sim/run_tb_encoder_decoder.tcl
```

The testbench sends `TB_NUM_CODEWORDS` generated messages through the encoder and then through the decoder. The number of input symbols is derived from `TB_K`, and the number of encoded/decoded symbols is derived from `TB_N`, so changing `--n` and `--k` in the script updates the testbench execution automatically.

The encoder uses the generated lookup tables in `rs_constants.vhd`. The decoder also uses those tables and receives `TB_FCR` and `TB_PRIMITIVE_POLYNOMIAL` through its generics. This is why the script updates both `rs_constants.vhd` and the testbench parameter package.

## Advanced: Adding primitive polynomial support

If the selected `WORD_LENGTH` and `PRIMITIVE_POLYNOMIAL` pair is not implemented in `rs_full_multiplier_core.vhd`, simulation will hit this assertion:

```text
ASSERT FAILURE - PRIMITIVE_POLYNOMIAL is not supported for this WORD_LENGTH
```

This comes from the following assertion in `rs_full_multiplier_core.vhd`:

```vhdl
assert is_primitive_polynomial_supported(WORD_LENGTH, SELECTED_PRIMITIVE_POLYNOMIAL)
    report "ASSERT FAILURE - PRIMITIVE_POLYNOMIAL is not supported for this WORD_LENGTH"
    severity failure;
```

If you hit this assertion, check whether the pair is listed in `is_primitive_polynomial_supported`. If it is missing, add a new case following the steps below.

Most constant multiplications use lookup tables generated in `rs_constants.vhd`. However, `rs_full_multiplier_core.vhd` contains explicit combinational implementations for selected primitive polynomials. If your primitive polynomial is missing there, the multiplier core must be extended too.

The example below shows how support for the GF(256) primitive polynomial `391` was added.

### 1. Convert the decimal polynomial to binary form

For GF(256), `WORD_LENGTH = 8`. Decimal `391` is:

```text
391 = 256 + 128 + 4 + 2 + 1
391 = 0b110000111
391 = x^8 + x^7 + x^2 + x + 1
```

Modulo this primitive polynomial, `x^8 + x^7 + x^2 + x + 1` is treated as zero, so:

```text
x^8 + x^7 + x^2 + x + 1 = 0
x^8 = x^7 + x^2 + x + 1
```

This first reduction is the most important line for creating the new multiplier case.

### 2. Add the polynomial to the support check

In `rs_full_multiplier_core.vhd`, update `is_primitive_polynomial_supported`:

```vhdl
elsif word_length = 8 and primitive_polynomial = 391 then
    return true;
```

Without this, the assertion at the start of the architecture will reject the configuration.

### 3. Derive all overflow reductions

For an 8-bit field, a multiplication can produce powers from `x^0` up to `x^14`. Powers `x^8` through `x^14` must be reduced back into `x^0` through `x^7`.

For primitive polynomial `391`, the reductions are:

```text
x^8  => x^7 + x^2 + x + 1
x^9  => x^7 + x^3 + 1
x^10 => x^7 + x^4 + x^2 + 1
x^11 => x^7 + x^5 + x^3 + x^2 + 1
x^12 => x^7 + x^6 + x^4 + x^3 + x^2 + 1
x^13 => x^5 + x^4 + x^3 + x^2 + 1
x^14 => x^6 + x^5 + x^4 + x^3 + x
```

The existing code stores the raw multiplication terms for these overflow powers in `w_factors_overflow(0)` through `w_factors_overflow(6)`, where:

```text
w_factors_overflow(0) = coefficient of x^8
w_factors_overflow(1) = coefficient of x^9
...
w_factors_overflow(6) = coefficient of x^14
```

The raw input products are stored in `w_and_out`. The index arrangement is:

```text
w_and_out(I)(J) = i1(I) and i2(J)
```

This is the product term for `x^(I+J)`. For example:

```text
w_and_out(0)(0) -> x^0
w_and_out(1)(0) and w_and_out(0)(1) -> x^1
w_and_out(2)(0), w_and_out(1)(1), and w_and_out(0)(2) -> x^2
```

The regular, non-overflow part of each output bit is made by XORing all `w_and_out(I)(J)` terms where `I + J` equals that output index. The overflow part is added afterwards using `w_factors_overflow`.

### 4. Add a new generate block

Create a new block following the same style as the other GF(256) cases. This is a partial skeleton; see `rs_full_multiplier_core.vhd` for the complete `gen_word_length_8_poly_391` implementation.

```vhdl
gen_word_length_8_poly_391: if WORD_LENGTH = 8 and SELECTED_PRIMITIVE_POLYNOMIAL = 391 generate
    --galois field conversion
    --x^8 = x^7 + x^2 + x + 1
    --x^8  => x^7 + x^2 + x + 1
    --x^9  => x^7 + x^3 + 1
    --x^10 => x^7 + x^4 + x^2 + 1
    --x^11 => x^7 + x^5 + x^3 + x^2 + 1
    --x^12 => x^7 + x^6 + x^4 + x^3 + x^2 + 1
    --x^13 => x^5 + x^4 + x^3 + x^2 + 1
    --x^14 => x^6 + x^5 + x^4 + x^3 + x

    --calculation for x^8
    w_factors_overflow(0) <= w_and_out(7)(1) xor
            w_and_out(6)(2) xor
            w_and_out(5)(3) xor
            w_and_out(4)(4) xor
            w_and_out(3)(5) xor
            w_and_out(2)(6) xor
            w_and_out(1)(7);

    -- Continue with x^9 through x^14, then map each
    -- w_factors_overflow bit into the output equations.
end generate;
```

Then build each output bit by XORing:

1. The normal non-overflow product terms for that bit.
2. Every `w_factors_overflow(I)` whose reduced polynomial contains that output power.

For example, the regular product terms for `o(3)` are all terms where `I + J = 3`:

```vhdl
w_and_out(3)(0) xor
w_and_out(2)(1) xor
w_and_out(1)(2) xor
w_and_out(0)(3)
```

Then add the overflow terms whose reductions contain `x^3`. For polynomial `391`, those are `w_factors_overflow(1)`, `w_factors_overflow(3)`, `w_factors_overflow(4)`, `w_factors_overflow(5)`, and `w_factors_overflow(6)`:

```vhdl
o(3) <= w_and_out(3)(0) xor
        w_and_out(2)(1) xor
        w_and_out(1)(2) xor
        w_and_out(0)(3) xor
        w_factors_overflow(1) xor
        w_factors_overflow(3) xor
        w_factors_overflow(4) xor
        w_factors_overflow(5) xor
        w_factors_overflow(6);
```

For example, since `x^8`, `x^9`, `x^10`, `x^11`, `x^12`, and `x^13` all contain the constant term `1`, `o(0)` receives overflow terms `0` through `5`:

```vhdl
o(0) <= w_and_out(0)(0) xor
        w_factors_overflow(0) xor
        w_factors_overflow(1) xor
        w_factors_overflow(2) xor
        w_factors_overflow(3) xor
        w_factors_overflow(4) xor
        w_factors_overflow(5);
```

As another example, only `x^8` and `x^14` contain `x^1`, so `o(1)` receives overflow terms `0` and `6`:

```vhdl
o(1) <= w_and_out(1)(0) xor
        w_and_out(0)(1) xor
        w_factors_overflow(0) xor
        w_factors_overflow(6);
```

Repeat this mapping for all bits `o(0)` through `o(7)`.
