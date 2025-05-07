library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity interrupt_generation is
	Port(
		clk:		    in  std_logic;
		rst:		    in  std_logic;

		-- tx fifo status
		tx_full_flag:	    in  std_logic;
		tx_near_full_flag:  in  std_logic;
		tx_near_empty_flag: in  std_logic;
		tx_emtpy_flag:	    in  std_logic;

		-- rx fifo status
		rx_full_flag:	    in  std_logic;
		rx_near_full_flag:  in  std_logic;
		rx_near_empty_flag: in  std_logic;
		rx_emtpy_flag:	    in  std_logic;

		-- rx errors
		rx_parity_err:	    in  std_logic;
		rx_frame_err:	    in  std_logic;
		rx_break_err:	    in  std_logic;
		rx_overrun_err:	    in  std_logic;

		-- flow control
		uart_ctsn:	    in  std_logic; --active low
		uart_rtsn:	    out std_logic; --active low

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

	signal ctsn_reg:    std_logic;

	signal tx_intr_reg: std_logic; --tx interrupt
	signal rx_intr_reg: std_logic; --rx interrupt

	signal oe_intr_reg: std_logic; --overrun error interrupt
	signal be_intr_reg: std_logic; --break error interrupt
	signal pe_intr_reg: std_logic; --parity error interrupt
	signal fe_intr_reg: std_logic; --frame error interrupt
	signal er_intr_all: std_logic; --or of all

	signal fc_intr_reg: std_logic; --modem status interrupt
begin

	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				cts_reg <= '0';

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
				if intr_clear_valid AND intr_clear(0) = '1' then
					tx_intr_reg <= '0';
				else
					tx_intr_reg <= tx_fifo_near_empty;
				end if;

				-- rx interrupt
				if intr_clear_valid AND intr_clear(1) = '1' then
					rx_intr_reg <= '0';
				else
					rx_intr_reg <= rx_fifo_near_full;
				end if;

				-- frame error interrupt
				if intr_clear_valid AND intr_clear(2) = '1' then
					fe_intr_reg <= '0';
				else
					if rx_frame_error = '1' then
						fe_intr_reg <= '1;
					end if;
				end if;

				-- parity error interrupt
				if intr_clear_valid AND intr_clear(3) = '1' then
					pe_intr_reg <= '0';
				else
					if rx_parity_error = '1' then
						pe_intr_reg <= '1';
					end if;
				end if;

				-- break error interrupt
				if intr_clear_valid AND intr_clear(4) = '1' then
					be_intr_reg <= '0';
				else
					if rx_break_error = '1' then
						be_intr_reg <= '1';
					end if;
				end if;

				-- overrun error interrupt
				if intr_clear_valid AND intr_clear(5) = '1' then
					oe_intr_reg <= '0';
				else
					if rx_overrun_error = '1' then
						oe_intr_reg <= '1';
					end if;
				end if;

				-- flow control interrupt
				if intr_clear_valid AND intr_clear(6) = '1' then
					fc_intr_reg <= '0';
				else
					if cts_reg /= cts then
						fc_intr_reg <= '1';
					end if;
				end if;
				-- store cts signal to check for change
				cts_reg <= cts;
			end if;
		end if;
	end process;

	--output logic
	uart_rtsn <= rx_near_full_flag;

	--interrupt status
	intr_status_mask <= (fc_intr_reg AND intr_mask(6)) &
			    (oe_intr_reg AND intr_mask(5)) &
			    (be_intr_reg AND intr_mask(4)) &
			    (pe_intr_reg AND intr_mask(3)) &
			    (fe_intr_reg AND intr_mask(2)) &
			    (rx_intr_reg AND intr_mask(1)) &
			    (tx_intr_reg AND intr_mask(0));

	intr_status_raw  <= fc_intr_reg &
			    oe_intr_reg &
			    be_intr_reg &
			    pe_intr_reg &
			    fe_intr_reg &
			    rx_intr_reg &
			    tx_intr_reg;

	--interrupt lines
	uart_tx_intr <= intr_status_mask(0);
	uart_rx_intr <= intr_status_mask(1);

	er_intr_all  <= intr_status_mask(2) OR
			intr_status_mask(3) OR
			intr_status_mask(4) OR
			intr_status_mask(5);
	uart_er_intr <= er_intr_all;

	uart_fc_intr <= intr_status_mask(6);

	uart_intr    <= intr_status_mask(6) OR
			er_intr_all OR
			intr_status_mask(1) OR
			intr_status_mask(0);

end Behavioral;
