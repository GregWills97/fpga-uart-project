library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_rx is
	Generic(
		S_TICKS_PER_BAUD: integer := 16;
		DATA_BITS_MAX: integer := 8);
	Port(
		clk:	      in  std_logic;
		rst:	      in  std_logic;
		en:	      in  std_logic;
		rx:	      in  std_logic;
		s_tick:	      in  std_logic;
		stop_bits:    in  std_logic;			--0 for 1 stop bit, 1 for 2 stop bits
		parity_ctrl:  in  std_logic_vector(1 downto 0);	--0 for off, 10 for even, 01 for odd
		data_bits:    in  std_logic_vector(1 downto 0);	--possible values of 5,6,7,8
		rx_done:      out std_logic;
		parity_error: out std_logic;
		frame_error:  out std_logic;
		break_error:  out std_logic;
		data_out:     out std_logic_vector(DATA_BITS_MAX-1 downto 0)
	);
end uart_rx;

architecture Behavioral of uart_rx is

	type state_type is (idle, start, data, parity, stop, recover);
	signal state_reg, state_next: state_type;

	signal s_reg, s_next: unsigned(4 downto 0) := (others => '0');		--holds s_tick count
	signal n_reg, n_next: unsigned(3 downto 0) := (others => '0');		--holds bit count
	signal b_reg, b_next: std_logic_vector(DATA_BITS_MAX-1 downto 0) := (others => '0'); --holds data_out
	signal p_reg, p_next: std_logic := '0';					--holds parity bit
	signal ferr_reg, ferr_next: std_logic := '0';				--holds framing error bit
	signal berr_reg, berr_next: std_logic := '0';				--holds break error bit

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
			ferr_reg  <= '0';
			berr_reg  <= '0';
		elsif rising_edge(clk) AND en = '1' then
			state_reg <= state_next;
			s_reg	  <= s_next;
			n_reg	  <= n_next;
			b_reg	  <= b_next;
			p_reg	  <= p_next;
			ferr_reg  <= ferr_next;
			berr_reg  <= berr_next;
		end if;
	end process;

	--next state logic
	process(state_reg, s_reg, n_reg, b_reg, p_reg, ferr_reg, berr_reg,
		data_bits, parity_ctrl, stop_bits, s_tick, rx)
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
		ferr_next    <= ferr_reg;
		berr_next    <= berr_reg;
		parity_error <= '0';
		frame_error  <= '0';
		break_error  <= '0';
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
						ferr_next  <= '0';
						berr_next  <= '0';

						--Lock in configuration for receiving
						case data_bits is
							when "00" =>
								num_dbits := 5;
							when "01" =>
								num_dbits := 6;
							when "10" =>
								num_dbits := 7;
							when "11" =>
								num_dbits := 8;
							when others =>
								num_dbits := 8;
						end case;

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
						berr_next <= berr_reg OR rx;
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
						berr_next <= berr_reg OR rx;
						state_next <= stop;
						if parity_setting = odd then	--odd parity
							p_next <= not (p_reg XOR rx);
						else				--even parity
							p_next <= p_reg XOR rx;
						end if;
						s_next <= (others => '0');
					else
						s_next <= s_reg + 1;
					end if;
				end if;

			when stop =>
				if s_tick = '1' then
					--check first stop bit if 2
					if (stop_bits = '1') AND (s_reg = num_stop_ticks/2 - 1) then
						ferr_next <= not rx;
						berr_next <= berr_reg OR rx;
					end if;

					if s_reg = num_stop_ticks - 1 then
						s_next <= (others => '0');
						rx_done <= '1';

						-- break error means no other errors should be generated
						-- only send frame error, if we dont have a break error
						-- only send parity error, if there is no break or
						-- frame error
						if (parity_setting /= none) AND (rx = '1') then
							parity_error <= p_reg AND berr_reg AND not ferr_reg;
						end if;

						if (ferr_reg = '1') OR (rx /= '1') then
							state_next <= recover;
							frame_error <= '1' AND berr_reg;
							break_error <= not berr_reg;
						else
							state_next <= idle;
						end if;
					else
						s_next <= s_reg + 1;
					end if;
				end if;

			when recover =>
				if s_tick = '1' then	--loop until we can go back to idle
					if s_reg = S_TICKS_PER_BAUD-1 then
						state_next <= idle;
					else
						if rx = '1' then
							s_next <= s_reg + 1;
						else
							s_next <= (others => '0');
						end if;
					end if;
				end if;

		end case;
	end process;

	data_out <= b_reg;

end Behavioral;
