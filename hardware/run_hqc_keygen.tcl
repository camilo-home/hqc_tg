if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

vcom -2008 arithmetic/poly_mul2.vhd
vcom -2008 arithmetic/sparse_xor.vhd

vcom -2008 memories/position_mem.vhd
vcom -2008 memories/ram64_sdp.vhd
vcom -2008 memories/ram64_tdp.vhd

vcom -2008 sampler/samplefxwtrej.vhd
vcom -2008 sampler/sample_vect.vhd

vcom -2008 SHA3/theta.vhd
vcom -2008 SHA3/pi.vhd
vcom -2008 SHA3/chi.vhd
vcom -2008 SHA3/rho.vhd
vcom -2008 SHA3/iota.vhd
vcom -2008 SHA3/keccak_p.vhd
vcom -2008 SHA3/keccak_c.vhd
vcom -2008 SHA3/keccak_sponge_pkg.vhd
vcom -2008 SHA3/keccak_sponge.vhd

vcom -2008 hqc_keygen.vhd
vcom -2008 tb_hqc_keygen.vhd

vsim -voptargs="+acc" work.tb_hqc_keygen