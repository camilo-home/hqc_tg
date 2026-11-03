quit -sim

set script_dir [file normalize [file dirname [info script]]]
set src_dir    [file join $script_dir src]
set tb_dir     [file join $script_dir tb]

cd $script_dir

# 1. Crear y mapear librería de trabajo
vlib work
vmap work work

puts "============================================================"
puts " 1. COMPILANDO CODIGO FUENTE (Desde src/source_list.txt)"
puts "============================================================"
set src_list_file [file join $src_dir "source_list.txt"]

if {[file exists $src_list_file]} {
    set fp [open $src_list_file r]
    set src_data [read $fp]
    close $fp

    foreach line [split $src_data "\n"] {
        set file_name [string trim $line]
        if {$file_name ne ""} {
            set full_path [file join $src_dir $file_name]
            if {[file exists $full_path]} {
                puts "-> Compilando src: $file_name"
                vcom -2008 $full_path
            } else {
                puts "-> ADVERTENCIA: $file_name no existe en src/"
            }
        }
    }
} else {
    puts "ERROR: No se encontro el archivo $src_list_file"
}

puts "============================================================"
puts " 2. COMPILANDO ENTORNO DE PRUEBAS (Desde tb/tb_source_list.txt)"
puts "============================================================"
set tb_list_file [file join $tb_dir "tb_source_list.txt"]

if {[file exists $tb_list_file]} {
    set fp [open $tb_list_file r]
    set tb_data [read $fp]
    close $fp

    foreach line [split $tb_data "\n"] {
        set file_name [string trim $line]
        if {$file_name ne ""} {
            set full_path [file join $tb_dir $file_name]
            if {[file exists $full_path]} {
                puts "-> Compilando tb: $file_name"
                vcom -2008 $full_path
            } else {
                puts "-> ADVERTENCIA: $file_name no existe en tb/"
            }
        }
    }
} else {
    puts "ERROR: No se encontro el archivo $tb_list_file"
}

puts "============================================================"
puts " 3. INICIANDO SIMULACION"
puts "============================================================"
# La entidad principal del archivo sha_tb_all.vhd
vsim work.sha_tb_all

# 4. Configurar Ondas
log -r /*
uplevel #0 {if {[info exists Work]} {wave clear}}

# Añadir las señales de la UUT y el generador de pruebas
add wave -radix hexadecimal /sha_tb_all/*

# El testbench oficial suele leer múltiples vectores, le damos suficiente tiempo

run 5000 ns