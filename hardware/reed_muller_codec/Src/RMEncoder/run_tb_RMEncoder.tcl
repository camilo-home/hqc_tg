quit -sim

# 1. Definir la ruta base (la carpeta actual donde está este script .tcl)
set script_dir [file normalize [file dirname [info script]]]

cd $script_dir

# 2. Crear y mapear la librería de trabajo
vlib work
vmap work work

puts "============================================================"
puts " COMPILANDO CODIGO FUENTE (RM ENCODER)"
puts "============================================================"
# Compilar el diseño combinacional (buscándolo en la misma carpeta)
set rtl_file [file join $script_dir "RMEncoder.vhd"]
if {[file exists $rtl_file]} {
    vcom -2008 $rtl_file
} else {
    puts "ERROR: No se encontro el archivo RMEncoder.vhd en $script_dir"
}

puts "============================================================"
puts " COMPILANDO TESTBENCH"
puts "============================================================"
# Compilar el testbench (en la misma carpeta)
set tb_file [file join $script_dir "tb_RMEncoder.vhd"]
if {[file exists $tb_file]} {
    vcom -2008 $tb_file
} else {
    puts "ERROR: No se encontro el archivo tb_RMEncoder.vhd en $script_dir"
}

# 3. Iniciar Simulación
vsim work.tb_RMEncoder

# 4. Configurar Ondas
log -r /*
uplevel #0 {if {[info exists Work]} {wave clear}}

# Reloj del Testbench
add wave -radix unsigned    /tb_RMEncoder/clock

# Interfaz Combinacional RMEncoder
add wave -divider "Interfaz Combinacional RMEncoder"
add wave -radix hexadecimal /tb_RMEncoder/data_in
add wave -radix hexadecimal /tb_RMEncoder/data_out

# 5. Ejecutar simulación (El bucle de tu TB tarda 320ns, le damos 350ns para terminar)
run 2560 ns