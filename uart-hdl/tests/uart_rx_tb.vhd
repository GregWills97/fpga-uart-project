library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx_tb is
end uart_rx_tb;

architecture Behavioral of uart_rx_tb is

	--top-level signals
	signal clk, rst: std_logic := '0';
	signal data_out: std_logic_vector(7 downto 0) := (others => '0');
	constant clk_period: time := 8 ns; --125Mhz clk
	constant baud_rate: time := 8.68 us; --115200 baud
	signal finished: std_logic := '0';

	--baud_gen signals
	signal int_div: std_logic_vector(15 downto 0) := (others => '0');
	signal frac_div: std_logic_vector(5 downto 0) := (others => '0');
	signal s_tick: std_logic := '0';

	--rx signals
	signal rx, rx_enable, rx_done: std_logic := '0';
	signal rx_dout: std_logic_vector(7 downto 0) := (others => '0');
	signal parity_error, frame_error, break_error: std_logic := '0';

	signal parity_ctrl: std_logic_vector(1 downto 0) := (others => '0');
	signal data_bits: std_logic_vector(3 downto 0) := (others => '0');
	signal stop_bits: std_logic := '0';

	--rx fifo signals
	signal rx_fifo_din, rx_fifo_dout: std_logic_vector(10 downto 0) := (others => '0');
	signal rx_fifo_rd: std_logic := '0';
	signal full, near_full, empty: std_logic := '0';

	procedure send_uart_byte (
			signal data_length: in std_logic_vector(3 downto 0);
			signal par_ctrl: in std_logic_vector(1 downto 0);
			signal num_stop: in std_logic;
			data_in: in std_logic_vector(7 downto 0);
			gen_perr: in boolean;
			gen_ferr: in boolean;
			signal tx_line: out std_logic
		) is
			variable parity_bit: std_logic;
			variable gen_err_bit: std_logic;
	begin
		wait for baud_rate;
		parity_bit := '0';

		--start bit
		tx_line <= '0';
		wait for baud_rate;
		-- data bits
		for i in 0 to to_integer(unsigned(data_length)) - 1 loop
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

	procedure read_fifo (
			signal rd: out std_logic
		) is
	begin
		rd <= '1';
		wait for clk_period;
		rd <= '0';
	end read_fifo;

begin

	baud_gen_uut: entity work.baud_generator
	Port map(
		clk => clk,
		rst => rst,
		int_div => int_div,
		frac_div => frac_div,
		s_tick => s_tick
	);

	rx_uut: entity work.uart_rx
	Generic map(S_TICKS_PER_BAUD => 16, DATA_BITS_MAX => 8)
	Port map(
		clk	     => clk,
		rst	     => rst,
		en	     => rx_enable,
		rx	     => rx,
		s_tick	     => s_tick,
		stop_bits    => stop_bits,
		parity_ctrl  => parity_ctrl,
		data_bits    => data_bits,
		rx_done	     => rx_done,
		parity_error => parity_error,
		frame_error  => frame_error,
		break_error  => break_error,
		data_out     => rx_dout
	);

	rx_fifo_uut: entity work.fifo
	Generic map(WORD_SIZE => 11, DEPTH => 3)
	Port map(
		clk	  => clk,
		rst   	  => rst,
		wr  	  => rx_done,
		rd  	  => rx_fifo_rd,
		d_in  	  => rx_fifo_din,
		d_out 	  => rx_fifo_dout,
		full  	  => full,
		near_full => near_full,
		empty	  => empty
	);

	rst <= '0';

	--Baud rate of 115200
	int_div <= std_logic_vector(to_unsigned(67, int_div'length));
	frac_div <= std_logic_vector(to_unsigned(52, frac_div'length));

	--fifo write data
	rx_fifo_din <= break_error & frame_error & parity_error & rx_dout;

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	process
		type data_array is array (0 to 1) of std_logic_vector(7 downto 0);
		variable test_data: data_array := (x"AA", x"75");
	begin
		--test break detection and enable bit
		data_bits <= std_logic_vector(to_unsigned(8, data_bits'length));
		parity_ctrl <= std_logic_vector(to_unsigned(0, parity_ctrl'length));
		stop_bits <= '0';
		rx <= '1';

		rx_enable <= '0';
		send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(0), false, false, rx);

		if empty /= '1' then
			report "TEST_ERROR: Rx FIFO written to when not enabled";
			finished <= '1';
			wait;
		end if;

		rx_enable <= '1';
		wait for baud_rate;

		rx <= '0';
		wait until rising_edge(clk) AND rx_done = '1';
		read_fifo(rx_fifo_rd);
		if rx_fifo_dout(10) /= '1' then
			report "TEST_ERROR: Break error not detected";
			finished <= '1';
			wait;
		elsif unsigned(rx_fifo_dout(9 downto 0)) /= 0 then
			report "TEST_ERROR: Erroneous data written to receive fifo during break error";
		end if;
		rx <= '1';

		for i in test_data'range loop -- test data loop
		for j in 5 to 8 loop  -- data bit loop
		for k in 0 to 2 loop -- parity config loop
		for l in 0 to 1 loop -- stop config
			data_bits <= std_logic_vector(to_unsigned(j, data_bits'length));
			parity_ctrl <= std_logic_vector(to_unsigned(k, parity_ctrl'length));
			if l = 0 then
				stop_bits <= '0'; -- 1 stop bit
			else
				stop_bits <= '1'; -- 2 stop bit
			end if;

			--test no error
			send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, false, rx);
			read_fifo(rx_fifo_rd);
			if rx_fifo_dout(10 downto 8) /= "000" then
				report "TEST_ERROR: unexpected error generated for data bits: " &
					integer'image(j) & " parity control: " & integer'image(k) &
					"stop bits: " & integer'image(l + 1);
			elsif rx_fifo_dout(j-1 downto 0) /= test_data(i)(j-1 downto 0) then
				report "TEST_ERROR: data mismatched for data bits: " &
					integer'image(j) & " parity control: " & integer'image(k) &
					"stop bits: " & integer'image(l + 1);
			end if;

			--test frame error
			send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, true, rx);
			read_fifo(rx_fifo_rd);
			if rx_fifo_dout(10 downto 8) /= "010" then
				report "TEST_ERROR: frame error not generated for data bits: " &
					integer'image(j) & " parity control: " & integer'image(k) &
					"stop bits: " & integer'image(l + 1);
			end if;

			--if parity enabled
			if k > 0 then
				--test no error
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, false, rx);
				read_fifo(rx_fifo_rd);
				if rx_fifo_dout(10 downto 8) /= "000" then
					report "TEST_ERROR: unexpected error generated for data bits: " &
						integer'image(j) & " parity control: " & integer'image(k) &
						"stop bits: " & integer'image(l + 1);
				elsif rx_fifo_dout(j-1 downto 0) /= test_data(i)(j-1 downto 0) then
					report "TEST_ERROR: data mismatched for data bits: " &
						integer'image(j) & " parity control: " & integer'image(k) &
						"stop bits: " & integer'image(l + 1);
				end if;

				--test frame error
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, true, rx);
				read_fifo(rx_fifo_rd);
				if rx_fifo_dout(10 downto 8) /= "010" then
					report "TEST_ERROR: frame error not generated for data bits: " &
						integer'image(j) & " parity control: " & integer'image(k) &
						"stop bits: " & integer'image(l + 1);
				end if;

				--test parity error
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), true, false, rx);
				read_fifo(rx_fifo_rd);
				if rx_fifo_dout(10 downto 8) /= "001" then
					report "TEST_ERROR: parity error not generated for data bits: " &
						integer'image(j) & " parity control: " & integer'image(k) &
						"stop bits: " & integer'image(l + 1);
				end if;

				--test both, but only frame error should generate
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), true, true, rx);
				read_fifo(rx_fifo_rd);
				if rx_fifo_dout(10 downto 8) /= "010" then
					report "TEST_ERROR: errors generated incorrectly for data bits: " &
						integer'image(j) & " parity control: " & integer'image(k) &
						"stop bits: " & integer'image(l + 1);
				end if;
			end if;
		end loop;
		end loop;
		end loop;
		end loop;

		report "TEST_SUCCESS: end of test";
		finished <= '1';
		wait;
	end process;

end Behavioral;
