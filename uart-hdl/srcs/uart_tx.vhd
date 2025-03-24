library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_tx is
	Generic(
		DATA_BITS:  integer := 8;
		STOP_TICKS: integer := 16
	);
	Port(
		clk:		 in  std_logic;
		rst:		 in  std_logic;
		parity_ctrl: in  std_logic;
		tx_start:	 in  std_logic;
		s_tick:		 in  std_logic;
		data_in:	 in  std_logic_vector(DATA_BITS-1 downto 0);
		tx_done:	 out std_logic;
		tx:			 out std_logic
	);
end uart_tx;

architecture Behavioral of uart_tx is

	type state_type is (idle, start, data, parity, stop);
	signal state_reg, state_next: state_type;
	signal s_reg, s_next: unsigned(3 downto 0) := (others => '0');			--holds s_tick count
	signal n_reg, n_next: unsigned(2 downto 0) := (others => '0');			--holds bit count
	signal b_reg, b_next: std_logic_vector(7 downto 0) := (others => '0');	--holds data_in
	signal tx_reg, tx_next: std_logic := '0';								--holds output
	signal p_reg, p_next: std_logic := '0';									--holds parity

begin

	--state and data register assignments
	process(clk,rst)
	begin
		if (rst = '1') then
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
					if (tx_start = '1') then
						state_next <= start;
						s_next <= (others => '0');
						b_next <= data_in;
					end if;

				when start =>
					tx_next <= '0';
					if (s_tick = '1') then
						if (s_reg = 15) then
							state_next <= data;
							s_next <= (others => '0');
							n_next <= (others => '0');
							p_next <= '0';
						else
							s_next <= s_reg + 1;
						end if;
					end if;

				when data =>
					tx_next <= b_reg(0);
					if (s_tick = '1') then
						if (s_reg = 15) then
							s_next <= (others => '0');
							b_next <= '0' & b_reg((DATA_BITS-1) downto 1);
							p_next <= b_reg(0) XOR p_reg;
							if(n_reg = (DATA_BITS-1)) then
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
					tx_next <= p_reg;
					if (s_tick = '1') then
						if (s_reg = 15) then
							state_next <= stop;
							s_next <= (others => '0');
						else
							s_next <= s_reg + 1;
						end if;
					end if;

				when stop =>
					tx_next <= '1';
					if (s_tick = '1') then
						if (s_reg = (STOP_TICKS-1)) then
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
