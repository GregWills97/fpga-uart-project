GHDL := ghdl
GTKW := gtkwave
SRCS = srcs/baud_gen.vhd srcs/uart_rx.vhd srcs/uart_tx.vhd
TESTS = tests/uart_rx_tb.vhd tests/uart_tx_tb.vhd

analyze: $(SRCS) $(TESTS)
	$(GHDL) -a $^

uart_rx: analyze
	$(GHDL) -e $@_tb
	$(GHDL) -r $@_tb --vcd=$@.vcd

uart_rx_wave: uart_rx
	$(GTKW) $<.vcd

uart_tx: analyze
	$(GHDL) -e $@_tb
	$(GHDL) -r $@_tb --vcd=$@.vcd

uart_tx_wave: uart_tx
	$(GTKW) $<.vcd

all: uart_rx uart_tx

clean:
	@rm -f *.cf
	@rm -f *.o
	@rm -f sim
	@rm -f *.vcd
