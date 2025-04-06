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
	type slv_int_array is array (0 to 3) of std_logic_vector(15 downto 0);
	type slv_frac_array is array (0 to 3) of std_logic_vector(5 downto 0);
	signal int_div: slv_int_array := (others => (others => '0'));
	signal frac_div: slv_frac_array := (others => (others => '0'));
	signal s_tick, finished: std_logic_vector(3 downto 0) := (others => '0');

	--baud rate calculations
	type int_array is array (0 to 3) of integer;
	signal tick_count, baud_count: int_array := (others => 0);
	signal baud_desired: int_array := (230400, 115200, 38400, 9600);

	constant sec_divider: integer := 20;
begin

	gen_baud_tests: for i in 0 to 3 generate
		baud_gen_uut_0: entity work.baud_generator
		Port map(
			clk => clk,
			rst => rst,
			int_div => int_div(i),
			frac_div => frac_div(i),
			s_tick => s_tick(i)
		);

		process
			variable start_time: time := 0 sec;
		begin

			start_time := now;
			while now < start_time + (1 sec / sec_divider) loop
				wait until rising_edge(s_tick(i));
				tick_count(i) <= tick_count(i) + 1;
				if tick_count(i) = 15 then
					baud_count(i) <= baud_count(i) + 1;
					tick_count(i) <= 0;
				end if;
			end loop;

			report "Baud " & integer'image(baud_desired(i)) &
				" projected baud ticks: " & integer'image(baud_count(i) * sec_divider);
			finished(i) <= '1';
			wait;
		end process;
	end generate gen_baud_tests;

	rst <= '0';

	--clk
	clk <= not clk after clk_period/2 when finished /= "1111" else '0';

	--230400 baud
	--125 Mhz clock (125 x 10^6) / (16 * 230400) = 33.90842
	--integer divisor = 33
	--fraction divisor = floor(0.90842 * 64 + 0.5) = 58
	int_div(0) <= std_logic_vector(to_unsigned(33, 16));
	frac_div(0) <= std_logic_vector(to_unsigned(58, 6));

	--115200 baud
	--125 Mhz clock (125 x 10^6) / (16 * 115200) = 67.81684
	--integer divisor = 67
	--fraction divisor = floor(0.81684 * 64 + 0.5) = 52
	int_div(1) <= std_logic_vector(to_unsigned(67, 16));
	frac_div(1) <= std_logic_vector(to_unsigned(52, 6));

	--38400 baud
	--125 Mhz clock (125 x 10^6) / (16 * 38400) = 203.4505
	--integer divisor = 203
	--fraction divisor = floor(0.4505 * 64 + 0.5) = 29
	int_div(2) <= std_logic_vector(to_unsigned(203, 16));
	frac_div(2) <= std_logic_vector(to_unsigned(29, 6));

	--9600 baud
	--125 Mhz clock (125 x 10^6) / (16 * 9600) = 813.80
	--integer divisor = 813
	--fraction divisor = floor(0.802 * 64 + 0.5) = 51
	int_div(3) <= std_logic_vector(to_unsigned(813, 16));
	frac_div(3) <= std_logic_vector(to_unsigned(51, 6));


end Behavioral;
