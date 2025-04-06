library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity baud_gen_tb is
end baud_gen_tb;

architecture Behavioral of baud_gen_tb is

	constant clk_period: time := 8 ns; --125Mhz clk
	signal clk, rst: std_logic := '0';
	signal d_in, d_out: std_logic_vector(7 downto 0) := (others => '0');

	--signal arrays
	type slv_int_array is array (0 to 2) of std_logic_vector(15 downto 0);
	type slv_frac_array is array (0 to 2) of std_logic_vector(5 downto 0);
	signal int_div: slv_int_array := (others => (others => '0'));
	signal frac_div: slv_frac_array := (others => (others => '0'));
	signal s_tick, finished: std_logic_vector(2 downto 0) := (others => '0');

	--baud rate calculations
	type int_array is array (0 to 2) of integer;
	signal tick_count, baud_count: int_array := (others => 0);

	constant sec_divider: integer := 20;
begin

	gen_baud_tests: for i in 0 to 2 generate
		baud_gen_uut_0: entity work.baud_generator
		Port map(
			clk => clk,
			rst => rst,
			int_div => int_div(i),
			frac_div => frac_div(i),
			s_tick => s_tick(i)
		);
	end generate gen_baud_tests;

	rst <= '0';

	--clk
	clk <= not clk after clk_period/2 when finished /= "111" else '0';

	--baud_generator 0
	process
		variable start_time: time := 0 sec;
		constant baud_desired: integer := 115200;
	begin
		--115200 baud
		--125 Mhz clock (125 x 10^6) / (16 * 115200) = 67.81684
		--integer divisor = 67
		--fraction divisor = floor(0.81684 * 64 + 0.5) = 52
		int_div(0) <= std_logic_vector(to_unsigned(67, 16));
		frac_div(0) <= std_logic_vector(to_unsigned(52, 6));

		start_time := now;
		while now < start_time + (1 sec / sec_divider) loop
			wait until rising_edge(s_tick(0));
			tick_count(0) <= tick_count(0) + 1;
			if tick_count(0) = 15 then
				baud_count(0) <= baud_count(0) + 1;
				tick_count(0) <= (0);
			end if;
		end loop;

		report "Baud " & integer'image(baud_desired) & " projected baud ticks: " & integer'image(baud_count(0) * sec_divider);

		finished(0) <= '1';
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
		int_div(1) <= std_logic_vector(to_unsigned(203, 16));
		frac_div(1) <= std_logic_vector(to_unsigned(29, 6));

		start_time := now;
		while now < start_time + (1 sec / sec_divider) loop
			wait until rising_edge(s_tick(1));
			tick_count(1) <= tick_count(1) + 1;
			if tick_count(1) = 15 then
				baud_count(1) <= baud_count(1) + (1);
				tick_count(1) <= 0;
			end if;
		end loop;

		report "Baud " & integer'image(baud_desired) & " projected baud ticks: " & integer'image(baud_count(1) * sec_divider);

		finished(1) <= '1';
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
		int_div(2) <= std_logic_vector(to_unsigned(813, 16));
		frac_div(2) <= std_logic_vector(to_unsigned(51, 6));

		start_time := now;
		while now < start_time + (1 sec / sec_divider) loop
			wait until rising_edge(s_tick(2));
			tick_count(2) <= tick_count(2) + 1;
			if tick_count(2) = 15 then
				baud_count(2) <= baud_count(2) + 1;
				tick_count(2) <= 0;
			end if;
		end loop;

		report "Baud " & integer'image(baud_desired) & " projected baud ticks: " & integer'image(baud_count(2) * sec_divider);

		finished(2) <= '1';
		wait;
	end process;

end Behavioral;
