library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axil_control is
	generic (
		-- Width of S_AXI data bus
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		-- Width of S_AXI address bus
		C_S_AXI_ADDR_WIDTH	: integer	:= 6
	);
	port (
		-- AXI signals
		S_AXI_ACLK	 : in  std_logic;
		S_AXI_ARESETN	 : in  std_logic;
		S_AXI_AWADDR	 : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWVALID	 : in  std_logic;
		S_AXI_AWREADY	 : out std_logic;
		S_AXI_WDATA	 : in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	 : in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	 : in  std_logic;
		S_AXI_WREADY	 : out std_logic;
		S_AXI_BRESP	 : out std_logic_vector(1 downto 0);
		S_AXI_BVALID	 : out std_logic;
		S_AXI_BREADY	 : in  std_logic;
		S_AXI_ARADDR	 : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARVALID	 : in  std_logic;
		S_AXI_ARREADY	 : out std_logic;
		S_AXI_RDATA	 : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	 : out std_logic_vector(1 downto 0);
		S_AXI_RVALID	 : out std_logic;
		S_AXI_RREADY	 : in  std_logic;

		-- Ignored, TrustZone not supported
		S_AXI_AWPROT	 : in  std_logic_vector(2 downto 0);
		S_AXI_ARPROT	 : in  std_logic_vector(2 downto 0);

		-- Control signals
		-- UARTDR (data register)
		rx_fifo_data	 : in  std_logic_vector(11 downto 0); --rx-fifo data including status
		rx_fifo_rd	 : out std_logic;
		tx_fifo_data	 : out std_logic_vector(7 downto 0);
		tx_fifo_wr	 : out std_logic;

		-- UARTFR (flag register)
		rx_fifo_empty	 : in  std_logic;
		rx_fifo_full	 : in  std_logic;
		tx_fifo_empty	 : in  std_logic;
		tx_fifo_full	 : in  std_logic;
		tx_busy		 : in  std_logic;
		tx_cts		 : in  std_logic;

		-- UARTIBRD (baud rate divisor integer part)
		baud_int_div	 : out std_logic_vector(15 downto 0);

		-- UARTFBRD (baud rate divisor fractional part)
		baud_frac_div	 : out std_logic_vector(5 downto 0);

		-- UARTLCR (line control register)
		break_gen	 : out std_logic;
		stop_bits	 : out std_logic;
		parity_config	 : out std_logic_vector(1 downto 0);
		data_bits	 : out std_logic_vector(1 downto 0);

		-- UARTCTRL (control register)
		flow_ctrl_enable : out std_logic;
		rts		 : out std_logic;
		rx_enable	 : out std_logic;
		tx_enable	 : out std_logic;
		uart_enable	 : out std_logic;

		-- UARTIMASK (interrupt mask register)
		intr_mask	 : out std_logic_vector(6 downto 0);

		-- UARTIMSTS (interrupt masked status register)
		intr_masked_sts	 : in  std_logic_vector(6 downto 0);

		-- UARTIRSTS (interrupt raw status register)
		intr_raw_sts	 : in  std_logic_vector(6 downto 0);

		-- UARTIRSTS (interrupt raw status register)
		intr_clear_valid : out std_logic;
		intr_clear	 : out std_logic_vector(6 downto 0)
	);
end axil_control;

architecture Behavioral of axil_control is

	constant ADDR_LSB	   : integer := C_S_AXI_DATA_WIDTH/32 + 1;
	constant OPT_MEM_ADDR_BITS : integer := C_S_AXI_ADDR_WIDTH - ADDR_LSB - 1;

	signal clk, rst: std_logic := '0';

	-- write logic signals
	signal axil_awaddr: std_logic_vector(OPT_MEM_ADDR_BITS + ADDR_LSB downto ADDR_LSB) := (others => '0');
	signal axil_wdata: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
	signal axil_wstrb: std_logic_vector(C_S_AXI_DATA_WIDTH/8-1 downto 0) := (others => '0');

	-- write control outputs
	signal axil_write_ready, axil_write_ready_next: std_logic := '0';
	signal axil_bvalid, axil_bvalid_next: std_logic := '0';

	-- read logic signals
	signal axil_araddr: std_logic_vector(OPT_MEM_ADDR_BITS + ADDR_LSB downto ADDR_LSB) := (others => '0');

	-- read control outputs
	signal axil_read_ready: std_logic := '0';
	signal axil_rdata: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');
	signal axil_arready: std_logic := '0';
	signal axil_rvalid, axil_rvalid_next: std_logic := '0';

	-- target registers
	-- UART DR (data register)
	-- there is no actual register here, writes and reads go directly to external fifos

	-- UART FR (flag register)
	-- there is no actual register here, read only address returns flags

	-- UART IBRD (Baud rate divisor - integer part)
	signal ibrd_reg, ibrd_next: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

	-- UART FBRD (Baud rate divisor - fractional part)
	signal fbrd_reg, fbrd_next: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

	-- UART LCR (Line control register)
	signal lcr_reg, lcr_next: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

	-- UART CTRL (Control register)
	signal ctrl_reg, ctrl_next: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

	-- UART IMASK (interrupt mask register)
	signal imask_reg, imask_next: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

	-- UART IMSTS (interrupt mask status register)
	-- there is no actual register here, read only address returns masked status

	-- UART IRSTS (interrupt raw status register)
	-- there is no actual register here, read only address returns raw status

	-- UART ICLR (interrupt clear register)
	-- there is no actual register here, writes go directly to external interrupt module

	-- function to apply write strobe to target registers
	function apply_wstrb (
		old_data : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		new_data : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		wstrb	 : in std_logic_vector(C_S_AXI_DATA_WIDTH/8-1 downto 0)
	) return std_logic_vector is
		variable result: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
	begin
		for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
			if wstrb(byte_index) = '1' then
				result(byte_index*8+7 downto byte_index*8) :=
					new_data(byte_index*8+7 downto byte_index*8);
			else
				result(byte_index*8+7 downto byte_index*8) :=
					old_data(byte_index*8+7 downto byte_index*8);
			end if;
		end loop;
		return result;
	end function;
begin

	rst <= not S_AXI_ARESETN;
	clk <= S_AXI_ACLK;

	--write signal hookup
	--inputs
	axil_awaddr  <= S_AXI_AWADDR(OPT_MEM_ADDR_BITS + ADDR_LSB downto ADDR_LSB);
	axil_wdata   <= S_AXI_WDATA;
	axil_wstrb   <= S_AXI_WSTRB;
	--outputs (must be registered according to spec)
	S_AXI_AWREADY <= axil_write_ready;
	S_AXI_WREADY  <= axil_write_ready;
	S_AXI_BVALID  <= axil_bvalid;
	S_AXI_BRESP   <= b"00"; --OK

	--write register process
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				axil_write_ready <= '0';
				axil_bvalid <= '0';

				ibrd_reg <= (others => '0');
				fbrd_reg <= (others => '0');
				lcr_reg  <= (others => '0');
				ctrl_reg <= (others => '0');
				imask_reg <= (others => '0');
			else
				axil_bvalid <= axil_bvalid_next;
				axil_write_ready <= axil_write_ready_next;

				if axil_write_ready = '1' then
					case axil_awaddr is
					-- No register for "0000", write will go directly to txfifo
					-- No register for "0001", it is read only flag register
					when "0010" =>
						-- baud rate integer register
						ibrd_reg <= ibrd_next;
					when "0011" =>
						-- baud rate fractional register
						fbrd_reg <= fbrd_next;
					when "0100" =>
						-- line control register
						lcr_reg <= lcr_next;
					when "0101" =>
						-- control register
						ctrl_reg <= ctrl_next;
					when "0110" =>
						-- interrupt mask register
						imask_reg <= imask_next;
					-- No register for "0111", it is read only masked interrupt status
					-- No register for "1000", it is read only raw interrupt status
					-- No register for "1001", write will go directly to interrupt module
					when others =>
						null;
					end case;
				end if;
			end if;
		end if;
	end process;

	--write control next state logic
	process(S_AXI_AWVALID, axil_wdata, S_AXI_WVALID, axil_wstrb, axil_write_ready,
		S_AXI_BREADY, axil_bvalid, ibrd_reg, fbrd_reg, lcr_reg, ctrl_reg, imask_reg)
	begin
		axil_bvalid_next <= axil_bvalid;
		if axil_write_ready = '1' then
			axil_bvalid_next <= '1';
		elsif S_AXI_BREADY = '1' then
			axil_bvalid_next <= '0';
		end if;

		axil_write_ready_next <= (not axil_write_ready) AND
					 (S_AXI_AWVALID AND S_AXI_WVALID) AND
					 ((not axil_bvalid) OR S_AXI_BREADY);

		--programmable registers
		tx_fifo_data <= apply_wstrb(axil_wdata, axil_wdata, axil_wstrb)(7 downto 0);
		ibrd_next  <= (C_S_AXI_DATA_WIDTH-1 downto 16 => '0')
			      & apply_wstrb(ibrd_reg, axil_wdata, axil_wstrb)(15 downto 0);
		fbrd_next  <= (C_S_AXI_DATA_WIDTH-1 downto 6 => '0')
			      & apply_wstrb(fbrd_reg, axil_wdata, axil_wstrb)(5 downto 0);
		lcr_next   <= (C_S_AXI_DATA_WIDTH-1 downto 6 => '0')
			      & apply_wstrb(lcr_reg, axil_wdata, axil_wstrb)(5 downto 0);
		ctrl_next  <= (C_S_AXI_DATA_WIDTH-1 downto 5 => '0')
			     & apply_wstrb(ctrl_reg, axil_wdata, axil_wstrb)(4 downto 0);
		imask_next <= (C_S_AXI_DATA_WIDTH-1 downto 7 => '0')
			     & apply_wstrb(imask_reg, axil_wdata, axil_wstrb)(6 downto 0);
		intr_clear <= apply_wstrb(axil_wdata, axil_wdata, axil_wstrb)(6 downto 0);
	end process;

	--read signal hookup
	--inputs
	axil_araddr <= S_AXI_ARADDR(OPT_MEM_ADDR_BITS + ADDR_LSB downto ADDR_LSB);
	--outputs (must be registered according to spec)
	axil_read_ready <= axil_arready AND S_AXI_ARVALID;
	S_AXI_ARREADY <= axil_arready;
	S_AXI_RDATA   <= axil_rdata;
	S_AXI_RVALID  <= axil_rvalid;
	S_AXI_RRESP   <= b"00"; --OK

	--read register process
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				axil_rvalid <= '0';
				axil_arready <= '0';
				axil_rdata <= (others => '0');
			else
				axil_rvalid <= axil_rvalid_next;
				axil_arready <= not axil_rvalid_next;

				if ((not axil_rvalid) OR S_AXI_RREADY) = '1' then
					case axil_araddr is
					when b"0000" =>
						-- UARTDR (data register)
						axil_rdata <= (C_S_AXI_DATA_WIDTH-1 downto 12 => '0')
							      & rx_fifo_data;
					when b"0001" =>
						-- UARTFR (flag register)
						axil_rdata <= (C_S_AXI_DATA_WIDTH-1 downto 6 => '0')
							      & rx_fifo_empty
							      & rx_fifo_full
							      & tx_fifo_empty
							      & tx_fifo_full
							      & tx_busy
							      & tx_cts;
					when b"0010" =>
						-- UARTIBRD (baud rate divisor integer)
						axil_rdata <= ibrd_reg;
					when b"0011" =>
						-- UARTFBRD (baud rate divisor fractional)
						axil_rdata <= fbrd_reg;
					when b"0100" =>
						-- UARTLCR (line control register)
						axil_rdata <= lcr_reg;
					when b"0101" =>
						-- UARTCTRL (control register)
						axil_rdata <= ctrl_reg;
					when b"0110" =>
						-- UARTIMASK (interrupt mask register)
						axil_rdata <= imask_reg;
					when b"0111" =>
						-- UARTIMSTS (interrupt masked status register)
						axil_rdata <= (C_S_AXI_DATA_WIDTH-1 downto 7 => '0')
							      & intr_masked_sts;
					when b"1000" =>
						-- UARTIRSTS (interrupt raw status register)
						axil_rdata <= (C_S_AXI_DATA_WIDTH-1 downto 7 => '0')
							      & intr_raw_sts;
					--register "1001" is write only interrupt clear register
					when others =>
						axil_rdata <= (others => '0');
					end case;
				end if;
			end if;
		end if;
	end process;

	--read control next state logic
	process(axil_rvalid, axil_read_ready, S_AXI_RREADY)
	begin
		axil_rvalid_next <= axil_rvalid;
		if axil_read_ready = '1' then
			axil_rvalid_next <= '1';
		elsif S_AXI_RREADY = '1' then
			axil_rvalid_next <= '0';
		end if;
	end process;

	-- output logic
	--data register
	tx_fifo_wr <= '1' when axil_write_ready = '1' AND axil_awaddr = b"0000" else '0';
	rx_fifo_rd <= '1' when axil_read_ready  = '1' AND axil_araddr = b"0000" else '0';

	--baud rate registers
	baud_int_div  <= ibrd_reg(15 downto 0);
	baud_frac_div <= fbrd_reg(5 downto 0);

	--line control register
	data_bits     <= lcr_reg(5 downto 4);
	stop_bits     <= lcr_reg(3);
	parity_config <= lcr_reg(2 downto 1);
	break_gen     <= lcr_reg(0);

	--control register
	flow_ctrl_enable <= ctrl_reg(4);
	rts		 <= ctrl_reg(3);
	rx_enable	 <= ctrl_reg(2);
	tx_enable    	 <= ctrl_reg(1);
	uart_enable	 <= ctrl_reg(0);

	--interrupt mask register
	intr_mask <= imask_reg(6 downto 0);

	--interrupt clear register
	intr_clear_valid <= '1' when axil_write_ready = '1' AND axil_awaddr = b"1001" else '0';

end Behavioral;
