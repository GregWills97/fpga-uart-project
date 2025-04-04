library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity baud_gen_tb is
end baud_gen_tb;

architecture Behavioral of baud_gen_tb is

	constant clk_period: time := 8 ns; --125Mhz clk
	signal clk, rst, s_tick0, s_tick1, s_tick2: std_logic := '0';
	signal d_in, d_out: std_logic_vector(7 downto 0) := (others => '0');
	signal int_div0, int_div1, int_div2: std_logic_vector(15 downto 0) := (others => '0');
	signal frac_div0, frac_div1, frac_div2: std_logic_vector(5 downto 0) := (others => '0');
	signal finished0, finished1, finished2: std_logic := '0';

	--baud rate calculations
	signal tick_count0, tick_count1, tick_count2: integer := 0;
	signal baud_count0, baud_count1, baud_count2: integer := 0;

	constant sec_divider: integer := 50;
begin

	baud_gen_uut_0: entity work.baud_generator
	Port map(
		clk => clk,
		rst => rst,
		int_div => int_div0,
		frac_div => frac_div0,
		s_tick => s_tick0
	);

	baud_gen_uut_1: entity work.baud_generator
	Port map(
		clk => clk,
		rst => rst,
		int_div => int_div1,
		frac_div => frac_div1,
		s_tick => s_tick1
	);


	baud_gen_uut_2: entity work.baud_generator
	Port map(
		clk => clk,
		rst => rst,
		int_div => int_div2,
		frac_div => frac_div2,
		s_tick => s_tick2
	);
	rst <= '0';

	--clk
	clk <= not clk after clk_period/2 when (finished0 AND finished1 AND finished2) /= '1' else '0';

	--baud_generator 0
	process
		variable start_time: time := 0 sec;
		constant baud_desired: integer := 115200;
	begin
		--115200 baud
		--125 Mhz clock (125 x 10^6) / (16 * 115200) = 67.81684
		--integer divisor = 67
		--fraction divisor = floor(0.81684 * 64 + 0.5) = 52
		int_div0 <= std_logic_vector(to_unsigned(67, int_div0'length));
		frac_div0 <= std_logic_vector(to_unsigned(52, frac_div0'length));

		start_time := now;
		while now < start_time + (1 sec / sec_divider) loop
			wait until rising_edge(s_tick0);
			tick_count0 <= tick_count0 + 1;
			if tick_count0 = 15 then
				baud_count0 <= baud_count0 + 1;
				tick_count0 <= 0;
			end if;
		end loop;

		report "Baud " & integer'image(baud_desired) & " projected baud ticks: " & integer'image(baud_count0 * sec_divider);

		finished0 <= '1';
		wait;
	end process;

	--baud_generator 1
	process
		variable start_time: time := 0 sec;
		constant baud_desired: integer := 38400;
	begin
		--38400 baud
		--125 Mhz clock (125 x 10^6) / (16 * 38400) = 203.4505
		--integer divisor = 203
		--fraction divisor = floor(0.4505 * 64 + 0.5) = 29
		int_div1 <= std_logic_vector(to_unsigned(203, int_div1'length));
		frac_div1 <= std_logic_vector(to_unsigned(29, frac_div1'length));

		start_time := now;
		while now < start_time + (1 sec / sec_divider) loop
			wait until rising_edge(s_tick1);
			tick_count1 <= tick_count1 + 1;
			if tick_count1 = 15 then
				baud_count1 <= baud_count1 + 1;
				tick_count1 <= 0;
			end if;
		end loop;

		report "Baud " & integer'image(baud_desired) & " projected baud ticks: " & integer'image(baud_count1 * sec_divider);

		finished1 <= '1';
		wait;
	end process;

	--baud_generator 2
	process
		variable start_time: time := 0 sec;
		constant baud_desired: integer := 9600;
	begin
		--9600 baud
		--125 Mhz clock (125 x 10^6) / (16 * 9600) = 813.80
		--integer divisor = 813
		--fraction divisor = floor(0.802 * 64 + 0.5) = 51
		int_div2 <= std_logic_vector(to_unsigned(813, int_div2'length));
		frac_div2 <= std_logic_vector(to_unsigned(51, frac_div2'length));

		start_time := now;
		while now < start_time + (1 sec / sec_divider) loop
			wait until rising_edge(s_tick2);
			tick_count2 <= tick_count2 + 1;
			if tick_count2 = 15 then
				baud_count2 <= baud_count2 + 1;
				tick_count2 <= 0;
			end if;
		end loop;

		report "Baud " & integer'image(baud_desired) & " projected baud ticks: " & integer'image(baud_count2 * sec_divider);

		finished2 <= '1';
		wait;
	end process;

end Behavioral;
