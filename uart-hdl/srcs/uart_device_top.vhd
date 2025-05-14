library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_device_top is
	generic (
		-- Parameters of Axi Slave Bus Interface S00_AXI
		C_S00_AXI_DATA_WIDTH	: integer	:= 32;
		C_S00_AXI_ADDR_WIDTH	: integer	:= 6
	);
	port (
		-- AXI signals
		S00_AXI_ACLK	: in  std_logic;
		S00_AXI_ARESETN	: in  std_logic;
		S00_AXI_AWADDR	: in  std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		S00_AXI_AWVALID	: in  std_logic;
		S00_AXI_AWREADY	: out std_logic;
		S00_AXI_WDATA	: in  std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		S00_AXI_WSTRB	: in  std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
		S00_AXI_WVALID	: in  std_logic;
		S00_AXI_WREADY	: out std_logic;
		S00_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S00_AXI_BVALID	: out std_logic;
		S00_AXI_BREADY	: in  std_logic;
		S00_AXI_ARADDR	: in  std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
		S00_AXI_ARVALID	: in  std_logic;
		S00_AXI_ARREADY	: out std_logic;
		S00_AXI_RDATA	: out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
		S00_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S00_AXI_RVALID	: out std_logic;
		S00_AXI_RREADY	: in  std_logic;

		-- TrustZone not supported
		S00_AXI_AWPROT	: in  std_logic_vector(2 downto 0);
		S00_AXI_ARPROT	: in  std_logic_vector(2 downto 0);

		-- uart top-level signals
		uart_rstn	: in  std_logic;
		uart_ctsn	: in  std_logic;
		uart_rtsn	: out std_logic;
		uart_rx		: in  std_logic;
		uart_tx		: out std_logic;

		-- interrupts
		uart_tx_intr	: out std_logic;
		uart_rx_intr	: out std_logic;
		uart_er_intr	: out std_logic;
		uart_fc_intr	: out std_logic;
		uart_intr	: out std_logic
	);
end uart_device_top;

architecture Behavioral of uart_device_top is

	--global signals
	signal clk, rst: std_logic := '0';

	-- axil control i/o
	-- lcr
	signal stop_bits, break_gen: std_logic := '0';
	signal parity_ctrl, data_bits: std_logic_vector(1 downto 0) := (others => '0');
	-- ctrl
	signal flow_ctrl_enable, rts: std_logic := '0';
	signal uart_enable, uart_tx_enable, uart_rx_enable: std_logic := '0';
	--intr mask
	signal intr_mask: std_logic_vector(6 downto 0) := (others => '0');
	signal intr_masked_sts: std_logic_vector(6 downto 0) := (others => '0');
	signal intr_raw_sts: std_logic_vector(6 downto 0) := (others => '0');
	signal intr_clear: std_logic_vector(6 downto 0) := (others => '0');
	signal intr_clear_valid: std_logic := '0';

	-- baud rate i/o
	signal s_tick: std_logic := '0';
	signal baud_int_div: std_logic_vector(15 downto 0);
	signal baud_frac_div: std_logic_vector(5 downto 0);

	-- rx fifo i/o
	signal rx_fifo_data_oe: std_logic_vector(11 downto 0);
	signal rx_fifo_data_in, rx_fifo_data_out: std_logic_vector(10 downto 0);
	signal rx_fifo_rd: std_logic := '0';
	signal rx_fifo_full, rx_fifo_near_full: std_logic := '0';
	signal rx_fifo_empty, rx_fifo_near_empty: std_logic := '0';
	signal overrun_error: std_logic := '0';

	-- rx i/o
	signal rx_enable, rx_done: std_logic := '0';
	signal parity_error, frame_error, break_error: std_logic := '0';
	signal rx_data_out: std_logic_vector(7 downto 0);

	-- tx fifo i/o
	signal tx_fifo_data_in, tx_fifo_data_out: std_logic_vector(7 downto 0);
	signal tx_fifo_wr: std_logic := '0';
	signal tx_fifo_full, tx_fifo_near_full: std_logic := '0';
	signal tx_fifo_empty, tx_fifo_near_empty: std_logic := '0';
	signal tx_busy, tx_cts: std_logic := '0';

	-- tx i/o
	signal tx_enable, tx_start, tx_done: std_logic := '0';
begin

	--global signal assignment
	rst <= not uart_rstn;
	clk <= S00_AXI_ACLK;

	----------------------
	-- AXI-LITE CONTROL --
	----------------------
	--axi instantiation
	axil_control: entity work.axil_control
	Generic map(
		C_S_AXI_DATA_WIDTH => C_S00_AXI_DATA_WIDTH,
		C_S_AXI_ADDR_WIDTH => C_S00_AXI_ADDR_WIDTH
	)
	Port map(
		S_AXI_ACLK	 => S00_AXI_ACLK,
		S_AXI_ARESETN	 => S00_AXI_ARESETN,
		S_AXI_AWADDR	 => S00_AXI_AWADDR,
		S_AXI_AWVALID	 => S00_AXI_AWVALID,
		S_AXI_AWREADY	 => S00_AXI_AWREADY,
		S_AXI_WDATA	 => S00_AXI_WDATA,
		S_AXI_WSTRB	 => S00_AXI_WSTRB,
		S_AXI_WVALID	 => S00_AXI_WVALID,
		S_AXI_WREADY	 => S00_AXI_WREADY,
		S_AXI_BRESP	 => S00_AXI_BRESP,
		S_AXI_BVALID	 => S00_AXI_BVALID,
		S_AXI_BREADY	 => S00_AXI_BREADY,
		S_AXI_ARADDR	 => S00_AXI_ARADDR,
		S_AXI_ARVALID	 => S00_AXI_ARVALID,
		S_AXI_ARREADY	 => S00_AXI_ARREADY,
		S_AXI_RDATA	 => S00_AXI_RDATA,
		S_AXI_RRESP	 => S00_AXI_RRESP,
		S_AXI_RVALID	 => S00_AXI_RVALID,
		S_AXI_RREADY	 => S00_AXI_RREADY,
		S_AXI_AWPROT	 => S00_AXI_AWPROT,
		S_AXI_ARPROT	 => S00_AXI_ARPROT,
		rx_fifo_data	 => rx_fifo_data_oe,
		rx_fifo_rd	 => rx_fifo_rd,
		rx_fifo_empty	 => rx_fifo_empty,
		rx_fifo_full	 => rx_fifo_full,
		tx_fifo_data	 => tx_fifo_data_in,
		tx_fifo_wr	 => tx_fifo_wr,
		tx_fifo_empty	 => tx_fifo_empty,
		tx_fifo_full	 => tx_fifo_full,
		tx_busy		 => tx_busy,
		tx_cts		 => tx_cts,
		baud_int_div	 => baud_int_div,
		baud_frac_div	 => baud_frac_div,
		break_gen	 => break_gen,
		stop_bits	 => stop_bits,
		parity_config	 => parity_ctrl,
		data_bits	 => data_bits,
		flow_ctrl_enable => flow_ctrl_enable,
		rts		 => rts,
		rx_enable	 => uart_rx_enable,
		tx_enable	 => uart_tx_enable,
		uart_enable	 => uart_enable,
		intr_mask	 => intr_mask,
		intr_masked_sts	 => intr_masked_sts,
		intr_raw_sts	 => intr_raw_sts,
		intr_clear_valid => intr_clear_valid,
		intr_clear	 => intr_clear
	);

	-- assign contrl signals
	tx_busy   <= not tx_fifo_empty;
	tx_cts    <= not uart_ctsn;
	uart_rtsn <= not rts;

	-------------------------
	-- BAUD RATE GENERATOR --
	-------------------------
	-- baud generator instantiation
	baud_gen: entity work.baud_generator
	Port map(
		clk	 => clk,
		rst	 => rst,
		int_div	 => baud_int_div,
		frac_div => baud_frac_div,
		s_tick	 => s_tick
	);

	-------------------------------
	-- UART RECEIVER AND RX FIFO --
	-------------------------------
	-- rx fifo instantiation
	rx_fifo_data_in <= break_error & parity_error & frame_error & rx_data_out;
	rx_fifo: entity work.fifo
	Generic map(WORD_SIZE => 11, DEPTH => 5)
	Port map(
		clk	   => clk,
		rst	   => rst,
		wr	   => rx_done,
		rd	   => rx_fifo_rd,
		d_in	   => rx_fifo_data_in,
		d_out	   => rx_fifo_data_out,
		full	   => rx_fifo_full,
		near_full  => rx_fifo_near_full,
		near_empty => rx_fifo_near_empty,
		empty	   => rx_fifo_empty
	);

	-- receiver instantiation
	rx_enable <= uart_rx_enable AND uart_enable;
	rx: entity work.uart_rx
	Generic map(S_TICKS_PER_BAUD => 16, DATA_BITS_MAX => 8)
	Port map(
		clk	     => clk,
		rst	     => rst,
		en	     => rx_enable,
		rx	     => uart_rx,
		s_tick	     => s_tick,
		stop_bits    => stop_bits,
		parity_ctrl  => parity_ctrl,
		data_bits    => data_bits,
		rx_done	     => rx_done,
		parity_error => parity_error,
		frame_error  => frame_error,
		break_error  => break_error,
		data_out     => rx_data_out
	);

	-- rx overrun error assignment
	rx_fifo_data_oe <= overrun_error & rx_fifo_data_out;
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				overrun_error <= '0';
			elsif overrun_error = '1' AND rx_fifo_full = '0' then
				overrun_error <= '0';
			elsif rx_fifo_full = '1' AND rx_done = '1' then
				overrun_error <= '1';
			end if;
		end if;
	end process;

	----------------------------------
	-- UART TRANSMITTER AND TX FIFO --
	----------------------------------
	-- tx fifo instantiation
	tx_fifo: entity work.fifo
	Generic map(WORD_SIZE => 8, DEPTH => 5)
	Port map(
		clk	   => clk,
		rst	   => rst,
		wr	   => tx_fifo_wr,
		rd	   => tx_done,
		d_in	   => tx_fifo_data_in,
		d_out	   => tx_fifo_data_out,
		full	   => tx_fifo_full,
		near_full  => tx_fifo_near_full,
		near_empty => tx_fifo_near_empty,
		empty	   => tx_fifo_empty
	);

	-- transmitter instantiation
	tx_enable <= tx_cts AND uart_enable AND uart_tx_enable when flow_ctrl_enable = '1'
		     else uart_enable AND uart_tx_enable;
	tx_start  <= not tx_fifo_empty;
	tx: entity work.uart_tx
	Generic map(S_TICKS_PER_BAUD => 16, DATA_BITS_MAX => 8)
	Port map(
		clk	    => clk,
		rst	    => rst,
		en	    => tx_enable,
		tx_start    => tx_start,
		s_tick	    => s_tick,
		break_gen   => break_gen,
		stop_bits   => stop_bits,
		parity_ctrl => parity_ctrl,
		data_bits   => data_bits,
		data_in	    => tx_fifo_data_out,
		tx_done	    => tx_done,
		tx	    => uart_tx
	);

	--------------------------
	-- Interrupt Generation --
	--------------------------
	-- interrupt generation instantiation
	interrupt_generation: entity work.interrupt_generation
	Port map(
		clk		   => clk,
		rst		   => rst,
		tx_near_empty_flag => tx_fifo_near_empty,
		rx_near_full_flag  => rx_fifo_near_full,
		rx_parity_err	   => parity_error,
		rx_frame_err	   => frame_error,
		rx_break_err	   => break_error,
		rx_overrun_err	   => overrun_error,
		uart_ctsn	   => uart_ctsn,
		intr_mask	   => intr_mask,
		intr_clear	   => intr_clear,
		intr_clear_valid   => intr_clear_valid,
		intr_status_mask   => intr_masked_sts,
		intr_status_raw	   => intr_raw_sts,
		uart_tx_intr	   => uart_tx_intr,
		uart_rx_intr	   => uart_rx_intr,
		uart_er_intr	   => uart_er_intr,
		uart_fc_intr	   => uart_fc_intr,
		uart_intr	   => uart_intr
	);

end Behavioral;
