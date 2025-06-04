GHDL := ghdl
GTKW := gtkwave
FLAGS = -O3 --std=08 -fexplicit -Wall
WORKDIR= $(PWD)/work
WORKFILE = $(WORKDIR)/work-obj93.cf

VIVADO = vivado
VIVADO_PATH = $(shell which $(VIVADO))

TEX = pdflatex
TEXOPTS = -output-dir=$(DOCBUILD)
DOCNAME = uart_trm.tex
DOCDIR = $(PWD)/docs
DOCBUILD = $(DOCDIR)/build

MODULES = baud_gen fifo interrupt_generation axil_control uart_rx uart_tx uart_device_top
SRCS = $(addprefix srcs/,$(addsuffix .vhd,$(MODULES)))
TESTS = $(addprefix tests/,$(addsuffix _tb.vhd,$(MODULES)))

$(WORKFILE): $(SRCS) $(TESTS)
	@mkdir -p $(WORKDIR)
	$(GHDL) -a $(FLAGS) --work=work --workdir='$(WORKDIR)' $^

analyze: $(WORKFILE)

.SECONDARY: $(MODULES:%=$(WORKDIR)/%_tb)
$(WORKDIR)/%_tb: $(WORKFILE)
	$(GHDL) -e $(FLAGS) --work=work --workdir='$(WORKDIR)' -o $@ $*_tb

%_run: $(WORKDIR)/%_tb
	@$<

.SECONDARY: $(MODULES:%=$(WORKDIR)/%.vcd)
$(WORKDIR)/%.vcd: $(WORKDIR)/%_tb
	$^ --vcd=$(WORKDIR)/$*.vcd

%_wave: $(WORKDIR)/%.vcd
	$(GTKW) $^

$(MODULES): %: $(WORKDIR)/%_tb

all: $(MODULES)
run_all: $(addsuffix _run, $(MODULES))

check_tools:
	@if [ -z $(strip $(VIVADO_PATH)) ]; then echo "Must source Vivado tools for bitstream"; exit 1; fi

xsa: check_tools
	$(VIVADO) -mode batch -source generate_xsa.tcl -log run.log

create_doc:
	@mkdir -p $(DOCBUILD)

$(DOCBUILD)/$(DOCNAME:%.tex=%.pdf): $(DOCDIR)/$(DOCNAME)
	$(TEX) $(TEXOPTS) $^

pdfdocs: create_doc $(DOCBUILD)/$(DOCNAME:%.tex=%.pdf)

clean:
	@rm -rf $(DOCBUILD)
	@rm -rf $(WORKDIR)
	@rm -rf vivado.prj .Xil
	@rm -f *.xsa *.log *.jou
