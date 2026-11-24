if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# modulos de aritmetica
vcom -2008 arithmetic/poly_mul2.vhd
vcom -2008 arithmetic/sparse_xor.vhd

# memorias
vcom -2008 memories/position_mem.vhd
vcom -2008 memories/ram64_sdp.vhd
vcom -2008 memories/ram64_tdp.vhd

# muestreadores de vectores
vcom -2008 sampler/samplefxwtmod.vhd
vcom -2008 sampler/samplefxwtrej.vhd
vcom -2008 sampler/sample_vect.vhd

# sha3
vcom -2008 sha3/theta.vhd
vcom -2008 sha3/pi.vhd
vcom -2008 sha3/chi.vhd
vcom -2008 sha3/rho.vhd
vcom -2008 sha3/iota.vhd
vcom -2008 sha3/keccak_p.vhd
vcom -2008 sha3/keccak_c.vhd
vcom -2008 sha3/keccak_sponge_pkg.vhd
vcom -2008 sha3/keccak_sponge.vhd

# reed-solomon codec
# generic
vcom -2008 reed-solomon-46-16/generic/generic_types.vhd
vcom -2008 reed-solomon-46-16/generic/generic_functions.vhd
vcom -2008 reed-solomon-46-16/generic/async_dff.vhd
vcom -2008 reed-solomon-46-16/generic/async_dff_gen_rst.vhd
vcom -2008 reed-solomon-46-16/generic/config_dff_array.vhd
vcom -2008 reed-solomon-46-16/generic/d_sync_flop.vhd
vcom -2008 reed-solomon-46-16/generic/no_rst_dff.vhd
vcom -2008 reed-solomon-46-16/generic/sync_dff_gen_rst.vhd
vcom -2008 reed-solomon-46-16/generic/async_dff_array.vhd
vcom -2008 reed-solomon-46-16/generic/sync_dff_array.vhd
vcom -2008 reed-solomon-46-16/generic/reg_fifo_array.vhd
vcom -2008 reed-solomon-46-16/generic/reg_fifo.vhd
vcom -2008 reed-solomon-46-16/generic/generic_components.vhd
vcom -2008 reed-solomon-46-16/generic/sync_ld_dff.vhd
vcom -2008 reed-solomon-46-16/generic/flop_cascade.vhd

# rtl
vcom -2008 reed-solomon-46-16/rtl/rs_constants.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_types.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_functions.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_components.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_adder.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_inverse.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_multiplier.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_multiplier_lut.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_reduce_adder.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_remainder_unit.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_full_multiplier.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_full_multiplier_core.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_syndrome_subunit.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_syndrome.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_berlekamp_massey.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_chien_forney.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_chien.vhd
vcom -2008 reed-solomon-46-16/rtl/rs_forney.vhd

# rs top
vcom -2008 reed-solomon-46-16/rs_encoder.vhd
vcom -2008 reed-solomon-46-16/rs_decoder.vhd

# reed-muller codec
# encoder
vcom -2008 reed-muller-x3/rm_encoder.vhd
vcom -2008 reed-muller-x3/rm_decoder.vhd

# modulos hqc top
#vcom -2008 hqc_top/hqc_keygen/hqc_keygen.vhd
#vcom -2008 hqc_top/hqc_keygen/tb_hqc_keygen.vhd

#vcom -2008 hqc_top/hqc_encaps/hqc_encaps.vhd
#vcom -2008 hqc_top/hqc_encaps/tb_hqc_encaps.vhd

#vcom -2008 hqc_top/hqc_decaps/hqc_decaps.vhd
#vcom -2008 hqc_top/hqc_decaps/tb_hqc_decaps.vhd
