library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axil_control_tb is
end axil_control_tb;

architecture Behavioral of axil_control_tb is

	constant clk_period: time := 8 ns; --125Mhz clk
	signal clk, rst, rstn, finished: std_logic := '0';

	--write signals
	signal awaddr: std_logic_vector(4 downto 0) := (others => '0');
	signal awvalid, awready: std_logic := '0';
	signal wdata: std_logic_vector(31 downto 0) := (others => '0');
	signal wstrb: std_logic_vector(3 downto 0) := (others => '0');
	signal wvalid, wready: std_logic := '0';
	signal bresp: std_logic_vector(1 downto 0) := (others => '0');
	signal bvalid, bready: std_logic := '0';

	--read signals
	signal araddr: std_logic_vector(4 downto 0) := (others => '0');
	signal arvalid, arready: std_logic := '0';
	signal rdata: std_logic_vector(31 downto 0) := (others => '0');
	signal rresp: std_logic_vector(1 downto 0) := (others => '0');
	signal rvalid, rready: std_logic := '0';

	--unused trustzone
	signal awprot, arprot: std_logic_vector(2 downto 0) := (others => '0');

	--control registers
	signal UARTDR: std_logic_vector(4 downto 0) := b"00000"; --address
	signal rx_fifo_data: std_logic_vector(11 downto 0) := (others => '0');
	signal rx_fifo_rd: std_logic := '0';
	signal tx_fifo_data: std_logic_vector(7 downto 0) := (others => '0');
	signal tx_fifo_wr: std_logic := '0';

	--flag register
	signal UARTFR: std_logic_vector(4 downto 0) := b"00100"; --address
	signal fifo_full, fifo_near_full, fifo_empty: std_logic := '0';
	signal tx_busy, tx_cts: std_logic := '0';

	--baudrate
	signal UARTIBRD: std_logic_vector(4 downto 0) := b"01000"; --address
	signal baud_int_div: std_logic_vector(15 downto 0) := (others => '0');
	signal UARTFBRD: std_logic_vector(4 downto 0) := b"01100"; --address
	signal baud_frac_div: std_logic_vector(5 downto 0) := (others => '0');

	--line control
	signal UARTLCR: std_logic_vector(4 downto 0) := b"10000"; --address
	signal break_gen, stop_bits: std_logic := '0';
	signal parity_config, data_bits: std_logic_vector(1 downto 0) := (others => '0');

	--control
	signal UARTCTRL: std_logic_vector(4 downto 0) := b"10100"; --address
	signal flow_ctrl_enable, rts: std_logic := '0';
	signal uart_enable, rx_enable, tx_enable: std_logic := '0';

	--fifo signals
	signal fifo_dout: std_logic_vector(7 downto 0) := (others => '0');

	type data_array is array (0 to 7) of std_logic_vector(31 downto 0);

	procedure write_axi (
			addr: in std_logic_vector(4 downto 0);
			data: in data_array;
			num_txns: in integer;
			axi_error_flag: out boolean;

			-- axi signals
			signal axil_clk:     in  std_logic;
			signal axil_awaddr:  out std_logic_vector(4 downto 0);
			signal axil_awvalid: out std_logic;
			signal axil_awready: in  std_logic;
			signal axil_wdata:   out std_logic_vector(31 downto 0);
			signal axil_wvalid:  out std_logic;
			signal axil_wready:  in  std_logic;
			signal axil_wstrb:   out std_logic_vector(3 downto 0);
			signal axil_bresp:   in  std_logic_vector(1 downto 0);
			signal axil_bvalid:  in  std_logic;
			signal axil_bready:  out std_logic
		) is
	begin
		axi_error_flag := false;

		axil_awvalid <= '1';
		axil_wvalid  <= '1';
		for i in 0 to num_txns-1 loop
			--write transaction
			axil_awaddr  <= addr;
			axil_wdata   <= data(i);
			axil_wstrb   <= "1111";
			axil_bready  <= '1';

			wait until rising_edge(axil_clk) AND
				(axil_awready = '1' AND axil_wready = '1');

			-- write response
			if i = num_txns-1 then
				axil_awvalid <= '0';
				axil_wvalid  <= '0';
			end if;
			wait until rising_edge(axil_clk) AND axil_bvalid = '1';

			axil_bready <= '0';
			if axil_bresp /= "00" then
				axi_error_flag := true;
			end if;
		end loop;
	end write_axi;

	procedure read_axi (
			addr: in std_logic_vector(4 downto 0);
			data: out data_array;
			num_txns: in integer;
			axi_error_flag: out boolean;

			-- axi signals
			signal axil_clk:     in  std_logic;
			signal axil_araddr:  out std_logic_vector(4 downto 0);
			signal axil_arvalid: out std_logic;
			signal axil_arready: in  std_logic;
			signal axil_rdata:   in  std_logic_vector(31 downto 0);
			signal axil_rresp:   in  std_logic_vector(1 downto 0);
			signal axil_rvalid:  in  std_logic;
			signal axil_rready:  out std_logic
		) is
	begin
		axi_error_flag := false;

		for i in 0 to num_txns-1 loop
			axil_araddr  <= addr;
			axil_arvalid <= '1';
			axil_rready  <= '1';
			wait until rising_edge(axil_clk) AND axil_rvalid = '1';

			data(i) := axil_rdata;
			if axil_rresp /= "00" then
				axi_error_flag := true;
			end if;
		end loop;
		axil_arvalid <= '0';
		axil_rready  <= '0';
	end read_axi;

begin

	axil_control_uut: entity work.axil_control
	Generic map(
		C_S_AXI_DATA_WIDTH => 32,
		C_S_AXI_ADDR_WIDTH => 5
	)
	Port map(
		S_AXI_ACLK	 => clk,
		S_AXI_ARESETN	 => rstn,
		S_AXI_AWADDR	 => awaddr,
		S_AXI_AWVALID	 => awvalid,
		S_AXI_AWREADY	 => awready,
		S_AXI_WDATA	 => wdata,
		S_AXI_WSTRB	 => wstrb,
		S_AXI_WVALID	 => wvalid,
		S_AXI_WREADY	 => wready,
		S_AXI_BRESP	 => bresp,
		S_AXI_BVALID	 => bvalid,
		S_AXI_BREADY	 => bready,
		S_AXI_ARADDR	 => araddr,
		S_AXI_ARVALID	 => arvalid,
		S_AXI_ARREADY	 => arready,
		S_AXI_RDATA	 => rdata,
		S_AXI_RRESP	 => rresp,
		S_AXI_RVALID	 => rvalid,
		S_AXI_RREADY	 => rready,
		S_AXI_AWPROT	 => awprot,
		S_AXI_ARPROT	 => arprot,
		rx_fifo_data	 => rx_fifo_data,
		rx_fifo_rd	 => rx_fifo_rd,
		tx_fifo_data	 => tx_fifo_data,
		tx_fifo_wr	 => tx_fifo_wr,
		rx_fifo_empty	 => fifo_empty,
		rx_fifo_full	 => fifo_full,
		tx_fifo_empty	 => fifo_empty,
		tx_fifo_full	 => fifo_full,
		tx_busy		 => tx_busy,
		tx_cts		 => tx_cts,
		baud_int_div	 => baud_int_div,
		baud_frac_div	 => baud_frac_div,
		break_gen	 => break_gen,
		stop_bits	 => stop_bits,
		parity_config	 => parity_config,
		data_bits	 => data_bits,
		flow_ctrl_enable => flow_ctrl_enable,
		rts		 => rts,
		rx_enable	 => rx_enable,
		tx_enable	 => tx_enable,
		uart_enable	 => uart_enable
	);

	fifo_uut: entity work.fifo
	Generic map(WORD_SIZE => 8, DEPTH => 3)
	Port map(
		clk	  => clk,
		rst   	  => rst,
		wr  	  => tx_fifo_wr,
		rd  	  => rx_fifo_rd,
		d_in  	  => tx_fifo_data,
		d_out 	  => fifo_dout,
		full  	  => fifo_full,
		near_full => fifo_near_full,
		empty	  => fifo_empty
	);
	--reset process
	rstn <= not rst;
	process
	begin
		rst <= '1';
		wait for clk_period;
		wait for clk_period / 2;
		rst <= '0';
		wait;
	end process;

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	--rx data needs 12 bits just prepend for test
	rx_fifo_data <= x"0" & fifo_dout;
	process
		variable mask: std_logic_vector(31 downto 0) := (others => '0');
		variable test_data: data_array := (others => (others => '0'));
		variable ret_data:  data_array := (others => (others => '0'));
		variable axi_error: boolean := false;
	begin
		wait until rising_edge(clk) AND rst = '1';
		wait for clk_period;

		-- check that empty flags are on
		read_axi(UARTFR, ret_data, 1, axi_error, clk, araddr, arvalid, arready,
			 rdata, rresp, rvalid, rready);
		if ret_data(0)(5 downto 0) /= "101000" then
			report "TEST_ERROR: axi does not report fifo empty on start";
		end if;
		ret_data := (others => (others => '0'));

		--fill up fifo
		test_data := (x"DEADBEEF", x"BEEFDEAD", x"12345678", x"87654321",
			      x"10ABCDEF", x"FFFFFFFF", x"55555555", x"1A2B3C4D");
		write_axi(UARTDR, test_data, 8, axi_error, clk, awaddr, awvalid, awready,
			  wdata, wvalid, wready, wstrb, bresp, bvalid, bready);

		--check fifo full
		read_axi(UARTFR, ret_data, 1, axi_error, clk, araddr, arvalid, arready,
			 rdata, rresp, rvalid, rready);
		if ret_data(0)(5 downto 0) /= "010100" then
			report "TEST_ERROR: axi does not report fifo empty on start";
		end if;

		-- readback data from fifo
		read_axi(UARTDR, ret_data, 8, axi_error, clk, araddr, arvalid, arready,
			 rdata, rresp, rvalid, rready);
		for i in 0 to 7 loop
			if ret_data(i)(7 downto 0) /= test_data(i)(7 downto 0) then
				report "TEST_ERROR: data register mismatch";
			end if;
		end loop;

		-- check that empty flags are on
		read_axi(UARTFR, ret_data, 1, axi_error, clk, araddr, arvalid, arready,
			 rdata, rresp, rvalid, rready);
		if ret_data(0)(5 downto 0) /= "101000" then
			report "TEST_ERROR: axi does not report fifo empty after reads";
		end if;

		--write to baud gen registers
		test_data := (x"DEADBEEF", others => (others => '0'));
		write_axi(UARTIBRD, test_data, 1, axi_error, clk, awaddr, awvalid, awready,
			  wdata, wvalid, wready, wstrb, bresp, bvalid, bready);
		-- check control out
		if baud_int_div /= test_data(0)(15 downto 0) then
			report "TEST_ERROR: integer baud divisor output not correct";
		end if;

		-- check axi readback
		read_axi(UARTIBRD, ret_data, 1, axi_error, clk, araddr, arvalid, arready,
			 rdata, rresp, rvalid, rready);
		mask := (31 downto 16 => '0') & (15 downto 0 => '1');
		if ret_data(0) /= (test_data(0) AND mask) then
			report "TEST_ERROR: integer baud divisor register readback not correct";
		end if;

		write_axi(UARTFBRD, test_data, 1, axi_error, clk, awaddr, awvalid, awready,
			  wdata, wvalid, wready, wstrb, bresp, bvalid, bready);
		-- check control out
		if baud_frac_div /= test_data(0)(5 downto 0) then
			report "TEST_ERROR: fractional baud divisor output not correct";
		end if;

		-- check axi readback
		read_axi(UARTFBRD, ret_data, 1, axi_error, clk, araddr, arvalid, arready,
			 rdata, rresp, rvalid, rready);
		mask := (31 downto 6 => '0') & (5 downto 0 => '1');
		if ret_data(0) /= (test_data(0) AND mask) then
			report "TEST_ERROR: fractional baud divisor register readback not correct";
		end if;

		-- write to line control
		test_data := (x"DEADBEEF", others => (others => '0'));
		write_axi(UARTLCR, test_data, 1, axi_error, clk, awaddr, awvalid, awready,
			  wdata, wvalid, wready, wstrb, bresp, bvalid, bready);
		if data_bits /= test_data(0)(5 downto 4) then
			report "TEST_ERROR: data bits control output not correct";
		elsif stop_bits /= test_data(0)(3) then
			report "TEST_ERROR: stop bits control output not correct";
		elsif parity_config /= test_data(0)(2 downto 1) then
			report "TEST_ERROR: parity config control output not correct";
		elsif break_gen /= test_data(0)(0) then
			report "TEST_ERROR: break gen control output not correct";
		end if;

		-- check axi readback
		read_axi(UARTLCR, ret_data, 1, axi_error, clk, araddr, arvalid, arready,
			 rdata, rresp, rvalid, rready);
		mask := (31 downto 6 => '0') & (5 downto 0 => '1');
		if ret_data(0) /= (test_data(0) AND mask) then
			report "TEST_ERROR: line control register readback not correct";
		end if;

		-- write to control
		test_data := (x"DEADBEEF", others => (others => '0'));
		write_axi(UARTCTRL, test_data, 1, axi_error, clk, awaddr, awvalid, awready,
			  wdata, wvalid, wready, wstrb, bresp, bvalid, bready);
		if flow_ctrl_enable /= test_data(0)(4) then
			report "TEST_ERROR: flow control enable output not correct";
		elsif rts /= test_data(0)(3) then
			report "TEST_ERROR: rts control output not correct";
		elsif rx_enable /= test_data(0)(2) then
			report "TEST_ERROR: rx_enable control output not correct";
		elsif tx_enable /= test_data(0)(1) then
			report "TEST_ERROR: tx_enable control output not correct";
		elsif uart_enable /= test_data(0)(0) then
			report "TEST_ERROR: uart_enable control output not correct";
		end if;

		-- check axi readback
		read_axi(UARTCTRL, ret_data, 1, axi_error, clk, araddr, arvalid, arready,
			 rdata, rresp, rvalid, rready);
		mask := (31 downto 5 => '0') & (4 downto 0 => '1');
		if ret_data(0) /= (test_data(0) AND mask) then
			report "TEST_ERROR: line control register readback not correct";
		end if;

		report "TEST_SUCCESS: end of test";
		finished <= '1';
		wait;
	end process;

end Behavioral;
