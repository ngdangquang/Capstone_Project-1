# Timing Constraints for Semantic Segmentation on DE10-Standard

# Primary clocks
create_clock -period 20.000 -name {clk} [get_ports {clk}]

# Derived clocks (from PLL)
create_generated_clock -name {sys_clk} -source [get_ports {clk}] -master_clock {clk} -divide_by 1 -multiply_by 1 [get_pins {system_pll|c0}]
create_generated_clock -name {vga_pll_clk} -source [get_ports {clk}] -master_clock {clk} -divide_by 2 -multiply_by 1 [get_pins {system_pll|c1}]

# Clock uncertainties
derive_clock_uncertainty

# Input delays
set_input_delay -clock {sys_clk} -max 2.000 [get_ports {reset_n}]
set_input_delay -clock {sys_clk} -max 2.000 [get_ports {start_process}]
set_input_delay -clock {sys_clk} -max 2.000 [get_ports {sdram_data*}]

# Output delays
set_output_delay -clock {sys_clk} -max 2.000 [get_ports {sdram_addr*}]
set_output_delay -clock {sys_clk} -max 2.000 [get_ports {sdram_*_n}]
set_output_delay -clock {sys_clk} -max 2.000 [get_ports {processing_done}]
set_output_delay -clock {sys_clk} -max 2.000 [get_ports {leds*}]

# VGA output delays
set_output_delay -clock {vga_pll_clk} -max 2.000 [get_ports {vga_*}]

# Cut paths between different clock domains
set_clock_groups -asynchronous -group {sys_clk} -group {vga_pll_clk}

# False paths
set_false_path -from [get_ports {reset_n}] -to *
set_false_path -from * -to [get_ports {leds*}]

# Multicycle paths
# None required at this time 