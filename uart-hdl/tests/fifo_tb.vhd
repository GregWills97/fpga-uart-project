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
	Generic map(WORD_SIZE => 8, DEPTH => 5)
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
		variable count: unsigned(7 downto 0) := (others => '0');
	begin
		wait for clk_period / 2;

		for i in 0 to 31 loop
			wr <= '1';
			d_in <= std_logic_vector(count);
			wait for clk_period;
			wr <= '0';
			wait for clk_period;
			count := count + 1;
		end loop;

		for i in 0 to 10 loop
			rd <= '1';
			wait for clk_period;
			rd <= '0';
			wait for clk_period;
		end loop;

		for i in 0 to 10 loop
			wr <= '1';
			d_in <= std_logic_vector(count);
			wait for clk_period;
			wr <= '0';
			wait for clk_period;
			count := count + 1;
		end loop;

		for i in 0 to 31 loop
			rd <= '1';
			wait for clk_period;
			rd <= '0';
			wait for clk_period;
		end loop;
		finished <= '1';
		wait;
	end process;

end Behavioral;
