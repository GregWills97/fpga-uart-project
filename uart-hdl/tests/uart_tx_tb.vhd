library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx_tb is
end uart_tx_tb;

architecture Behavioral of uart_tx_tb is

	--top-level signals
	signal clk, rst: std_logic := '0';
	constant clk_period: time := 8 ns; --125Mhz clk
	constant baud_rate: time := 8.68 us; --115200 baud
	signal finished: std_logic := '0';

	--baud_gen signals
	signal int_div: std_logic_vector(15 downto 0) := (others => '0');
	signal frac_div: std_logic_vector(5 downto 0) := (others => '0');
	signal s_tick: std_logic := '0';

	--tx signals
	signal tx, tx_done, tx_start, tx_enable: std_logic := '0';

	signal parity_ctrl: std_logic_vector(1 downto 0) := (others => '0');
	signal data_bits: std_logic_vector(1 downto 0) := (others => '0');
	signal stop_bits: std_logic := '0';

	--tx fifo signals
	signal tx_fifo_din, tx_fifo_dout: std_logic_vector(7 downto 0) := (others => '0');
	signal tx_fifo_wr: std_logic := '0';
	signal full, near_full, empty: std_logic := '0';

	procedure fill_fifo (
			signal wr: out std_logic
		) is
	begin
		wr <= '1';
		wait for clk_period;
		wr <= '0';
	end fill_fifo;

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
	Generic map(S_TICKS_PER_BAUD => 16, DATA_BITS_MAX => 8)
	Port map(
		clk	    => clk,
		rst	    => rst,
		en	    => tx_enable,
		tx_start    => tx_start,
		s_tick	    => s_tick,
		stop_bits   => stop_bits,
		parity_ctrl => parity_ctrl,
		data_bits   => data_bits,
		data_in	    => tx_fifo_dout,
		tx_done	    => tx_done,
		tx	    => tx
	);

	tx_fifo_uut: entity work.fifo
	Generic map(WORD_SIZE => 8, DEPTH => 3)
	Port map(
		clk	  => clk,
		rst   	  => rst,
		wr  	  => tx_fifo_wr,
		rd  	  => tx_done,
		d_in  	  => tx_fifo_din,
		d_out 	  => tx_fifo_dout,
		full  	  => full,
		near_full => near_full,
		empty	  => empty
	);

	rst <= '0';

	--Continuously transmit while FIFO has data
	tx_start <= not empty;

	--Baud rate of 115200
	int_div <= std_logic_vector(to_unsigned(67, int_div'length));
	frac_div <= std_logic_vector(to_unsigned(52, frac_div'length));

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	process
		type data_array is array (0 to 7) of std_logic_vector(7 downto 0);
		variable test_data: data_array := (x"DE", x"AD", x"BE", x"EF", x"FE", x"EB", x"DA", x"ED");

		variable expected_parity: std_logic := '0';
	begin
		for i in 5 to 8 loop -- data bit loop
		for j in 0 to 2 loop -- parity config loop
		for k in 0 to 1 loop -- stop bit config
			case i is
				when 5 =>
					data_bits <= "00";
				when 6 =>
					data_bits <= "01";
				when 7 =>
					data_bits <= "10";
				when 8 =>
					data_bits <= "11";
			end case;
			parity_ctrl <= std_logic_vector(to_unsigned(j, parity_ctrl'length));
			if k = 0 then
				stop_bits <= '0';
			else
				stop_bits <= '1';
			end if;

			tx_enable <= '0';
			for l in test_data'range loop -- test data loop
				tx_fifo_din <= test_data(l);
				fill_fifo(tx_fifo_wr);
			end loop;

			wait for baud_rate;
			tx_enable <= '1';
			wait for clk_period;

			-- loop through all data
			for n in test_data'range loop
				--wait for start bit and get in the middle of 1st data bit
				wait until rising_edge(clk) AND s_tick = '1' AND tx = '0';
				wait for baud_rate/2;

				--test data bits
				expected_parity := '0';
				for m in 0 to i-1 loop
					wait for baud_rate;
					if tx /= test_data(n)(m) then
						report "TEST_ERROR: transmitter sent incorrect data for data_bits: " &
							integer'image(i) & " parity control: " & integer'image(j) &
							" stop bits: " & integer'image(k + 1);
					else
						expected_parity := expected_parity XOR tx;
					end if;
				end loop;

				--check for parity
				if j = 1 then --odd parity
					wait for baud_rate;
					if (tx XOR expected_parity) /= '1' then
						report "TEST_ERROR: transmitter sent incorrect parity bit for data_bits: " &
							integer'image(i) & " parity control: " & integer'image(j) &
							" stop bits: " & integer'image(k + 1);
					end if;
				elsif j = 2 then --even parity
					wait for baud_rate;
					if (tx XOR expected_parity) /= '0' then
						report "TEST_ERROR: transmitter sent incorrect parity bit for data_bits: " &
							integer'image(i) & " parity control: " & integer'image(j) &
							" stop bits: " & integer'image(k + 1);
					end if;
				end if;

				--check stop bits
				wait for baud_rate;
				if tx /= '1' then
					report "TEST_ERROR: transmitter did not send stop bit for data_bits: " &
						integer'image(i) & " parity control: " & integer'image(j) &
						" stop bits: " & integer'image(k + 1);
				end if;
				if k = 1 then
					wait for baud_rate;
					if tx /= '1' then
						report "TEST_ERROR: transmitter did not send 2nd stop bit for data_bits: " &
							integer'image(i) & " parity control: " & integer'image(j) &
							" stop bits: " & integer'image(k + 1);
					end if;
				end if;
			end loop;

			wait until rising_edge(clk) AND empty = '1';
		end loop;
		end loop;
		end loop;

		report "TEST_SUCCESS: end of test";
		finished <= '1';
		wait;
	end process;

end Behavioral;
