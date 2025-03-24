library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx_tb is
end uart_rx_tb;

architecture Behavioral of uart_rx_tb is

	signal clk, rst, rx, s_tick, rx_done, parity_ctrl, parity_error: std_logic;
	signal data_out: std_logic_vector(7 downto 0);
	constant clk_period: time := 8 ns; --125Mhz clk

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
	Generic map(DATA_BITS => 8, STOP_TICKS => 16)
	Port map(
			clk			 => clk,
			rst	     	 => rst,
			parity_ctrl  => parity_ctrl,
			rx			 => rx,
			s_tick		 => s_tick,
			rx_done		 => rx_done,
			parity_error => parity_error,
			data_out	 => data_out
	);

	rst <= '0';

	--clk process
	process
	begin
		clk <= '1';
		wait for clk_period/2;
		clk <= '0';
		wait for clk_period/2;
	end process;

	process
	begin
		parity_ctrl <= '1';
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 500 us;

		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '1';
		wait for 500 us;

		parity_ctrl <= '0';
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 8.68 us;
		rx <= '0';
		wait for 8.68 us;
		rx <= '1';
		wait for 500 us;
	end process;

end Behavioral;
