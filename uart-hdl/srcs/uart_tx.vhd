library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
	Generic(
		S_TICKS_PER_BAUD:  integer := 16;
		DATA_BITS_MAX:  integer := 9
	);
	Port(
		clk:	     in  std_logic;
		rst:	     in  std_logic;
		tx_start:    in  std_logic;
		s_tick:	     in  std_logic;
		stop_bits:   in  std_logic;			--0 for 1 stop bit, 1 for 2 stop bits
		parity_ctrl: in  std_logic_vector(1 downto 0);	--0 for off, 10 for even, 01 for odd
		data_bits:   in  std_logic_vector(3 downto 0);	--possible values of 5,6,7,8,9
		data_in:     in  std_logic_vector(DATA_BITS_MAX-1 downto 0);
		tx_done:     out std_logic;
		tx:	     out std_logic
	);
end uart_tx;

architecture Behavioral of uart_tx is

	type state_type is (idle, start, data, parity, stop);
	signal state_reg, state_next: state_type;
	signal s_reg, s_next: unsigned(4 downto 0) := (others => '0');		--holds s_tick count
	signal n_reg, n_next: unsigned(3 downto 0) := (others => '0');		--holds bit count
	signal b_reg, b_next: std_logic_vector(DATA_BITS_MAX-1 downto 0) := (others => '0');	--holds data_in
	signal tx_reg, tx_next: std_logic := '0';				--holds output
	signal p_reg, p_next: std_logic := '0';					--holds parity

begin

	--state and data register assignments
	process(clk,rst) begin if (rst = '1') then
			state_reg <= idle;
			s_reg	  <= (others => '0');
			n_reg	  <= (others => '0');
			b_reg	  <= (others => '0');
			p_reg	  <= '0';
			tx_reg	  <= '1';
		elsif rising_edge(clk) then
			state_reg <= state_next;
			s_reg	  <= s_next;
			n_reg	  <= n_next;
			b_reg	  <= b_next;
			p_reg	  <= p_next;
			tx_reg	  <= tx_next;
		end if;
	end process;

	--next state logic;
	process(state_reg, s_reg, n_reg, b_reg, p_reg, s_tick, tx_reg, tx_start, data_in)
		type parity_type is (none, even, odd);
		variable parity_setting: parity_type := none;
		variable num_stop_ticks: integer := 0;
		variable num_dbits: integer := 0;
	begin
		state_next   <= state_reg;
		s_next	     <= s_reg;
		n_next	     <= n_reg;
		b_next	     <= b_reg;
		p_next	     <= p_reg;
		tx_next	     <= tx_reg;
		tx_done	     <= '0';

		case state_reg is

			when idle =>
				tx_next <= '1';
				if tx_start = '1' then
					state_next <= start;
					s_next <= (others => '0');
					b_next <= (others => '0');
				end if;

			when start =>
				tx_next <= '0';
				if s_tick = '1' then
					if s_reg = S_TICKS_PER_BAUD-1 then
						state_next <= data;
						s_next <= (others => '0');
						n_next <= (others => '0');
						b_next <= data_in;
						p_next <= '0';

						--lock in configuration
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
				tx_next <= b_reg(0);
				if s_tick = '1' then
					if s_reg = S_TICKS_PER_BAUD-1 then
						s_next <= (others => '0');
						b_next(num_dbits-1 downto 0) <= '0' & b_reg(num_dbits-1 downto 1);
						p_next <= b_reg(0) XOR p_reg;
						if n_reg = num_dbits-1 then
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
				if parity_setting = odd then
					tx_next <= not p_reg;
				else
					tx_next <= p_reg;
				end if;

				if s_tick = '1' then
					if s_reg = S_TICKS_PER_BAUD-1 then
						state_next <= stop;
						s_next <= (others => '0');
					else
						s_next <= s_reg + 1;
					end if;
				end if;

			when stop =>
				tx_next <= '1';
				if s_tick = '1' then
					if s_reg = num_stop_ticks-1 then
						state_next <= idle;
						tx_done <= '1';
					else
						s_next <= s_reg + 1;
					end if;
				end if;
		end case;
	end process;

	--output logic
	tx <= tx_reg;

end Behavioral;
