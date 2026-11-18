	jtag_comm u0 (
		.clk_clk                 (<connected-to-clk_clk>),                 //         clk.clk
		.reset_reset_n           (<connected-to-reset_reset_n>),           //       reset.reset_n
		.uart_avalon_chipselect  (<connected-to-uart_avalon_chipselect>),  // uart_avalon.chipselect
		.uart_avalon_address     (<connected-to-uart_avalon_address>),     //            .address
		.uart_avalon_read_n      (<connected-to-uart_avalon_read_n>),      //            .read_n
		.uart_avalon_readdata    (<connected-to-uart_avalon_readdata>),    //            .readdata
		.uart_avalon_write_n     (<connected-to-uart_avalon_write_n>),     //            .write_n
		.uart_avalon_writedata   (<connected-to-uart_avalon_writedata>),   //            .writedata
		.uart_avalon_waitrequest (<connected-to-uart_avalon_waitrequest>)  //            .waitrequest
	);

