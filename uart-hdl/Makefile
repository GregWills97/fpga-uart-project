GHDL := ghdl
GTKW := gtkwave
SRCS = srcs/baud_gen.vhd srcs/uart_rx.vhd srcs/uart_tx.vhd srcs/fifo.vhd
TESTS = tests/baud_gen_tb.vhd tests/uart_rx_tb.vhd tests/uart_tx_tb.vhd tests/fifo_tb.vhd
FLAGS = -O3
WORKDIR= $(PWD)/work
WORKFILE = $(WORKDIR)/work-obj93.cf

TEX = pdflatex
TEXOPTS = -output-dir=$(DOCBUILD)
DOCNAME = uart_trm.tex
DOCDIR = $(PWD)/docs
DOCBUILD = $(DOCDIR)/build

MODULES = baud_gen uart_rx uart_tx fifo

$(WORKFILE): $(SRCS) $(TESTS)
	mkdir -p $(WORKDIR)
	$(GHDL) -a $(FLAGS) --work=work --workdir='$(WORKDIR)' $^

analyze: $(WORKFILE)

$(WORKDIR)/%_tb: $(WORKFILE)
	$(GHDL) -e $(FLAGS) --work=work --workdir='$(WORKDIR)' \
	-o $(WORKDIR)/$*_tb $*_tb

%_run: $(WORKDIR)/%_tb
	$^

$(WORKDIR)/%.vcd: $(WORKDIR)/%_tb
	$^ --vcd=$(WORKDIR)/$*.vcd

%_wave: $(WORKDIR)/%.vcd
	$(GTKW) $^

$(MODULES): %: $(WORKDIR)/%_tb

create_doc:
	mkdir -p $(DOCBUILD)

$(DOCBUILD)/$(DOCNAME:%.tex=%.pdf): $(DOCDIR)/$(DOCNAME)
	$(TEX) $(TEXOPTS) $^

pdfdocs: create_doc $(DOCBUILD)/$(DOCNAME:%.tex=%.pdf)
	echo $^

all: $(MODULES)
clean:
	rm -rf $(DOCBUILD)
	rm -rf $(WORKDIR)
