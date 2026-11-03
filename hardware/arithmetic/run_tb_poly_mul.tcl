vdel -lib work -all

vlib work
vmap work work

vcom -work work -2008 ../memories/position_mem.vhd
vcom -work work -2008 ../memories/bram_singleport.vhd
vcom -work work -2008 ../memories/bram_dualport.vhd

vcom -work work -2008 poly_mul.vhd
vcom -work work -2008 top_poly_mul.vhd
vcom -work work -2008 tb_top_poly_mul.vhd

