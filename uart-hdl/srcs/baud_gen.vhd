library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity baud_generator is
	Port(
		clk:	  in  std_logic;
		rst:	  in  std_logic;
		int_div:  in  std_logic_vector(15 downto 0);
		frac_div: in  std_logic_vector(5 downto 0);
		err_ovf:  out std_logic;
		max_tick: out std_logic
	);
end baud_generator;

architecture Behavioral of baud_generator is

	signal count_reg, count_next: unsigned(15 downto 0) := (others => '0');
	signal err_reg, err_next: unsigned(6 downto 0) := (others => '0');

	signal err_max: integer := 2**frac_div'length;
begin
	--register assignments
	process(clk, rst)
	begin
		if(rst = '1') then
			count_reg <= (others => '0');
			err_reg <= (others => '0');
		elsif rising_edge(clk) then
			count_reg <= count_next;
			err_reg <= err_next;
		end if;
	end process;

	--next state logic
	process(count_reg, err_reg)
	begin
		count_next <= count_reg;
		err_next <= err_reg;

		if count_reg >= unsigned(int_div) then
			count_next <= to_unsigned(1, count_reg'length);

			err_next <= err_reg + unsigned(frac_div);
			if err_reg >= err_max then
				--add in extra clock cycle by starting at zero instead of one
				count_next <= (others => '0');
				err_next <= err_reg - err_max;
			end if;
		else
			count_next <= count_reg + 1;
		end if;
	end process;

	--output
	max_tick <= '1' when count_reg >= unsigned(int_div) else '0';
	err_ovf <= '1' when err_reg >= err_max else '0';
end Behavioral;
