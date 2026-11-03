quit -sim

set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ../../..]]
set generic_rtl [file join $repo_root generic_components rtl]
set rs_rtl      [file join $repo_root rs_codec rtl]
set rs_sim      [file normalize [file join $script_dir ..]]

cd $script_dir

vlib work
vmap work work

# ============================================================
# 1. Compilar Componentes Genéricos (Completos)
# ============================================================
foreach file [list \
    [file join $generic_rtl generic_types.vhd] \
    [file join $generic_rtl generic_functions.vhd] \
    [file join $generic_rtl generic_components.vhd] \
    [file join $generic_rtl async_dff.vhd] \
    [file join $generic_rtl no_rst_dff.vhd] \
    [file join $generic_rtl sync_dff.vhd] \
    [file join $generic_rtl sync_dff_array.vhd] \
    [file join $generic_rtl config_dff.vhd] \
    [file join $generic_rtl config_dff_array.vhd] \
    [file join $generic_rtl reg_fifo.vhd] \
    [file join $generic_rtl reg_fifo_array.vhd] \
    [file join $generic_rtl register_shifter.vhd] \
    [file join $generic_rtl register_feedback_shifter.vhd] \
] { 
    if {[file exists $file]} { vcom -2008 $file } 
}

# ============================================================
# 2. Compilar RS RTL (Incluyendo submódulos faltantes)
# ============================================================
foreach file [list \
    [file join $rs_rtl rs_constants.vhd] \
    [file join $rs_rtl rs_types.vhd] \
    [file join $rs_rtl rs_functions.vhd] \
    [file join $rs_rtl rs_components.vhd] \
    [file join $rs_rtl rs_adder.vhd] \
    [file join $rs_rtl rs_reduce_adder.vhd] \
    [file join $rs_rtl rs_inverse.vhd] \
    [file join $rs_rtl rs_multiplier.vhd] \
    [file join $rs_rtl rs_multiplier_lut.vhd] \
    [file join $rs_rtl rs_full_multiplier.vhd] \
    [file join $rs_rtl rs_remainder_unit.vhd] \
    [file join $rs_rtl rs_syndrome_subunit.vhd] \
    [file join $rs_rtl rs_syndrome.vhd] \
    [file join $rs_rtl rs_berlekamp_massey.vhd] \
    [file join $rs_rtl rs_chien_search.vhd] \
    [file join $rs_rtl rs_chien.vhd] \
    [file join $rs_rtl rs_forney.vhd] \
    [file join $rs_rtl rs_chien_forney.vhd] \
    [file join $rs_rtl rs_decoder.vhd] \
    [file join $rs_rtl rs_encoder.vhd] \
] { 
    if {[file exists $file]} { vcom -2008 $file } 
}

# ============================================================
# 3. Compilar Parámetros y Testbench
# ============================================================
vcom -2008 [file join $rs_sim tb_rs_encoder_decoder_params.vhd]
vcom -2008 [file join $script_dir tb_rs_decoder.vhd]

# ============================================================
# 4. Simular
# ============================================================
vsim work.tb_rs_decoder
log -r /*
add wave -radix unsigned -r /*
run 3500 ns