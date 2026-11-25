# Restricciones de tiempo para hqc_kem_top (DE2-115, reloj de 50 MHz)
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_pll_clocks
derive_clock_uncertainty

# El reloj JTAG (TCK) es asincrono respecto a CLOCK_50: el puente cruza con sincronizadores de 2 FF
# y los registros INPUT / CORRUPT / MEM* / RESULT son estaticos cuando se leen.
set_clock_groups -asynchronous -group [get_clocks {CLOCK_50}] -group [get_clocks {altera_reserved_tck}]

# Pulsadores y LEDs: no son criticos
set_false_path -from [get_ports {KEY[*]}]
set_false_path -to   [get_ports {LEDG[*] LEDR[*]}]
