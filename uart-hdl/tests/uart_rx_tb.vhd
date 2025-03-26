library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx_tb is
end uart_rx_tb;

architecture Behavioral of uart_rx_tb is

	signal clk, rst, rx, s_tick, rx_done, parity_ctrl, parity_error: std_logic := '0';
	signal data_out: std_logic_vector(7 downto 0) := (others => '0');
	constant clk_period: time := 8 ns; --125Mhz clk
	constant baud_rate: time := 8.68 us; --115200 baud
	signal finished: std_logic := '0';

	procedure receive_uart_byte (
				signal par_ctrl: in std_logic;
				data_in: in std_logic_vector(7 downto 0);
				gen_err: in boolean;
				signal tx_line: out std_logic
		) is
			variable parity_bit: std_logic;
	begin
		parity_bit := '0';

		--start bit
		tx_line <= '0';
		wait for baud_rate;

		-- data bits
		for i in 0 to 7 loop
				parity_bit := parity_bit XOR data_in(i);
				tx_line <= data_in(i);
				wait for baud_rate;
		end loop;

		--if parity enabled send parity bit
		if par_ctrl = '1' then
				if gen_err = false then
						tx_line <= parity_bit;
				else
						tx_line <= parity_bit XOR '1';
				end if;
				wait for baud_rate;
		end if;

		--stop bit
		tx_line <= '1';
		wait for 2 * baud_rate;
	end receive_uart_byte;

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

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	process
	begin
		parity_ctrl <= '1';
		rx <= '1';
		wait for baud_rate;

		--0x55 with correct parity
		receive_uart_byte(parity_ctrl, x"AA", false, rx);

		--0x55 with incorrect parity
		receive_uart_byte(parity_ctrl, x"77", true, rx);

		--0x55 without parity
		parity_ctrl <= '0';
		receive_uart_byte(parity_ctrl, x"55", false, rx);
		wait for baud_rate;

		finished <= '1';
		wait;
	end process;

end Behavioral;
