library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
	Generic(
		S_TICKS_PER_BAUD: integer := 16;
		DATA_BITS_MAX: integer := 9);
	Port(
		clk:	      in  std_logic;
		rst:	      in  std_logic;
		rx:	      in  std_logic;
		s_tick:	      in  std_logic;
		stop_bits:    in  std_logic;			--0 for 1 stop bit, 1 for 2 stop bits
		parity_ctrl:  in  std_logic_vector(1 downto 0);	--0 for off, 10 for even, 01 for odd
		data_bits:    in  std_logic_vector(3 downto 0);	--possible values of 5,6,7,8,9
		rx_done:      out std_logic;
		parity_error: out std_logic;
		data_out:     out std_logic_vector(DATA_BITS_MAX-1 downto 0)
	);
end uart_rx;

architecture Behavioral of uart_rx is

	type state_type is (idle, start, data, parity, stop);
	signal state_reg, state_next: state_type;

	signal s_reg, s_next: unsigned(4 downto 0) := (others => '0');		--holds s_tick count
	signal n_reg, n_next: unsigned(3 downto 0) := (others => '0');		--holds bit count
	signal b_reg, b_next: std_logic_vector(DATA_BITS_MAX-1 downto 0) := (others => '0'); --holds data_out
	signal p_reg, p_next: std_logic := '0';					--holds parity bit

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
		type parity_type is (none, even, odd);
		variable parity_setting: parity_type := none;
		variable num_stop_ticks: integer := 0;
		variable num_dbits: integer := 0;
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
				if rx = '0' then
					state_next <= start;
					s_next <= (others => '0');
				end if;

			when start =>
				if s_tick = '1' then
					--check in middle of the start bit
					if s_reg = (S_TICKS_PER_BAUD/2) - 1 then
						state_next <= data;
						s_next	   <= (others => '0');
						n_next	   <= (others => '0');
						b_next	   <= (others => '0');

						--Lock in configuration for receiving
						if (unsigned(data_bits) >= 5) OR
							(unsigned(data_bits) <= 9) then
							num_dbits := to_integer(unsigned(data_bits));
						else
							num_dbits := 8;
						end if;

						if (parity_ctrl = "01") then
							parity_setting := odd;
						elsif (parity_ctrl = "10") then
							parity_setting := even;
						else
							parity_setting := none;
						end if;

						p_next <= '0';

						--Check stop config
						if stop_bits = '1' then
							num_stop_ticks := S_TICKS_PER_BAUD * 2;
						else
							num_stop_ticks := S_TICKS_PER_BAUD;
						end if;
					else
						s_next <= s_reg + 1;
					end if;
				end if;

			when data =>
				if s_tick = '1' then
					if s_reg = S_TICKS_PER_BAUD-1 then
						s_next <= (others => '0');
						b_next(num_dbits-1 downto 0) <= rx & b_reg(num_dbits-1 downto 1);
						p_next <= rx XOR p_reg;
						if n_reg = num_dbits - 1 then
							if parity_setting /= none then
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
				if s_tick = '1' then
					if s_reg = S_TICKS_PER_BAUD-1 then
						state_next <= stop;
						if parity_setting = odd then	--odd parity
							parity_error <= not (p_reg XOR rx);
						else				--even parity
							parity_error <= p_reg XOR rx;
						end if;
						s_next <= (others => '0');
					else
						s_next <= s_reg + 1;
					end if;
				end if;

			when stop =>
				if s_tick = '1' then
					if s_reg = num_stop_ticks - 1 then
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
