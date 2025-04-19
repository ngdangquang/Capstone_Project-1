# ModelSim simulation script for Semantic Segmentation project

# Set paths
set HDL_DIR "../../hdl"
set TB_DIR "$HDL_DIR/tb"
set RTL_TOP_DIR "$HDL_DIR/rtl/top"
set RTL_CORE_DIR "$HDL_DIR/rtl/core"
set RTL_NETWORK_DIR "$HDL_DIR/rtl/network"
set SIM_DIR "$HDL_DIR/sim"
set WORK_DIR "./work"

# Create work library if it doesn't exist
if {![file exists $WORK_DIR]} {
    vlib $WORK_DIR
}
vmap work $WORK_DIR

# Compile RTL files
vlog -sv -work work $RTL_TOP_DIR/semantic_segmentation_top.v
vlog -sv -work work $RTL_CORE_DIR/image_loader.v
vlog -sv -work work $RTL_CORE_DIR/segmentation_processor.v
vlog -sv -work work $RTL_CORE_DIR/result_display.v
vlog -sv -work work $RTL_CORE_DIR/pll.v
vlog -sv -work work $RTL_NETWORK_DIR/encoder.v
vlog -sv -work work $RTL_NETWORK_DIR/encoder_stages.v
vlog -sv -work work $RTL_NETWORK_DIR/bottleneck.v
vlog -sv -work work $RTL_NETWORK_DIR/decoder.v
vlog -sv -work work $RTL_NETWORK_DIR/decoder_stages.v
vlog -sv -work work $RTL_NETWORK_DIR/cityscapes_class_mapping.v

# Compile testbench files
vlog -sv -work work $TB_DIR/tb_semantic_segmentation_top.v
vlog -sv -work work $TB_DIR/tb_image_loader.v
vlog -sv -work work $TB_DIR/tb_segmentation_processor.v
vlog -sv -work work $TB_DIR/tb_encoder.v
vlog -sv -work work $TB_DIR/tb_bottleneck.v
vlog -sv -work work $TB_DIR/tb_decoder.v
vlog -sv -work work $TB_DIR/tb_result_display.v

# Simulate testbench
if {$argc >= 1} {
    set test_name [lindex $argv 0]
} else {
    set test_name "tb_semantic_segmentation_top"
}

# Start simulation
vsim -t 1ps -L work -voptargs="+acc" $test_name

# Add all waveforms
add wave -position insertpoint sim:/$test_name/*

# Run simulation
run -all

# Quit simulation if not in GUI mode
if {$argc >= 2 && [lindex $argv 1] eq "batch"} {
    quit -f
} 