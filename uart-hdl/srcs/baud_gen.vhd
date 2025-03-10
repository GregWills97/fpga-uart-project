library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--Clock on Zybo board is 125 MHz
--Max_pulse needs to be 16 times the frequency of the baud rate (115200 baud)
--(125 Mhz) / (115200 * 16) = 678.168, so M needs to be 679
--to hold that count r_reg needs 10 bits so N goes to 10

entity BaudGenerator is
	Generic(
		N: integer := 10;
		M: integer := 679
	);
	Port(
		clk:	  in  std_logic;
		rst:	  in  std_logic;
		max_tick: out std_logic;
		q:	  out std_logic_vector(N-1 downto 0)
	);
end BaudGenerator;

architecture Behavioral of BaudGenerator is

	signal r_reg, r_next: unsigned(N-1 downto 0) := (others => '0');

begin
	--register assignments
	process(clk, rst)
	begin
		if(rst = '1') then
			r_reg <= (others => '0');
		elsif rising_edge(clk) then
			r_reg <= r_next;
		end if;
	end process;

	--next state logic
	r_next <= (others => '0') when r_reg = (M-1) else r_reg + 1;

	--output logic
	q <= std_logic_vector(r_reg);
	max_tick <= '1' when r_reg = (M-1) else '0';

end Behavioral;
