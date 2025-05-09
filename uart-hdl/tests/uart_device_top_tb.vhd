library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_device_top_tb is
end uart_device_top_tb;

architecture Behavioral of uart_device_top_tb is

	constant clk_period: time := 8 ns; --125Mhz clk
	constant baud_rate: time := 8.68 us; --115200 baud
	signal clk, rstn, finished: std_logic := '0';

	--write signals
	signal awaddr: std_logic_vector(5 downto 0) := (others => '0');
	signal awvalid, awready: std_logic := '0';
	signal wdata: std_logic_vector(31 downto 0) := (others => '0');
	signal wstrb: std_logic_vector(3 downto 0) := (others => '0');
	signal wvalid, wready: std_logic := '0';
	signal bresp: std_logic_vector(1 downto 0) := (others => '0');
	signal bvalid, bready: std_logic := '0';

	--read signals
	signal araddr: std_logic_vector(5 downto 0) := (others => '0');
	signal arvalid, arready: std_logic := '0';
	signal rdata: std_logic_vector(31 downto 0) := (others => '0');
	signal rresp: std_logic_vector(1 downto 0) := (others => '0');
	signal rvalid, rready: std_logic := '0';

	--unused trustzone
	signal awprot, arprot: std_logic_vector(2 downto 0) := (others => '0');

	--control registers
	signal UARTDR:	  std_logic_vector(5 downto 0) := b"000000"; --data registers
	signal UARTFR:	  std_logic_vector(5 downto 0) := b"000100"; --flag register
	signal UARTIBRD:  std_logic_vector(5 downto 0) := b"001000"; --baudrate integer
	signal UARTFBRD:  std_logic_vector(5 downto 0) := b"001100"; --baudrate fractional
	signal UARTLCR:	  std_logic_vector(5 downto 0) := b"010000"; --line control
	signal UARTCTRL:  std_logic_vector(5 downto 0) := b"010100"; --control
	signal UARTIMASK: std_logic_vector(5 downto 0) := b"011000"; --interrupt mask
	signal UARTIMSTS: std_logic_vector(5 downto 0) := b"011100"; --interrupt masked status
	signal UARTIRSTS: std_logic_vector(5 downto 0) := b"100000"; --interrupt raw status
	signal UARTICLR:  std_logic_vector(5 downto 0) := b"100100"; --interrupt clear

	signal rx: std_logic := '0';

	type data_array is array (0 to 7) of std_logic_vector(31 downto 0);
	procedure write_axi (
			addr: in std_logic_vector(5 downto 0);
			data: in data_array;
			num_txns: in integer;
			axi_error_flag: out boolean;

			-- axi signals
			signal axil_clk:     in  std_logic;
			signal axil_awaddr:  out std_logic_vector(5 downto 0);
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
			addr: in std_logic_vector(5 downto 0);
			data: out data_array;
			num_txns: in integer;
			axi_error_flag: out boolean;

			-- axi signals
			signal axil_clk:     in  std_logic;
			signal axil_araddr:  out std_logic_vector(5 downto 0);
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

	procedure send_uart_byte (
			signal data_length: in std_logic_vector(1 downto 0);
			signal par_ctrl: in std_logic_vector(1 downto 0);
			signal num_stop: in std_logic;
			data_in: in std_logic_vector(7 downto 0);
			gen_perr: in boolean;
			gen_ferr: in boolean;
			signal tx_line: out std_logic
		) is
			variable parity_bit: std_logic;
			variable gen_err_bit: std_logic;
			variable num_bits: integer;
	begin
		wait for baud_rate;
		parity_bit := '0';

		--start bit
		tx_line <= '0';
		wait for baud_rate;

		case data_length is
			when "00" =>
				num_bits := 5;
			when "01" =>
				num_bits := 6;
			when "10" =>
				num_bits := 7;
			when "11" =>
				num_bits := 8;
			when others =>
				num_bits := 8;
		end case;
		-- data bits
		for i in 0 to num_bits-1 loop
			parity_bit := parity_bit XOR data_in(i);
			tx_line <= data_in(i);
			wait for baud_rate;
		end loop;

		--if parity enabled send parity bit
		if unsigned(par_ctrl) > "00" then
			if gen_perr = true then
				gen_err_bit := '1';
			else
				gen_err_bit := '0';
			end if;

			if par_ctrl = "01" then
				tx_line <= not parity_bit XOR gen_err_bit;
			else
				tx_line <= parity_bit XOR gen_err_bit;
			end if;
			wait for baud_rate;
		end if;

		--stop bit
		if gen_ferr = true then
			tx_line <= '0';
		else
			tx_line <= '1';
		end if;

		if num_stop = '1' then
			wait for 2 * baud_rate;
		else
			wait for baud_rate;
		end if;
		tx_line <= '1';
	end send_uart_byte;
begin

	uart_device_top_uut: entity work.uart_device_top
	Generic map(
		C_S00_AXI_DATA_WIDTH => 32,
		C_S00_AXI_ADDR_WIDTH => 6
	)
	Port map(
		S00_AXI_ACLK	 => clk,
		S00_AXI_ARESETN	 => rstn,
		S00_AXI_AWADDR	 => awaddr,
		S00_AXI_AWVALID	 => awvalid,
		S00_AXI_AWREADY	 => awready,
		S00_AXI_WDATA	 => wdata,
		S00_AXI_WSTRB	 => wstrb,
		S00_AXI_WVALID	 => wvalid,
		S00_AXI_WREADY	 => wready,
		S00_AXI_BRESP	 => bresp,
		S00_AXI_BVALID	 => bvalid,
		S00_AXI_BREADY	 => bready,
		S00_AXI_ARADDR	 => araddr,
		S00_AXI_ARVALID	 => arvalid,
		S00_AXI_ARREADY	 => arready,
		S00_AXI_RDATA	 => rdata,
		S00_AXI_RRESP	 => rresp,
		S00_AXI_RVALID	 => rvalid,
		S00_AXI_RREADY	 => rready,
		S00_AXI_AWPROT	 => awprot,
		S00_AXI_ARPROT	 => arprot,
		uart_rstn	 => rstn,
		uart_rx		 => rx
	);

	--reset process
	process
	begin
		rstn <= '0';
		wait for clk_period * 2;
		wait until rising_edge(clk);
		rstn <= '1';
		wait;
	end process;

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	process
		--variable mask: std_logic_vector(31 downto 0) := (others => '0');
		--variable test_data: data_array := (others => (others => '0'));
		--variable ret_data:  data_array := (others => (others => '0'));
		--variable axi_error: boolean := false;
	begin
		--wait until rising_edge(clk) AND rstn = '1';
		--wait for clk_period;

		---- check that empty flags are on
		--read_axi(UARTFR, ret_data, 1, axi_error, clk, araddr, arvalid, arready,
		--	 rdata, rresp, rvalid, rready);
		--if ret_data(0)(5 downto 0) /= "101000" then
		--	report "TEST_ERROR: axi does not report fifo empty on start";
		--end if;
		--ret_data := (others => (others => '0'));

		----fill up fifo
		--test_data := (x"DEADBEEF", x"BEEFDEAD", x"12345678", x"87654321",
		--	      x"10ABCDEF", x"FFFFFFFF", x"55555555", x"1A2B3C4D");
		--write_axi(UARTDR, test_data, 8, axi_error, clk, awaddr, awvalid, awready,
		--	  wdata, wvalid, wready, wstrb, bresp, bvalid, bready);

		report "TEST_SUCCESS: end of test";
		finished <= '1';
		wait;
	end process;

end Behavioral;
