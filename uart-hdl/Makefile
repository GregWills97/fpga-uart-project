GHDL := ghdl
GTKW := gtkwave
SRCS = srcs/baud_gen.vhd srcs/uart_rx.vhd srcs/uart_tx.vhd srcs/fifo.vhd
TESTS = tests/uart_rx_tb.vhd tests/uart_tx_tb.vhd tests/fifo_tb.vhd
WORK = work-obj93.cf

$(WORK): $(SRCS) $(TESTS)
	$(GHDL) -a $^

analyze: $(WORK)

uart_rx: uart_rx.vcd
uart_rx.vcd: $(WORK)
	$(GHDL) -e $(subst .vcd,_tb,$@)
	$(GHDL) -r $(subst .vcd,_tb,$@) --vcd=$@

uart_rx_wave: uart_rx.vcd
	$(GTKW) $<

uart_tx: uart_tx.vcd
uart_tx.vcd: $(WORK)
	$(GHDL) -e $(subst .vcd,_tb,$@)
	$(GHDL) -r $(subst .vcd,_tb,$@) --vcd=$@

uart_tx_wave: uart_tx.vcd
	$(GTKW) $<

fifo: fifo.vcd
fifo.vcd: $(WORK)
	$(GHDL) -e $(subst .vcd,_tb,$@)
	$(GHDL) -r $(subst .vcd,_tb,$@) --vcd=$@

fifo_wave: fifo.vcd
	$(GTKW) $<

all: uart_rx uart_tx fifo

clean:
	@rm -f *.cf
	@rm -f *.o
	@rm -f sim
	@rm -f *.vcd
