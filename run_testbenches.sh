#!/bin/bash
# Script to run all testbenches for the semantic segmentation project

# Directory structure
RTL_DIR="rtl"
TB_DIR="testbench"
SIM_DIR="simulation"

# Create simulation directory if it doesn't exist
mkdir -p $SIM_DIR

# Function to run a testbench
run_testbench() {
    tb_name=$1
    echo "Running testbench: $tb_name"
    
    # Compile the design and testbench files
    iverilog -o $SIM_DIR/${tb_name}.vvp \
        $TB_DIR/${tb_name}.v \
        $RTL_DIR/top/semantic_segmentation_top.v \
        $RTL_DIR/core/image_loader.v \
        $RTL_DIR/core/segmentation_processor.v \
        $RTL_DIR/core/result_display.v \
        $RTL_DIR/core/pll.v \
        $RTL_DIR/network/encoder.v \
        $RTL_DIR/network/encoder_stages.v \
        $RTL_DIR/network/bottleneck.v \
        $RTL_DIR/network/decoder.v \
        $RTL_DIR/network/decoder_stages.v \
        $RTL_DIR/network/cityscapes_class_mapping.v
    
    # Check if compilation was successful
    if [ $? -eq 0 ]; then
        # Run the simulation
        vvp $SIM_DIR/${tb_name}.vvp
        
        # Generate waveform for viewing (if $dump commands exist in testbench)
        if [ -f "${tb_name}.vcd" ]; then
            mv ${tb_name}.vcd $SIM_DIR/
            echo "VCD file created: $SIM_DIR/${tb_name}.vcd"
        fi
    else
        echo "Compilation failed for $tb_name"
    fi
    
    echo "-------------------------------------"
}

# List of all testbenches
testbenches=(
    "tb_semantic_segmentation_top"
    "tb_image_loader"
    "tb_segmentation_processor"
    "tb_encoder"
    "tb_bottleneck"
    "tb_decoder"
    "tb_result_display"
)

# Run each testbench
for tb in "${testbenches[@]}"; do
    run_testbench $tb
done

echo "All testbenches completed."

# Optional: Open GTKWave with the first testbench's waveform
if command -v gtkwave &> /dev/null && [ -f "$SIM_DIR/tb_semantic_segmentation_top.vcd" ]; then
    echo "Opening GTKWave with the first testbench waveform..."
    gtkwave $SIM_DIR/tb_semantic_segmentation_top.vcd &
fi 