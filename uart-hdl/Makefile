GHDL := ghdl
GTKW := gtkwave
FLAGS = -O3 --std=08 -fexplicit -Wall
WORKDIR= $(PWD)/work
WORKFILE = $(WORKDIR)/work-obj93.cf

TEX = pdflatex
TEXOPTS = -output-dir=$(DOCBUILD)
DOCNAME = uart_trm.tex
DOCDIR = $(PWD)/docs
DOCBUILD = $(DOCDIR)/build

MODULES = axil_control baud_gen fifo interrupt_generation uart_rx uart_tx
SRCS = $(addprefix srcs/,$(addsuffix .vhd,$(MODULES)))
TESTS = $(addprefix tests/,$(addsuffix _tb.vhd,$(MODULES)))

$(WORKFILE): $(SRCS) $(TESTS)
	mkdir -p $(WORKDIR)
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

create_doc:
	mkdir -p $(DOCBUILD)

$(DOCBUILD)/$(DOCNAME:%.tex=%.pdf): $(DOCDIR)/$(DOCNAME)
	$(TEX) $(TEXOPTS) $^

pdfdocs: create_doc $(DOCBUILD)/$(DOCNAME:%.tex=%.pdf)

all: $(MODULES)
run_all: $(addsuffix _run, $(MODULES))
clean:
	rm -rf $(DOCBUILD)
	rm -rf $(WORKDIR)
