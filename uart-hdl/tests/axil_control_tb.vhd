library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axil_control_tb is
end axil_control_tb;

architecture Behavioral of axil_control_tb is

	constant clk_period: time := 8 ns; --125Mhz clk
	signal clk, rst, rstn, finished: std_logic := '0';

	--write signals
	signal awaddr: std_logic_vector(3 downto 0) := (others => '0');
	signal awvalid, awready: std_logic := '0';
	signal wdata: std_logic_vector(31 downto 0) := (others => '0');
	signal wstrb: std_logic_vector(3 downto 0) := (others => '0');
	signal wvalid, wready: std_logic := '0';
	signal bresp: std_logic_vector(1 downto 0) := (others => '0');
	signal bvalid, bready: std_logic := '0';

	--read signals
	signal araddr: std_logic_vector(3 downto 0) := (others => '0');
	signal arvalid, arready: std_logic := '0';
	signal rdata: std_logic_vector(31 downto 0) := (others => '0');
	signal rresp: std_logic_vector(1 downto 0) := (others => '0');
	signal rvalid, rready: std_logic := '0';

	--unused trustzone
	signal awprot, arprot: std_logic_vector(2 downto 0) := (others => '0');

	--control registers
	signal UARTDR: std_logic_vector(3 downto 0) := x"0"; --address
	signal rx_fifo_data: std_logic_vector(11 downto 0) := (others => '0');
	signal rx_fifo_rd: std_logic := '0';
	signal tx_fifo_data: std_logic_vector(7 downto 0) := (others => '0');
	signal tx_fifo_wr: std_logic := '0';

	--fifo signals
	signal fifo_dout: std_logic_vector(7 downto 0) := (others => '0');
	signal fifo_full, fifo_near_full, fifo_empty: std_logic := '0';

	type addr_array is array (0 to 3) of std_logic_vector(3 downto 0);
	type data_array is array (0 to 3) of std_logic_vector(31 downto 0);

	procedure write_axi (
			addr: in addr_array;
			data: in data_array;
			num_txns: in integer;
			axi_error_flag: out boolean;

			-- axi signals
			signal axil_clk:     in  std_logic;
			signal axil_awaddr:  out std_logic_vector(3 downto 0);
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
			axil_awaddr  <= addr(i);
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
			addr: in addr_array;
			data: out data_array;
			num_txns: in integer;
			axi_error_flag: out boolean;

			-- axi signals
			signal axil_clk:     in  std_logic;
			signal axil_araddr:  out std_logic_vector(3 downto 0);
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
			axil_araddr  <= addr(i);
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
		C_S_AXI_ADDR_WIDTH => 4
	)
	Port map(
		S_AXI_ACLK	=> clk,
		S_AXI_ARESETN	=> rstn,
		S_AXI_AWADDR	=> awaddr,
		S_AXI_AWVALID	=> awvalid,
		S_AXI_AWREADY	=> awready,
		S_AXI_WDATA	=> wdata,
		S_AXI_WSTRB	=> wstrb,
		S_AXI_WVALID	=> wvalid,
		S_AXI_WREADY	=> wready,
		S_AXI_BRESP	=> bresp,
		S_AXI_BVALID	=> bvalid,
		S_AXI_BREADY	=> bready,
		S_AXI_ARADDR	=> araddr,
		S_AXI_ARVALID	=> arvalid,
		S_AXI_ARREADY	=> arready,
		S_AXI_RDATA	=> rdata,
		S_AXI_RRESP	=> rresp,
		S_AXI_RVALID	=> rvalid,
		S_AXI_RREADY	=> rready,
		S_AXI_AWPROT	=> awprot,
		S_AXI_ARPROT	=> arprot,
		rx_fifo_data	=> rx_fifo_data,
		rx_fifo_rd	=> rx_fifo_rd,
		tx_fifo_data	=> tx_fifo_data,
		tx_fifo_wr	=> tx_fifo_wr
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
		variable test_addrs: addr_array := (UARTDR, UARTDR, others => (others => '0'));
		variable test_data: data_array := (x"DEADBEEF", x"BEEFDEAD", others => (others => '0'));
		variable ret_data: data_array := (others => (others => '0'));
		variable axi_error: boolean := false;
	begin
		wait until rising_edge(clk) AND rst = '1';
		wait for clk_period;

		write_axi(test_addrs, test_data, 2, axi_error, clk, awaddr, awvalid, awready,
			  wdata, wvalid, wready, wstrb, bresp, bvalid, bready);

		read_axi(test_addrs, ret_data, 2, axi_error, clk, araddr, arvalid, arready,
			 rdata, rresp, rvalid, rready);
		for i in 0 to 1 loop
			if ret_data(i)(7 downto 0) /= test_data(i)(7 downto 0) then
				report "TEST_ERROR: data register mismatch";
			end if;
		end loop;

		report "TEST_SUCCESS: end of test";
		finished <= '1';
		wait;
	end process;

end Behavioral;
