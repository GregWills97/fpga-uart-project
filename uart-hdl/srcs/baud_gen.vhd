library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity baud_generator is
	Port(
		clk:	  in  std_logic;
		rst:	  in  std_logic;
		int_div:  in  std_logic_vector(15 downto 0);
		frac_div: in  std_logic_vector(5 downto 0);
		s_tick:   out std_logic
	);
end baud_generator;

architecture Behavioral of baud_generator is

	signal count_acc: unsigned(15 downto 0) := (others => '0');
	signal err_acc: unsigned(6 downto 0) := (others => '0');
	signal tick: std_logic := '0';
	signal err_max: unsigned(6 downto 0) := "1000000";

begin
	--register assignments
	process(clk, rst)
		variable err_calc: unsigned(6 downto 0) := (others => '0');
	begin
		if(rst = '1') then
			count_acc <= (others => '0');
			err_acc <= (others => '0');
			tick <= '0';
		elsif rising_edge(clk) then
			if count_acc = unsigned(int_div) then
				tick <= '1';

				err_calc := err_acc + unsigned(frac_div);
				if err_calc >= err_max then
					count_acc <= (others => '0');
					err_acc <= err_calc - err_max;
				else
					count_acc <= to_unsigned(1, count_acc'length);
					err_acc <= err_calc;
				end if;
			else
				count_acc <= count_acc + 1;
				tick <= '0';
			end if;
		end if;
	end process;

	s_tick <= tick;

end Behavioral;
