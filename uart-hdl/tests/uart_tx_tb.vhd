library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx_tb is
end uart_tx_tb;

architecture Behavioral of uart_tx_tb is

	signal clk, rst, tx_start, s_tick, tx, tx_done, parity_ctrl: std_logic := '0';
	signal data_in: std_logic_vector(7 downto 0) := (others => '0');
	signal clk_period: time := 8 ns; --clk 125 MHz
	constant baud_rate: time := 8.68 us; --115200 baud
	signal finished: std_logic := '0';

	procedure send_uart_byte (
				signal par_ctrl: in std_logic;
				data: in std_logic_vector(7 downto 0);
				signal din: out std_logic_vector(7 downto 0);
				signal start: out std_logic
		) is
	begin
			din <= data;
			wait for 2 * baud_rate;

			start <= '1';
			wait for clk_period;
			start <= '0';

			--(start bit + 8 data bits + stop bit + if(parity_ctrl))
			if par_ctrl = '1' then
					wait for baud_rate * 11;
			else
					wait for baud_rate * 10;
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

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	process
	begin

		--send with parity
		parity_ctrl <= '1';
		send_uart_byte(parity_ctrl, x"55", data_in, tx_start);

		--send without parity
		parity_ctrl <= '0';
		send_uart_byte(parity_ctrl, x"55", data_in, tx_start);

		--send with parity
		parity_ctrl <= '1';
		send_uart_byte(parity_ctrl, x"73", data_in, tx_start);

		--send without parity
		parity_ctrl <= '0';
		send_uart_byte(parity_ctrl, x"73", data_in, tx_start);
		wait for baud_rate;

		finished <= '1';
		wait;
	end process;

end Behavioral;
