library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo_tb is
end fifo_tb;

architecture Behavioral of fifo_tb is

	constant clk_period: time := 8 ns; --125Mhz clk
	signal clk, rst, wr, rd, full, near_full, empty: std_logic := '0';
	signal d_in, d_out: std_logic_vector(7 downto 0) := (others => '0');
	signal finished: std_logic := '0';

begin

	fifo_uut: entity work.fifo
	Generic map(WORD_SIZE => 8, DEPTH => 3)
	Port map(
		clk	  => clk,
		rst   	  => rst,
		wr  	  => wr,
		rd  	  => rd,
		d_in  	  => d_in,
		d_out 	  => d_out,
		full  	  => full,
		near_full => near_full,
		empty	  => empty
	);

	rst <= '0';

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	process
		type data_array is array (0 to 7) of integer;
		variable fifo_data: data_array := (12, 1, 19, 97, 9, 27, 19, 97);
	begin
		wait for clk_period;

		if ((full OR near_full) = '1') OR empty = '0' then
			report "TEST_ERROR: Flags are reported incorrectly";
		end if;

		wait until rising_edge(clk);
		for i in 0 to 5 loop
			wr <= '1';
			d_in <= std_logic_vector(to_unsigned(fifo_data(i), d_in'length));
			wait for clk_period;
			wr <= '0';
			wait for clk_period;
		end loop;

		if empty = '1' then
			report "TEST_ERROR: expected empty flag to be low";
		elsif near_full /= '1' then
			report "TEST_ERROR: expected near flag to be high";
		end if;

		for i in 6 to 7 loop
			wr <= '1';
			d_in <= std_logic_vector(to_unsigned(fifo_data(i), d_in'length));
			wait for clk_period;
			wr <= '0';
			wait for clk_period;
		end loop;

		if full /= '1' then
			report "TEST_ERROR: expected full flag to be high";
		elsif empty = '1' then
			report "TEST_ERROR: expected near empty to be low";
		end if;

		for i in 0 to 1 loop
			if unsigned(d_out) /= to_unsigned(fifo_data(i), d_out'length) then
				report "TEST_ERROR mismatched data returned from fifo at: " &
					integer'image(i);
			end if;

			rd <= '1';
			wait for clk_period;
			rd <= '0';
			wait for clk_period;
		end loop;

		if full = '1' then
			report "TEST_ERROR: expected full flag to be low";
		elsif near_full /= '1' then
			report "TEST_ERROR: expected near full flag to be high";
		elsif empty = '1' then
			report "TEST_ERROR: expected empty flag to be low";
		end if;

		for i in 2 to 7 loop
			if unsigned(d_out) /= to_unsigned(fifo_data(i), d_out'length) then
				report "TEST_ERROR mismatched data returned from fifo at: " &
					integer'image(i);
			end if;

			rd <= '1';
			wait for clk_period;
			rd <= '0';
			wait for clk_period;
		end loop;

		if full = '1' then
			report "TEST_ERROR: expected full flag to be low";
		elsif near_full = '1' then
			report "TEST_ERROR: expected near full flag to be low";
		elsif empty /= '1' then
			report "TEST_ERROR: expected empty flag to be high";
		end if;

		report "TEST_SUCCESS: end of test";
		finished <= '1';
		wait;
	end process;

end Behavioral;
