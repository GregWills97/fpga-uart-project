library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity fifo is
	Generic(
		WORD_SIZE: integer := 8;  --byte size word
		DEPTH:	   integer := 5   --2^x number of words should be greater than 2
	);
	Port(
		clk:	    in  std_logic;
		rst:	    in  std_logic;
		wr:	    in  std_logic;
		rd:	    in  std_logic;
		d_in:	    in  std_logic_vector((WORD_SIZE-1) downto 0);
		d_out:	    out std_logic_vector((WORD_SIZE-1) downto 0);
		full:	    out std_logic;
		near_full:  out std_logic;
		near_empty: out std_logic;
		empty:	    out std_logic
	);
end fifo;

architecture Behavioral of fifo is

	--register file
	type ram_type is array(0 to (2**DEPTH)-1) of std_logic_vector(WORD_SIZE-1 downto 0);
	signal fifo_regs: ram_type := (others => (others => '0'));
	constant max_size: unsigned(DEPTH-1 downto 0) := (others => '1');

	--control signals
	signal r_addr, w_addr: unsigned((DEPTH-1) downto 0) := (others => '0');
	signal curr_size: unsigned((DEPTH-1) downto 0) := (others => '0');
	signal full_flag:  std_logic := '0';
	signal empty_flag: std_logic := '1';
	signal write_read: std_logic_vector(1 downto 0) := (others => '0');  --write and read concatenated

begin

	--write and read concatenated
	write_read <= wr & rd;

	--current amount of data in buffer
	curr_size <= w_addr - r_addr + max_size + 1;

	--register process
	process(clk, rst)
	begin
		if (rst = '1') then
			fifo_regs <= (others => (others => '0'));
		elsif rising_edge(clk) then
			if ((wr and (not full_flag)) = '1') then
				fifo_regs(to_integer(w_addr)) <= d_in;
			end if;
		end if;
	end process;

	--control process
	process(clk, rst)
	begin
		if (rst = '1') then
			empty_flag <= '1';
			full_flag  <= '0';
		elsif rising_edge(clk) then
			case write_read is
				--read
				when "01" =>
					if empty_flag = '0' then  --if not empty
						if (r_addr + 1 = w_addr) then
							empty_flag <= '1';
						end if;
						r_addr <= r_addr + 1;
						full_flag <= '0';
					end if;

				--write
				when "10" =>
					if full_flag = '0' then  --if not full
						if (w_addr + 1 = r_addr) then
							full_flag <= '1';
						end if;
						w_addr <= w_addr + 1;
						empty_flag <= '0';
					end if;

				--write and read
				when "11" =>
					w_addr <= w_addr + 1;
					r_addr <= r_addr + 1;

				--do nothing otherwise
				when others =>
					null;
			end case;
		end if;
	end process;

	--output logic
	full  <= full_flag;
	empty <= empty_flag;
	d_out <= fifo_regs(to_integer(r_addr));

	--if top 2 bits of current size are set we know that the buffer is greater than 75% full
	near_full <= (curr_size(DEPTH-1) AND curr_size(DEPTH-2));

	--if top 2 bits of current size are unset we know that the buffer is less than 25% full
	near_empty <= (not curr_size(DEPTH-1) AND not curr_size(DEPTH-2)) AND not full_flag AND not empty_flag;

end Behavioral;
