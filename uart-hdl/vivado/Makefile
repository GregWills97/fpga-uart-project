VIVADO = vivado
VIVADO_PATH = $(shell which $(VIVADO))

check_tools:
	@if [ -z $(strip $(VIVADO_PATH)) ]; then echo "Must source Vivado tools for bitstream"; exit 1; fi

xsa: check_tools
	$(VIVADO) -mode batch -source generate_xsa.tcl -log run.log

all: xsa

clean:
	@rm -rf ip_repo *_proj vivado* *.log
