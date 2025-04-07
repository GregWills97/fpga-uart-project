library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx_tb is
end uart_rx_tb;

architecture Behavioral of uart_rx_tb is

	signal clk, rst, rx, s_tick, rx_done, stop_bits, parity_error, frame_error: std_logic := '0';
	signal parity_ctrl: std_logic_vector(1 downto 0) := (others => '0');
	signal data_bits: std_logic_vector(3 downto 0) := (others => '0');
	signal data_out: std_logic_vector(7 downto 0) := (others => '0');
	signal int_div: std_logic_vector(15 downto 0) := (others => '0');
	signal frac_div: std_logic_vector(5 downto 0) := (others => '0');
	constant clk_period: time := 8 ns; --125Mhz clk
	constant baud_rate: time := 8.68 us; --115200 baud
	signal finished: std_logic := '0';

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
		rx	     => rx,
		s_tick	     => s_tick,
		stop_bits    => stop_bits,
		parity_ctrl  => parity_ctrl,
		data_bits    => data_bits,
		rx_done	     => rx_done,
		parity_error => parity_error,
		frame_error  => frame_error,
		data_out     => data_out
	);

	rst <= '0';

	--Baud rate of 115200
	int_div <= std_logic_vector(to_unsigned(67, int_div'length));
	frac_div <= std_logic_vector(to_unsigned(52, frac_div'length));

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	process
		type data_array is array (0 to 1) of std_logic_vector(7 downto 0);
		variable test_data: data_array := (x"AA", x"75");
	begin
		rx <= '1';

		--test break detection
		data_bits <= std_logic_vector(to_unsigned(8, data_bits'length));
		parity_ctrl <= std_logic_vector(to_unsigned(0, parity_ctrl'length));
		stop_bits <= '0';
		rx <= '0';
		wait for baud_rate * (1 + 8 + 1);

		rx <= '1';
		for i in test_data'range loop -- test data loop
		for j in 5 to 8 loop  -- data bit loop
		for k in 0 to 2 loop -- parity config loop
			data_bits <= std_logic_vector(to_unsigned(j, data_bits'length));
			parity_ctrl <= std_logic_vector(to_unsigned(k, parity_ctrl'length));
			stop_bits <= '0'; -- 1 stop bit
			send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, false, rx);
			send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, true, rx); -- generate frame error
			if k > 0 then
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, false, rx);
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, true, rx); --generate frame error
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), true, false, rx); -- generate parity error
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), true, true, rx); -- generate both
			end if;

			stop_bits <= '1'; -- 2 stop bit
			send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, false, rx);
			send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, true, rx); -- generate frame error
			if k > 0 then
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, false, rx);
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, true, rx); --generate frame error
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), true, false, rx); -- generate parity error
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), true, true, rx); -- generate both
			end if;
		end loop;
		end loop;
		end loop;

		report "Successful test";
		finished <= '1';
		wait;
	end process;

end Behavioral;
