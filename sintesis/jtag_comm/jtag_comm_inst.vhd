	component jtag_comm is
		port (
			clk_clk                 : in  std_logic                     := 'X';             -- clk
			reset_reset_n           : in  std_logic                     := 'X';             -- reset_n
			uart_avalon_chipselect  : in  std_logic                     := 'X';             -- chipselect
			uart_avalon_address     : in  std_logic                     := 'X';             -- address
			uart_avalon_read_n      : in  std_logic                     := 'X';             -- read_n
			uart_avalon_readdata    : out std_logic_vector(31 downto 0);                    -- readdata
			uart_avalon_write_n     : in  std_logic                     := 'X';             -- write_n
			uart_avalon_writedata   : in  std_logic_vector(31 downto 0) := (others => 'X'); -- writedata
			uart_avalon_waitrequest : out std_logic                                         -- waitrequest
		);
	end component jtag_comm;

	u0 : component jtag_comm
		port map (
			clk_clk                 => CONNECTED_TO_clk_clk,                 --         clk.clk
			reset_reset_n           => CONNECTED_TO_reset_reset_n,           --       reset.reset_n
			uart_avalon_chipselect  => CONNECTED_TO_uart_avalon_chipselect,  -- uart_avalon.chipselect
			uart_avalon_address     => CONNECTED_TO_uart_avalon_address,     --            .address
			uart_avalon_read_n      => CONNECTED_TO_uart_avalon_read_n,      --            .read_n
			uart_avalon_readdata    => CONNECTED_TO_uart_avalon_readdata,    --            .readdata
			uart_avalon_write_n     => CONNECTED_TO_uart_avalon_write_n,     --            .write_n
			uart_avalon_writedata   => CONNECTED_TO_uart_avalon_writedata,   --            .writedata
			uart_avalon_waitrequest => CONNECTED_TO_uart_avalon_waitrequest  --            .waitrequest
		);

