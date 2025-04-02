library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity baud_gen_tb is
end baud_gen_tb;

architecture Behavioral of baud_gen_tb is

	constant clk_period: time := 8 ns; --125Mhz clk
	signal clk, rst, s_tick: std_logic := '0';
	signal d_in, d_out: std_logic_vector(7 downto 0) := (others => '0');
	signal int_div: std_logic_vector(15 downto 0) := (others => '0');
	signal frac_div: std_logic_vector(5 downto 0) := (others => '0');
	signal finished: std_logic := '0';

	--baud rate calculations
	signal start_time: time := 0 sec;
	signal tick_count: integer := 0;
	signal baud_count: integer := 0;

begin

	baud_gen_uut: entity work.baud_generator
	Port map(
		clk => clk,
		rst => rst,
		int_div => int_div,
		frac_div => frac_div,
		max_tick => s_tick
	);

	rst <= '0';

	--clk
	clk <= not clk after clk_period/2 when finished /= '1' else '0';

	process
		variable baud_rate: integer := 0;
		variable baud_period: time := 0 ns;
	begin
		--115200 baud = 8.68 us period;
		--125 Mhz clock (125 x 10^6) / (16 * 115200) = 67.81684
		--int div = 67
		--frac div = floor(0.81684 * 64 + 0.5) = 52
		baud_rate := 115200;
		baud_period := 8.68 us;
		int_div <= std_logic_vector(to_unsigned(67, int_div'length));
		frac_div <= std_logic_vector(to_unsigned(52, frac_div'length));

		start_time <= now;
		while now < start_time + 1 sec loop
			wait until rising_edge(s_tick);
			tick_count <= tick_count + 1;
			if tick_count >= 15 then
				baud_count <= baud_count + 1;
			end if;
		end loop;

		report "Measured baud ticks: " & integer'image(baud_count);

		finished <= '1';
		wait;
	end process;

end Behavioral;
