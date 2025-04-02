library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx_tb is
end uart_rx_tb;

architecture Behavioral of uart_rx_tb is

	signal clk, rst, rx, s_tick, rx_done, stop_bits, parity_error: std_logic := '0';
	signal parity_ctrl: std_logic_vector(1 downto 0) := (others => '0');
	signal data_bits: std_logic_vector(3 downto 0) := (others => '0');
	signal data_out: std_logic_vector(8 downto 0) := (others => '0');
	constant clk_period: time := 8 ns; --125Mhz clk
	constant baud_rate: time := 8.68 us; --115200 baud
	signal finished: std_logic := '0';

	procedure send_uart_byte (
			signal data_length: in std_logic_vector(3 downto 0);
			signal par_ctrl: in std_logic_vector(1 downto 0);
			signal num_stop: in std_logic;
			data_in: in std_logic_vector(8 downto 0);
			gen_err: in boolean;
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
			if gen_err = true then
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
		tx_line <= '1';
		if num_stop = '1' then
			wait for 2 * baud_rate;
		else
			wait for baud_rate;
		end if;
	end send_uart_byte;

begin

	baud_gen: entity work.BaudGenerator
	Generic map(N => 7, M => 68) --generate baud of 115200
	Port map(
		clk => clk,
		rst => rst,
		max_tick => s_tick,
		q => open
	);


	rx_uut: entity work.uart_rx
	Generic map(S_TICKS_PER_BAUD => 16, DATA_BITS_MAX => 9)
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
		data_out     => data_out
	);

	rst <= '0';

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	process
		type data_array is array (0 to 1) of std_logic_vector(8 downto 0);
		variable test_data: data_array := ('0' & x"AA", '0' & x"75");
	begin
		rx <= '1';

		for i in test_data'range loop -- test data loop
		for j in 5 to 9 loop  -- data bit loop
		for k in 0 to 2 loop -- parity config loop
			data_bits <= std_logic_vector(to_unsigned(j, data_bits'length));
			parity_ctrl <= std_logic_vector(to_unsigned(k, parity_ctrl'length));
			stop_bits <= '0'; -- 1 stop bit
			send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, rx);
			if k > 0 then
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), true, rx); --generate error
			end if;

			stop_bits <= '1'; -- 2 stop bit
			send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), false, rx);
			if k > 0 then
				send_uart_byte(data_bits, parity_ctrl, stop_bits, test_data(i), true, rx); --generate error
			end if;
		end loop;
		end loop;
		end loop;

		finished <= '1';
		wait;
	end process;

end Behavioral;
