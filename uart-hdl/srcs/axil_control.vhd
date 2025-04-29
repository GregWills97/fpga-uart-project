library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axil_control is
	generic (
		-- Width of S_AXI data bus
		C_S_AXI_DATA_WIDTH	: integer	:= 32;
		-- Width of S_AXI address bus
		C_S_AXI_ADDR_WIDTH	: integer	:= 4);
	port (
		-- AXI signals
		S_AXI_ACLK	: in  std_logic;
		S_AXI_ARESETN	: in  std_logic;
		S_AXI_AWADDR	: in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_AWVALID	: in  std_logic;
		S_AXI_AWREADY	: out std_logic;
		S_AXI_WDATA	: in  std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_WSTRB	: in  std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
		S_AXI_WVALID	: in  std_logic;
		S_AXI_WREADY	: out std_logic;
		S_AXI_BRESP	: out std_logic_vector(1 downto 0);
		S_AXI_BVALID	: out std_logic;
		S_AXI_BREADY	: in  std_logic;
		S_AXI_ARADDR	: in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
		S_AXI_ARVALID	: in  std_logic;
		S_AXI_ARREADY	: out std_logic;
		S_AXI_RDATA	: out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
		S_AXI_RRESP	: out std_logic_vector(1 downto 0);
		S_AXI_RVALID	: out std_logic;
		S_AXI_RREADY	: in  std_logic;

		-- Ignored, TrustZone not supported
		S_AXI_AWPROT	: in  std_logic_vector(2 downto 0);
		S_AXI_ARPROT	: in  std_logic_vector(2 downto 0);

		-- Control signals
		-- data register UARTDR
		rx_fifo_data	: in  std_logic_vector(11 downto 0); -- rx-fifo data including errors
		rx_fifo_rd	: out std_logic;
		tx_fifo_data	: out std_logic_vector(7 downto 0);
		tx_fifo_wr	: out std_logic
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

	-- slave registers
	-- UART DR
	-- there is no actual register here, writes and reads go directly to external fifos

	-- UART LCTRL
	signal lctrl_reg, lctrl_next: std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0) := (others => '0');

	-- function to apply write strobe to slave registers
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

				lctrl_reg <= (others => '0');
			else
				axil_bvalid <= axil_bvalid_next;
				axil_write_ready <= axil_write_ready_next;

				if axil_write_ready = '1' then
					case axil_awaddr is
					-- No register for "00", write will go directly to txfifo
					when b"01" =>
						lctrl_reg <= lctrl_next;
					when others =>
						null;
					end case;
				end if;
			end if;
		end if;
	end process;

	--write control next state logic
	process(S_AXI_AWVALID, axil_wdata, S_AXI_WVALID, axil_wstrb, axil_write_ready,
		S_AXI_BREADY, axil_bvalid, lctrl_reg)
	begin
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
		lctrl_next <= apply_wstrb(lctrl_reg, axil_wdata, axil_wstrb);
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
					when b"00" =>
						axil_rdata <= (C_S_AXI_DATA_WIDTH-1 downto 12 => '0')
							      & rx_fifo_data;
					when b"01" =>
						axil_rdata <= lctrl_reg;
					when others =>
						null;
					end case;
				end if;
			end if;
		end if;
	end process;

	--read control next state logic
	process(axil_read_ready, S_AXI_RREADY)
	begin
		if axil_read_ready = '1' then
			axil_rvalid_next <= '1';
		elsif S_AXI_RREADY = '1' then
			axil_rvalid_next <= '0';
		end if;
	end process;

	-- output logic
	tx_fifo_wr <= '1' when axil_write_ready = '1' AND axil_awaddr = b"00" else '0';
	rx_fifo_rd <= '1' when axil_read_ready  = '1' AND axil_araddr = b"00" else '0';

end Behavioral;
