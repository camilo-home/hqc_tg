# ============================================================================
# Script TCL para compilar y simular el multiplicador polinomial
# ============================================================================

# 1. Limpiar el entorno y crear la librería de trabajo (work)
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# 2. Compilar los archivos de memoria (ubicados en la carpeta "mem")
# Se asume el estándar VHDL-2008
vcom -work work -2008 mem/position_mem.vhd
vcom -work work -2008 mem/BRAM_singleport.vhd
vcom -work work -2008 mem/BRAM_dualport.vhd

# 3. Compilar el diseño principal y el Testbench (en el mismo nivel)
vcom -work work -2008 poly_mul.vhd
vcom -work work -2008 tb_poly_mul.vhd

# 4. Iniciar la simulación desactivando optimizaciones que ocultan señales (+acc)
vsim -voptargs=+acc work.tb_poly_mul

# 5. Configurar la ventana de formas de onda (Wave)
# -- Señales de control globales
add wave -noupdate -divider "Control Signals"
add wave -noupdate -color Yellow /tb_poly_mul/clk
add wave -noupdate -color Yellow /tb_poly_mul/rst
add wave -noupdate -color Green  /tb_poly_mul/start
add wave -noupdate -color Red    /tb_poly_mul/done

# -- Estado del FSM y Contadores internos del DUT
add wave -noupdate -divider "DUT Internal State"
add wave -noupdate /tb_poly_mul/uut/state
add wave -noupdate -radix unsigned /tb_poly_mul/uut/pos_cnt
add wave -noupdate -radix unsigned /tb_poly_mul/uut/pipe_cnt

# -- Interfaces de Memoria Dispersa (Position) y Densa
add wave -noupdate -divider "Read Interfaces"
add wave -noupdate -radix unsigned /tb_poly_mul/pm_rd_addr
add wave -noupdate -radix unsigned /tb_poly_mul/pm_rd_data
add wave -noupdate -radix unsigned /tb_poly_mul/dm_rd_addr
add wave -noupdate -radix hexadecimal /tb_poly_mul/dm_rd_data

# -- Interfaces de Memoria del Acumulador (Escritura en Puerto B)
add wave -noupdate -divider "Accumulator Write (Port B)"
add wave -noupdate /tb_poly_mul/acc_we_b
add wave -noupdate -radix unsigned /tb_poly_mul/acc_addr_b
add wave -noupdate -radix hexadecimal /tb_poly_mul/acc_din_b

# 6. Ajustar la vista y ejecutar la simulación hasta que haga stop
WaveRestoreZoom {0 ps} {200 ns}
run -all
