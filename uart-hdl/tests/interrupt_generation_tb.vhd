library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity interrupt_generation_tb is
end interrupt_generation_tb;

architecture Behavioral of interrupt_generation_tb is

	constant clk_period: time := 8 ns; --125Mhz clk
	signal clk, rst, enable, finished: std_logic := '0';

	signal rx_near_full_flag, tx_near_empty_flag: std_logic := '0';
	signal rx_parity_err, rx_frame_err, rx_break_err, rx_overrun_err: std_logic := '0';
	signal uart_ctsn: std_logic := '0';

	signal intr_mask, intr_clear: std_logic_vector(6 downto 0) := (others => '0');
	signal intr_status_mask, intr_status_raw: std_logic_vector(6 downto 0) := (others => '0');
	signal intr_clear_valid: std_logic := '0';

	signal uart_tx_intr, uart_rx_intr, uart_er_intr, uart_fc_intr, uart_intr: std_logic := '0';

begin

	interrupt_generation_uut: entity work.interrupt_generation
	Port map(
		clk		   => clk,
		rst		   => rst,
		enable		   => enable,
		tx_near_empty_flag => tx_near_empty_flag,
		rx_near_full_flag  => rx_near_full_flag,
		rx_parity_err	   => rx_parity_err,
		rx_frame_err	   => rx_frame_err,
		rx_break_err	   => rx_break_err,
		rx_overrun_err	   => rx_overrun_err,
		uart_ctsn	   => uart_ctsn,
		intr_mask	   => intr_mask,
		intr_clear	   => intr_clear,
		intr_clear_valid   => intr_clear_valid,
		intr_status_mask   => intr_status_mask,
		intr_status_raw	   => intr_status_raw,
		uart_tx_intr	   => uart_tx_intr,
		uart_rx_intr	   => uart_rx_intr,
		uart_er_intr	   => uart_er_intr,
		uart_fc_intr	   => uart_fc_intr,
		uart_intr	   => uart_intr
	);

	process
	begin
		rst <= '1';
		wait for clk_period;
		wait until rising_edge(clk);
		rst <= '0';
		wait;
	end process;

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';
	enable <= '1';

	process
	begin
		uart_ctsn <= '1'; --active low

		--generate all interrupts
		wait until rising_edge(clk) AND rst = '0';
		intr_mask <= b"1111111";
		tx_near_empty_flag <= '1';
		rx_near_full_flag <= '1';
		rx_frame_err <= '1';
		rx_parity_err <= '1';
		rx_break_err <= '1';
		rx_overrun_err <= '1';
		uart_ctsn <= '0';

		wait for clk_period;
		tx_near_empty_flag <= '0';
		rx_near_full_flag <= '0';
		rx_frame_err <= '0';
		rx_parity_err <= '0';
		rx_break_err <= '0';
		rx_overrun_err <= '0';
		uart_ctsn <= '1';

		wait until rising_edge(clk);
		if uart_intr /= '1' then
			report "TEST_ERROR: expected uart_intr to be raised";
		elsif uart_fc_intr /= '1' then
			report "TEST_ERROR: expected uart_fc_intr to be raised";
		elsif uart_er_intr /= '1' then
			report "TEST_ERROR: expected uart_er_intr to be raised";
		elsif uart_rx_intr /= '1' then
			report "TEST_ERROR: expected uart_rx_intr to be raised";
		elsif uart_tx_intr /= '1' then
			report "TEST_ERROR: expected uart_tx_intr to be raised";
		end if;

		if intr_status_mask /= (intr_status_raw AND intr_mask) then
			report "TEST_ERROR: interrupt status reported incorrectly";
		end if;

		--clear all
		for i in 0 to 6 loop
			wait until rising_edge(clk);
			intr_clear <= std_logic_vector(to_unsigned(1, intr_clear'length) sll i);
			intr_clear_valid <= '1';
			wait for clk_period;
			intr_clear_valid <= '0';

			wait until rising_edge(clk);
			if intr_status_mask(i) /= '0' then
				report "TEST_ERROR: interrupt not cleared";
			end if;
		end loop;
		wait for clk_period;

		--test mask
		wait until rising_edge(clk);
		intr_mask <= b"1000010";
		tx_near_empty_flag <= '1';
		rx_near_full_flag <= '1';
		rx_frame_err <= '1';
		rx_parity_err <= '1';
		rx_break_err <= '1';
		rx_overrun_err <= '1';
		uart_ctsn <= '0';

		wait for clk_period;
		tx_near_empty_flag <= '0';
		rx_near_full_flag <= '0';
		rx_frame_err <= '0';
		rx_parity_err <= '0';
		rx_break_err <= '0';
		rx_overrun_err <= '0';
		uart_ctsn <= '1';

		wait until rising_edge(clk);
		if uart_intr /= '1' then
			report "TEST_ERROR: expected uart_intr to be raised";
		elsif uart_fc_intr /= '1' then
			report "TEST_ERROR: expected uart_fc_intr to be raised";
		elsif uart_er_intr = '1' then
			report "TEST_ERROR: expected uart_er_intr to be low";
		elsif uart_rx_intr /= '1' then
			report "TEST_ERROR: expected uart_rx_intr to be raised";
		elsif uart_tx_intr = '1' then
			report "TEST_ERROR: expected uart_tx_intr to be low";
		end if;

		if intr_status_mask /= (intr_status_raw AND intr_mask) then
			report "TEST_ERROR: interrupt status reported incorrectly";
		end if;

		--test raising interrupt while clearing
		wait until rising_edge(clk);
		intr_mask <= b"1111111";
		rx_frame_err <= '1';
		rx_parity_err <= '1';
		rx_break_err <= '1';
		rx_overrun_err <= '1';

		intr_clear_valid <= '1';
		intr_clear <= b"1000010";
		wait for clk_period;
		intr_clear_valid <= '0';

		wait until rising_edge(clk);
		if intr_status_mask /= b"0111100" then
			report "TEST_ERROR: interrupt status not reported correctly";
		end if;

		if intr_status_mask /= (intr_status_raw AND intr_mask) then
			report "TEST_ERROR: interrupt status reported incorrectly";
		end if;

		report "TEST_SUCCESS: end of test";
		finished <= '1';
		wait;
	end process;

end Behavioral;
