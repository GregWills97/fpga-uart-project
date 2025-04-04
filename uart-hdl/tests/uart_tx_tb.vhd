library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx_tb is
end uart_tx_tb;

architecture Behavioral of uart_tx_tb is

	signal clk, rst, tx_start, s_tick, tx, tx_done, stop_bits: std_logic := '0';
	signal parity_ctrl: std_logic_vector(1 downto 0) := (others => '0');
	signal data_bits: std_logic_vector(3 downto 0) := (others => '0');
	signal data_in: std_logic_vector(8 downto 0) := (others => '0');
	signal int_div: std_logic_vector(15 downto 0) := (others => '0');
	signal frac_div: std_logic_vector(5 downto 0) := (others => '0');
	constant clk_period: time := 8 ns; --clk 125 MHz
	constant baud_rate: time := 8.68 us; --115200 baud
	signal finished: std_logic := '0';

	procedure receive_uart_byte (
			signal par_ctrl: in std_logic_vector(1 downto 0);
			data_length: in integer;
			signal stp_bit: in std_logic;
			data: in std_logic_vector(8 downto 0);
			signal din: out std_logic_vector(8 downto 0);
			signal start: out std_logic
		) is
	begin
		din <= data;
		start <= '1';
		wait for clk_period;
		start <= '0';

		--wait for start bit + num data bits + if(parity_bit) + num stop bits + 1 for padding
		if unsigned(par_ctrl) > 0 then
			if stp_bit = '1' then
				wait for baud_rate * (1 + data_length + 1 + 2 + 1);
			else
				wait for baud_rate * (1 + data_length + 1 + 1 + 1);
			end if;
		else
			if stp_bit = '1' then
				wait for baud_rate * (1 + data_length + 2 + 1);
			else
				wait for baud_rate * (1 + data_length + 1 + 1);
			end if;
		end if;

	end receive_uart_byte;

begin

	baud_gen_uut: entity work.baud_generator
	Port map(
		clk => clk,
		rst => rst,
		int_div => int_div,
		frac_div => frac_div,
		s_tick => s_tick
	);

	tx_uut: entity work.uart_tx
	Generic map(S_TICKS_PER_BAUD => 16, DATA_BITS_MAX => 9)
	Port map(
		clk	    => clk,
		rst	    => rst,
		tx_start    => tx_start,
		s_tick	    => s_tick,
		stop_bits   => stop_bits,
		parity_ctrl => parity_ctrl,
		data_bits   => data_bits,
		data_in	    => data_in,
		tx_done	    => tx_done,
		tx	    => tx
	);

	rst <= '0';

	--Baud rate of 115200
	int_div <= std_logic_vector(to_unsigned(2, int_div'length));
	frac_div <= std_logic_vector(to_unsigned(11, frac_div'length));

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	process
		type data_array is array (0 to 1) of std_logic_vector(8 downto 0);
		variable test_data: data_array := ('0' & x"AA", '0' & x"75");
	begin

		wait for baud_rate;

		for i in test_data'range loop -- test data loop
		for j in 5 to 9 loop  -- data bit loop
		for k in 0 to 2 loop -- parity config loop
			data_bits <= std_logic_vector(to_unsigned(j, data_bits'length));
			parity_ctrl <= std_logic_vector(to_unsigned(k, parity_ctrl'length));

			--1 stop bit
			stop_bits <= '0';
			receive_uart_byte(parity_ctrl, j, stop_bits, test_data(i), data_in, tx_start);

			--2 stop bit
			stop_bits <= '1';
			receive_uart_byte(parity_ctrl, j, stop_bits, test_data(i), data_in, tx_start);
		end loop;
		end loop;
		end loop;

		report "Successful test";
		finished <= '1';
		wait;
	end process;

end Behavioral;
