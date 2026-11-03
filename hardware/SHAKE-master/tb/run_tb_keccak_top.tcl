quit -sim

# 1. Definir la ruta del script actual (carpeta tb/)
set script_dir [file normalize [file dirname [info script]]]

# 2. Definir la ruta a la carpeta hermana (carpeta src/)
set src_dir [file normalize [file join $script_dir ".." "src"]]

cd $script_dir

# 3. Crear y mapear librería de trabajo
vlib work
vmap work work

# 4. Lista manual con ORDEN ESTRICTO (Bottom-Up)
# Se colocan los paquetes y constantes primero para evitar el error "Unknown expanded name"
set ordered_src_files [list \
    "keccak_pkg.vhd" \
    "sha3_pkg.vhd" \
    "keccak_cons.vhd" \
    "sr_reg.vhd" \
    "regn.vhd" \
    "piso.vhd" \
    "sipo.vhd" \
    "countern.vhd" \
    "keccak_round.vhd" \
    "keccak_bytepad.vhd" \
    "keccak_datapath.vhd" \
    "keccak_fsm1.vhd" \
    "keccak_fsm2.vhd" \
    "sha3_fsm3.vhd" \
    "keccak_control.vhd" \
    "keccak_top.vhd" \
]

puts "============================================================"
puts " COMPILANDO CODIGO FUENTE (ORDEN MANUAL ESTRICTO)"
puts "============================================================"

foreach file_name $ordered_src_files {
    set full_path [file join $src_dir $file_name]
    
    if {[file exists $full_path]} {
        puts "-> Compilando: $file_name"
        vcom -2008 $full_path
    } else {
        puts "-> ERROR: No se encontro el archivo $file_name en $src_dir"
    }
}

puts "============================================================"
puts " COMPILANDO TESTBENCH"
puts "============================================================"
# Compilamos el testbench que creamos (Asegurate que se llame así y esté en tb/)
vcom -2008 [file join $script_dir "tb_keccak_top.vhd"]

# 5. Iniciar Simulación
vsim work.tb_keccak_top

# 6. Configurar Ondas
log -r /*
uplevel #0 {if {[info exists Work]} {wave clear}}

# Reloj y reset
add wave -radix unsigned    /tb_keccak_top/clk
add wave -radix unsigned    /tb_keccak_top/rst

# Interfaz de Entrada (Source)
add wave -divider "Input (Absorb)"
add wave -radix unsigned    /tb_keccak_top/UUT/src_ready
add wave -radix unsigned    /tb_keccak_top/UUT/src_read
add wave -radix hexadecimal /tb_keccak_top/UUT/din

# Interfaz de Salida (Destination)
add wave -divider "Output (Squeeze)"
add wave -radix unsigned    /tb_keccak_top/UUT/dst_ready
add wave -radix unsigned    /tb_keccak_top/UUT/dst_write
add wave -radix hexadecimal /tb_keccak_top/UUT/dout

# Correr simulación
run 1500 ns