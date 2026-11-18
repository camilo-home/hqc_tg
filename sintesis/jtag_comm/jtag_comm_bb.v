
module jtag_comm (
	clk_clk,
	reset_reset_n,
	uart_avalon_chipselect,
	uart_avalon_address,
	uart_avalon_read_n,
	uart_avalon_readdata,
	uart_avalon_write_n,
	uart_avalon_writedata,
	uart_avalon_waitrequest);	

	input		clk_clk;
	input		reset_reset_n;
	input		uart_avalon_chipselect;
	input		uart_avalon_address;
	input		uart_avalon_read_n;
	output	[31:0]	uart_avalon_readdata;
	input		uart_avalon_write_n;
	input	[31:0]	uart_avalon_writedata;
	output		uart_avalon_waitrequest;
endmodule
