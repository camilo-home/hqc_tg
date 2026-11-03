quit -sim

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ../../..]]

set generic_rtl [file join $repo_root generic_components rtl]
set rs_rtl      [file join $repo_root rs_codec rtl]
set rs_sim      [file normalize [file join $script_dir ..]]

cd $script_dir

# Crear librería de trabajo
vlib work
vmap work work

# ============================================================
# Generic components
# ============================================================

foreach file [list \
    [file join $generic_rtl async_dff.vhd] \
    [file join $generic_rtl no_rst_dff.vhd] \
    [file join $generic_rtl generic_types.vhd] \
    [file join $generic_rtl generic_functions.vhd] \
    [file join $generic_rtl generic_components.vhd] \
] {
    vcom -2008 $file
}

# ============================================================
# Reed-Solomon
# ============================================================

foreach file [list \
    [file join $rs_rtl rs_constants.vhd] \
    [file join $rs_rtl rs_types.vhd] \
    [file join $rs_rtl rs_functions.vhd] \
    [file join $rs_rtl rs_components.vhd] \
    [file join $rs_rtl rs_adder.vhd] \
    [file join $rs_rtl rs_inverse.vhd] \
    [file join $rs_rtl rs_multiplier.vhd] \
    [file join $rs_rtl rs_multiplier_lut.vhd] \
    [file join $rs_rtl rs_remainder_unit.vhd] \
    [file join $rs_rtl rs_encoder.vhd] \
] {
    vcom -2008 $file
}

# ============================================================
# Testbench parameters
# ============================================================

vcom -2008 [file join $rs_sim tb_rs_encoder_decoder_params.vhd]

# ============================================================
# Testbench
# ============================================================

vcom -2008 [file join $script_dir tb_rs_encoder.vhd]

# ============================================================
# Simulation
# ============================================================

vsim work.tb_rs_encoder

log -r /*
add wave -radix unsigned -r /*
run 700 ns