# hqc_kem_jtag.tcl - acceso JTAG al puente jtag_kem_bridge (USB-Blaster), para hqc_kem_top
#
# Uso (lo llama hqc_kem_jtag.py, pero tambien se puede ejecutar a mano):
#   quartus_stp -t hqc_kem_jtag.tcl id
#   quartus_stp -t hqc_kem_jtag.tcl run <trabajos.txt> <salida.txt> [timeout_ms]
#
#   trabajos.txt: una linea por trabajo:  <input 128 hex> <corrupt 5 hex> <leer_memorias 0|1>
#                 input   = seed_kem (256 bits) | m (128) | salt (128), entero little-endian de los bytes
#                 corrupt = [16] habilitar | [15:6] palabra del ct | [5:0] bit
#   salida.txt  : por trabajo
#                   R <estado hex> <resultado 640 bits hex>       (si termino)
#                   M0 <291 palabras hex>  y  M1 <555 palabras hex>   (si leer_memorias = 1)
#                 o bien  T <estado hex>  si no hubo DONE (se hace un reset por software)
#
# Variables de entorno opcionales: HQC_CABLE (indice del cable, 0), HQC_DEVICE (indice en la cadena, 0)

set IR_ID      1
set IR_INPUT   2
set IR_CTRL    3
set IR_CORRUPT 4
set IR_MEMADDR 5
set IR_MEMDATA 6
set IR_RESULT  7

set DK_WORDS 291
set CT_WORDS 555

proc open_link {} {
    global env
    set cables [get_hardware_names]
    if {[llength $cables] == 0} {
        puts "ERROR: no se encontro ningun cable USB-Blaster"
        exit 2
    }
    set ci 0
    if {[info exists env(HQC_CABLE)]} { set ci $env(HQC_CABLE) }
    set cable [lindex $cables $ci]
    set devs [get_device_names -hardware_name $cable]
    if {[llength $devs] == 0} {
        puts "ERROR: el cable $cable no ve ningun dispositivo"
        exit 2
    }
    set di 0
    if {[info exists env(HQC_DEVICE)]} { set di $env(HQC_DEVICE) }
    set dev [lindex $devs $di]
    puts "INFO: cable = $cable"
    puts "INFO: dispositivo = $dev"
    open_device -hardware_name $cable -device_name $dev
}

proc ir {v} {
    device_virtual_ir_shift -instance_index 0 -ir_value $v -no_captured_ir_value
}
proc dr_w {len hex} {
    device_virtual_dr_shift -instance_index 0 -length $len -dr_value $hex -value_in_hex -no_captured_dr_value
}
proc dr_r {len} {
    set v [device_virtual_dr_shift -instance_index 0 -length $len -value_in_hex]
    regsub {^0[xX]} $v {} v
    return $v
}

# lee el estado (CTRL, 16 bits) como entero; escribir 0 no dispara nada
proc read_status {} {
    global IR_CTRL
    ir $IR_CTRL
    set st [dr_r 16]
    scan $st %x stv
    return $stv
}

proc cmd_id {} {
    global IR_ID
    device_lock -timeout 10000
    ir $IR_ID
    set v [dr_r 32]
    device_unlock
    puts "ID = $v"
    if {[string toupper $v] eq "48514332"} {
        puts "OK: puente HQC (kem_top) detectado"
    } else {
        puts "ERROR: ID inesperado (se esperaba 48514332). Esta cargado el .sof correcto?"
        exit 3
    }
}

# lee 'count' palabras de la memoria 'sel' (0 dk_ram, 1 ct_ram)
proc read_memory {sel count timeout_ms} {
    global IR_MEMADDR IR_MEMDATA IR_CTRL
    set words {}
    for {set a 0} {$a < $count} {incr a} {
        ir $IR_MEMADDR
        dr_w 11 [format %03x [expr {($sel << 10) | $a}]]
        set t0 [clock milliseconds]
        set ok 0
        while {([clock milliseconds] - $t0) < $timeout_ms} {
            set stv [read_status]
            if {($stv >> 6) & 1} { set ok 1; break }
        }
        if {!$ok} { puts "AVISO: la memoria $sel no contesto en la direccion $a"; return $words }
        ir $IR_MEMDATA
        lappend words [dr_r 64]
    }
    return $words
}

proc cmd_run {jobfile outfile timeout_ms} {
    global IR_INPUT IR_CTRL IR_CORRUPT IR_RESULT DK_WORDS CT_WORDS

    set fi [open $jobfile r]
    set fo [open $outfile w]
    set n 0

    device_lock -timeout 10000
    while {[gets $fi line] >= 0} {
        set line [string trim $line]
        if {$line eq ""} { continue }
        incr n
        set input   [lindex $line 0]
        set corrupt [lindex $line 1]
        set readmem [lindex $line 2]

        # 1) entradas, 2) start
        ir $IR_INPUT;   dr_w 512 $input
        ir $IR_CORRUPT; dr_w 17 $corrupt
        ir $IR_CTRL;    dr_w 16 0001

        # 3) esperar DONE (bit0). Leer CTRL escribe 0: no lanza nada
        set t0 [clock milliseconds]
        set ok 0
        while {([clock milliseconds] - $t0) < $timeout_ms} {
            set stv [read_status]
            if {$stv & 1} { set ok 1; break }
        }
        if {!$ok} {
            puts "AVISO: trabajo $n sin DONE tras $timeout_ms ms (estado = [format %04x $stv])"
            puts $fo "T [format %04x $stv]"
            ir $IR_CTRL
            dr_w 16 0002
            after 10
            continue
        }

        # 4) resultado (640 bits)
        set stv [read_status]
        ir $IR_RESULT
        set res [dr_r 640]
        puts $fo "R [format %04x $stv] $res"
        puts "INFO: trabajo $n terminado"

        # 5) memorias (opcional)
        if {$readmem == 1} {
            puts $fo "M0 [join [read_memory 0 $DK_WORDS 2000] { }]"
            puts $fo "M1 [join [read_memory 1 $CT_WORDS 2000] { }]"
        }
    }
    device_unlock
    close $fi
    close $fo
}

# ---------------- main ----------------
if {[llength $quartus(args)] < 1} {
    puts "uso: quartus_stp -t hqc_kem_jtag.tcl id | run <trabajos.txt> <salida.txt> \[timeout_ms\]"
    exit 1
}
set cmd [lindex $quartus(args) 0]

open_link
switch -- $cmd {
    id  { cmd_id }
    run {
        set tmo 60000
        if {[llength $quartus(args)] > 3} { set tmo [lindex $quartus(args) 3] }
        cmd_run [lindex $quartus(args) 1] [lindex $quartus(args) 2] $tmo
    }
    default { puts "comando desconocido: $cmd"; exit 1 }
}
close_device
