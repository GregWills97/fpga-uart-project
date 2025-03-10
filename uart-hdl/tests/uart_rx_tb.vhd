library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity rx_tb is
end rx_tb;

architecture Behavioral of rx_tb is

	signal data_bits:  integer := 8;
	signal stop_ticks: integer := 16;
	signal N: integer := 10;
	signal M: integer := 814;
	signal clk, rst, rx, s_tick, rx_done, parity_ctrl, parity_error: std_logic;
	signal data_out: std_logic_vector(data_bits-1 downto 0);
	constant clk_period: time := 8 ns; --125Mhz clk

begin

	baud_gen: entity work.BaudGenerator
	Generic map(N => N, M => M)
	Port map(
			clk => clk,
			rst => rst,
			max_tick => s_tick,
			q => open
	);


	rx_tb: entity work.uart_rx
	Generic map(data_bits => data_bits, stop_ticks => stop_ticks)
	Port map(
			clk	     => clk,
			rst	     => rst,
			parity_ctrl  => parity_ctrl,
			rx	     => rx,
			s_tick	     => s_tick,
			rx_done	     => rx_done,
			parity_error => parity_error,
			data_out     => data_out
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
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 2 ms;

		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '1';
		wait for 2 ms;

		parity_ctrl <= '0';
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 105 us;
		rx <= '0';
		wait for 105 us;
		rx <= '1';
		wait for 2 ms;
	end process;

end Behavioral;
