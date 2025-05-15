library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity interrupt_generation is
	Port(
		clk:		    in  std_logic;
		rst:		    in  std_logic;

		-- fifo status
		tx_near_empty_flag: in  std_logic;
		rx_near_full_flag:  in  std_logic;

		-- rx errors
		rx_parity_err:	    in  std_logic;
		rx_frame_err:	    in  std_logic;
		rx_break_err:	    in  std_logic;
		rx_overrun_err:	    in  std_logic;

		-- flow control
		uart_ctsn:	    in  std_logic; --active low

		-- Interrupt register control
		intr_mask:	    in  std_logic_vector(6 downto 0);
		intr_clear:	    in  std_logic_vector(6 downto 0);
		intr_clear_valid:   in  std_logic;
		intr_status_mask:   out std_logic_vector(6 downto 0);
		intr_status_raw:    out std_logic_vector(6 downto 0);

		-- interrupt lines
		uart_tx_intr:	    out std_logic; --tx interrupt (triggered when tx_interrupt_generation near empty)
		uart_rx_intr:	    out std_logic; --rx interrupt (triggered when rx_interrupt_generation near full)
		uart_er_intr:	    out std_logic; --error interrupt (triggered by rx data error)
		uart_fc_intr:	    out std_logic; --flow control interrupt (triggered when cts changes)
		uart_intr:	    out std_logic  --or of all interrupts
	);
end interrupt_generation;

architecture Behavioral of interrupt_generation is

	signal ctsn_reg:    std_logic := '0';

	signal tx_intr_reg: std_logic := '0'; --tx interrupt
	signal rx_intr_reg: std_logic := '0'; --rx interrupt

	signal oe_intr_reg: std_logic := '0'; --overrun error interrupt
	signal be_intr_reg: std_logic := '0'; --break error interrupt
	signal pe_intr_reg: std_logic := '0'; --parity error interrupt
	signal fe_intr_reg: std_logic := '0'; --frame error interrupt

	signal fc_intr_reg: std_logic := '0'; --modem status interrupt

	signal status_mask: std_logic_vector(6 downto 0);
begin

	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				ctsn_reg <= '1'; --active low

				--interrupts
				tx_intr_reg <= '0';
				rx_intr_reg <= '0';
				oe_intr_reg <= '0';
				be_intr_reg <= '0';
				pe_intr_reg <= '0';
				fe_intr_reg <= '0';
				fc_intr_reg <= '0';
			else
				-- tx interrupt
				if intr_clear_valid = '1' AND intr_clear(0) = '1' then
					tx_intr_reg <= '0';
				else
					tx_intr_reg <= tx_near_empty_flag;
				end if;

				-- rx interrupt
				if intr_clear_valid = '1' AND intr_clear(1) = '1' then
					rx_intr_reg <= '0';
				else
					rx_intr_reg <= rx_near_full_flag;
				end if;

				-- frame error interrupt
				if intr_clear_valid = '1' AND intr_clear(2) = '1' then
					fe_intr_reg <= '0';
				else
					if rx_frame_err = '1' then
						fe_intr_reg <= '1';
					end if;
				end if;

				-- parity error interrupt
				if intr_clear_valid = '1' AND intr_clear(3) = '1' then
					pe_intr_reg <= '0';
				else
					if rx_parity_err = '1' then
						pe_intr_reg <= '1';
					end if;
				end if;

				-- break error interrupt
				if intr_clear_valid = '1' AND intr_clear(4) = '1' then
					be_intr_reg <= '0';
				else
					if rx_break_err = '1' then
						be_intr_reg <= '1';
					end if;
				end if;

				-- overrun error interrupt
				if intr_clear_valid = '1' AND intr_clear(5) = '1' then
					oe_intr_reg <= '0';
				else
					if rx_overrun_err = '1' then
						oe_intr_reg <= '1';
					end if;
				end if;

				-- flow control interrupt
				if intr_clear_valid = '1' AND intr_clear(6) = '1' then
					fc_intr_reg <= '0';
				else
					if ctsn_reg /= uart_ctsn then
						fc_intr_reg <= '1';
					end if;
				end if;
				-- store ctsn signal to check for change
				ctsn_reg <= uart_ctsn;
			end if;
		end if;
	end process;

	--interrupt status
	status_mask <= (fc_intr_reg AND intr_mask(6)) &
		       (oe_intr_reg AND intr_mask(5)) &
		       (be_intr_reg AND intr_mask(4)) &
		       (pe_intr_reg AND intr_mask(3)) &
		       (fe_intr_reg AND intr_mask(2)) &
		       (rx_intr_reg AND intr_mask(1)) &
		       (tx_intr_reg AND intr_mask(0));

	intr_status_mask <= status_mask;
	intr_status_raw  <= fc_intr_reg &
			    oe_intr_reg &
			    be_intr_reg &
			    pe_intr_reg &
			    fe_intr_reg &
			    rx_intr_reg &
			    tx_intr_reg;

	--interrupt lines
	uart_tx_intr <= status_mask(0);
	uart_rx_intr <= status_mask(1);

	uart_er_intr <= status_mask(2) OR
			status_mask(3) OR
			status_mask(4) OR
			status_mask(5);

	uart_fc_intr <= status_mask(6);

	uart_intr    <= status_mask(6) OR
			status_mask(5) OR
			status_mask(4) OR
			status_mask(3) OR
			status_mask(2) OR
			status_mask(1) OR
			status_mask(0);

end Behavioral;
