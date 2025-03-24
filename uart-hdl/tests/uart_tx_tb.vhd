library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx_tb is
end uart_tx_tb;

architecture Behavioral of uart_tx_tb is

	signal clk, rst, tx_start, s_tick, tx, tx_done, parity_ctrl: std_logic;
	signal data_in: std_logic_vector(7 downto 0);
	signal clk_period: time := 8 ns; --clk 125 MHz

begin

	baud_gen: entity work.BaudGenerator
	Generic map(N => 7, M => 68) --generate baud of 115200
	Port map(
			clk => clk,
			rst => rst,
			max_tick => s_tick,
			q => open
	);

	tx_uut: entity work.uart_tx
	Generic map(DATA_BITS => 8, STOP_TICKS => 16)
	Port map(
			clk			=> clk,
			rst			=> rst,
			parity_ctrl	=> parity_ctrl,
			tx_start	=> tx_start,
			s_tick		=> s_tick,
			data_in		=> data_in,
			tx_done		=> tx_done,
			tx			=> tx
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
		data_in <= x"55";
		tx_start <= '0';
		wait for 16 us;
		tx_start <= '1';
		wait for 20 ns;
		tx_start <= '0';
		wait for 2 ms;

		parity_ctrl <= '0';
		wait for 50 ns;
		data_in <= x"55";
		tx_start <= '1';
		wait for 20 ns;
		tx_start <= '0';
		wait for 2 ms;
	end process;

end Behavioral;
