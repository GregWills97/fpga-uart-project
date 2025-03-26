library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
	Generic(
		DATA_BITS:  integer := 8;
		STOP_TICKS: integer := 16
	);
	Port(
		clk:	      in  std_logic;
		rst:	      in  std_logic;
		parity_ctrl:  in  std_logic;
		rx:	      in  std_logic;
		s_tick:	      in  std_logic;
		rx_done:      out std_logic;
		parity_error: out std_logic;
		data_out:     out std_logic_vector(DATA_BITS-1 downto 0)
	);
end uart_rx;

architecture Behavioral of uart_rx is

	type state_type is (idle, start, data, parity, stop);
	signal state_reg, state_next: state_type;

	signal s_reg, s_next: unsigned(3 downto 0) := (others => '0');					 --holds s_tick count
	signal n_reg, n_next: unsigned(2 downto 0) := (others => '0');					 --holds bit count
	signal b_reg, b_next: std_logic_vector(DATA_BITS-1 downto 0) := (others => '0'); --holds data_out
	signal p_reg, p_next: std_logic := '0';											 --holds parity bit

begin

	--state and register assignments
	process(clk ,rst)
	begin
		if(rst = '1') then
			state_reg <= idle;
			s_reg	  <= (others => '0');
			n_reg	  <= (others => '0');
			b_reg	  <= (others => '0');
			p_reg	  <= '0';
		elsif rising_edge(clk) then
			state_reg <= state_next;
			s_reg	  <= s_next;
			n_reg	  <= n_next;
			b_reg	  <= b_next;
			p_reg	  <= p_next;
		end if;
	end process;

	--next state logic
	process(state_reg, s_reg, n_reg, b_reg, p_reg, s_tick, rx)
	begin
		--these assignments are to trigger the sensitivity list
		--state_next gets its actual value below
		state_next   <= state_reg;
		s_next	     <= s_reg;
		n_next	     <= n_reg;
		b_next	     <= b_reg;
		p_next	     <= p_reg;
		parity_error <= '0';
		rx_done	     <= '0';

		case state_reg is

			when idle =>
				if (rx = '0') then
					state_next <= start;
					s_next	 <= (others => '0');
				end if;

			when start =>
				--when s_reg is 7 we are in the middle of the start bit
				if (s_tick = '1') then
					if (s_reg = 7) then
						state_next <= data;
						s_next	   <= (others => '0');
						n_next	   <= (others => '0');
						p_next	   <= '0';
					else
						s_next	   <= s_reg + 1;
					end if;
				end if;

			when data =>
				if (s_tick = '1') then
					if (s_reg = 15) then
						s_next <= (others => '0');
						b_next <= rx & b_reg(DATA_BITS-1 downto 1);
						p_next <= rx XOR p_reg;
						if(n_reg = (DATA_BITS - 1)) then
							if(parity_ctrl = '1') then
								state_next <= parity;
							else
								state_next <= stop;
							end if;
						else
							n_next <= n_reg + 1;
						end if;
					else
						s_next <= s_reg + 1;
					end if;
				end if;

			when parity =>
				if (s_tick = '1') then
					if (s_reg = 15) then
						state_next <= stop;
						parity_error <= p_reg XOR rx;
						s_next <= (others => '0');
					else
						s_next <= s_reg + 1;
					end if;
				end if;

			when stop =>
				if (s_tick = '1') then
					if (s_reg = (STOP_TICKS - 1)) then
						state_next <= idle;
						rx_done <= '1';
					else
						s_next <= s_reg + 1;
					end if;
				end if;

		end case;
	end process;

	data_out <= b_reg;

end Behavioral;
