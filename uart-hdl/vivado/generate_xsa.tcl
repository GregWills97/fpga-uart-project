# Create vivado project
set project_name	"uart_device_proj"
set project_part	"xc7z010clg400-1"
set project_board	"digilentinc.com:zybo-z7-10:part0:1.2"

create_project $project_name [pwd]/$project_name -part $project_part
set_property board_part $project_board [current_project]
set_property target_language VHDL [current_project]

# Package UART device as IP
set ip_proj	"ip_packager_proj"
set ip_name	"uart_device"
set ip_desc	"AXI programmable UART device"
set ip_vendor	"greg.org"
set ip_library	"greg"
set ip_version	"1.0"
set ip_dir	"[pwd]/ip_repo/$ip_name"
set sources	[pwd]/../srcs

# create temporary IP project
create_project $ip_proj [pwd]/$ip_proj -part $project_part
add_files $sources
update_compile_order -fileset sources_1

ipx::package_project -root_dir $ip_dir -vendor $ip_vendor -library $ip_library -name $ip_name \
		     -version $ip_version -taxonomy /UserIP -import_files
set core [ipx::current_core]
set_property display_name "Custom UART Device" $core
set_property description "AXI programmable UART controller" $core
update_compile_order -fileset sources_1
ipx::update_source_project_archive -component $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
current_project $ip_proj
close_project

## Add IP repo to curent project
current_project $project_name
set_property ip_repo_paths [file normalize "[pwd]/ip_repo"] [current_project]
update_ip_catalog -rebuild

# Add constraint file
add_files -fileset constrs_1 -norecurse [pwd]/Zybo-Master.xdc

# Create block design
set bd "uart_block_design_1"
create_bd_design $bd
update_compile_order -fileset sources_1

# Add UART IP and ZYNQ PS
startgroup
create_bd_cell -type ip -vlnv $ip_vendor:$ip_library:$ip_name:$ip_version ${ip_name}_0
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
endgroup

# Enable PL interrupt on PS connect DDR and FIXED_IO
set_property -dict [list \
	CONFIG.PCW_IRQ_F2P_INTR {1} \
	CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
] [get_bd_cells processing_system7_0]
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 \
		    -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" } \
		    [get_bd_cells processing_system7_0]

# Connect PS to AXI UART
# axi signals
apply_bd_automation -rule xilinx.com:bd_rule:axi4 \
		    -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
			    Master {/processing_system7_0/M_AXI_GP0} Slave {/${ip_name}_0/S00_AXI} \
			    ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}} \
		    [get_bd_intf_pins ${ip_name}_0/S00_AXI]

# set clock to 125 Mhz
set_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {125} [get_bd_cells processing_system7_0]

# reset
connect_bd_net [get_bd_pins ${ip_name}_0/uart_rstn] [get_bd_pins rst_ps7_0_50M/peripheral_aresetn]

# interrupt
connect_bd_net [get_bd_pins ${ip_name}_0/uart_intr] [get_bd_pins processing_system7_0/IRQ_F2P]

# external io
set io_list [list uart_rx uart_tx uart_rtsn uart_ctsn]
foreach io $io_list {
	startgroup
	make_bd_pins_external [get_bd_pins ${ip_name}_0/$io]
	endgroup
	set_property name $io [get_bd_ports ${io}_0]
}

# Validate and generate block design
regenerate_bd_layout
validate_bd_design
set proj_dir [pwd]/$project_name
set cache_path $proj_dir/${project_name}.cache
set src_path $proj_dir/${project_name}.srcs
set bd_path $src_path/sources_1/bd/$bd/${bd}.bd
set ip_path $proj_dir/${project_name}.ip_user_files
set wrapper_path $proj_dir/${project_name}.gen/sources_1/bd/${bd}/hdl/${bd}_wrapper.vhd
generate_target all [get_files $bd_path]
catch { config_ip_cache -export [get_ips -all ${bd}_${ip_name}_0_0] }
catch { config_ip_cache -export [get_ips -all ${bd}_axi_smc_0] }
catch { config_ip_cache -export [get_ips -all ${bd}_rst_ps7_0_50M_0] }
export_ip_user_files -of_objects [get_files $bd_path] -no_script -sync -force -quiet
create_ip_run [get_files -of_objects [get_fileset sources_1] $bd_path]
launch_runs \
	${bd}_axi_smc_0_synth_1 \
	${bd}_processing_system7_0_0_synth_1 \
	${bd}_rst_ps7_0_50M_0_synth_1 \
	${bd}_${ip_name}_0_0_synth_1 -jobs 12
export_simulation \
	-lib_map_path [list \
		{modelsim=$cache_path/compile_simlib/modelsim} \
		{questa=$cache_path/compile_simlib/questa} \
		{xcelium=$cache_path/compile_simlib/xcelium} \
		{vcs=$cache_path/compile_simlib/vcs} \
		{riviera=$cache_path/compile_simlib/riviera}] \
	-of_objects [get_files $bd_path] -directory $ip_path/sim_scripts \
	-ip_user_files_dir $ip_path \
	-ipstatic_source_dir $ip_path/ipstatic -use_ip_compiled_libs -force -quiet

wait_on_run ${bd}_axi_smc_0_synth_1
wait_on_run ${bd}_processing_system7_0_0_synth_1
wait_on_run ${bd}_rst_ps7_0_50M_0_synth_1
wait_on_run ${bd}_${ip_name}_0_0_synth_1

make_wrapper -files [get_files $bd_path] -top
add_files -norecurse $wrapper_path

# Run Linter, synthesis and implementation, then write bitstream
create_ip_run [get_files -of_objects [get_fileset sources_1] $bd_path]
synth_design -top uart_block_design_1_wrapper -part xc7z010clg400-1 -lint

launch_runs synth_1 -jobs 12
wait_on_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 12
wait_on_run impl_1

# Export to XSA
write_hw_platform -fixed -include_bit -force -file [pwd]/../system.xsa
