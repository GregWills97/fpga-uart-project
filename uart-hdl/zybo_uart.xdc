#Pmod Header JD
set_property -dict { PACKAGE_PIN T14	IOSTANDARD LVCMOS33 } [get_ports { uart_ctsn }]; #IO_L5P_T0_34 Sch=JD1_P
set_property -dict { PACKAGE_PIN T15	IOSTANDARD LVCMOS33 } [get_ports { uart_tx }]; #IO_L5N_T0_34 Sch=JD1_N
set_property -dict { PACKAGE_PIN P14	IOSTANDARD LVCMOS33 } [get_ports { uart_rx }]; #IO_L6P_T0_34 Sch=JD2_P
set_property -dict { PACKAGE_PIN R14	IOSTANDARD LVCMOS33 } [get_ports { uart_rtsn }]; #IO_L6N_T0_VREF_34 Sch=JD2_N
