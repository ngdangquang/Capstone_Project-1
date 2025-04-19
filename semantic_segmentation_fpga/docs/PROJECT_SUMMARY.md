# Semantic Segmentation FPGA Project Summary

**Author:** Nguyen Dang Quang  
**Student ID:** 2251043  
**Date:** April 2025

## Project Overview

This project implements a complete semantic segmentation system using U-Net architecture on the DE10-Standard FPGA kit. The system processes 224×224 RGB images and classifies each pixel into one of 21 semantic categories. The implementation achieves real-time performance (30 fps) with low power consumption (4.7W), making it suitable for embedded vision applications.

## Key Features

- **Real-time Performance**: 30 frames per second processing
- **Low Power Consumption**: Only 4.7W during operation
- **Complete Pipeline**: Image loading from SDRAM, segmentation, and display via VGA
- **Full U-Net Architecture**: 3 encoder stages, bottleneck, and 3 decoder stages
- **21 Semantic Classes**: Compatible with Pascal VOC dataset format
- **Fixed-Point Implementation**: 8.8 format for optimal precision/resource balance
- **Resource-Efficient**: 54% ALM utilization, 21% register utilization on Cyclone V FPGA

## Technical Implementation

The implementation includes:
- **Hardware Optimizations**: Double buffering, optimized memory access patterns
- **Efficient Convolution**: Sliding window approach with parallel MAC operations
- **Memory Management**: Block RAM with dual-port access for feature maps
- **State Machine Control**: Coordinated operation between modules

## Project Structure

```
semantic_segmentation_fpga/
├── hdl/                     # Verilog code
│   ├── rtl/                 # Register Transfer Level design
│   │   ├── top/             # Top-level module
│   │   ├── core/            # Core system modules
│   │   └── network/         # Neural network modules
│   ├── tb/                  # Testbenches
│   └── sim/                 # Simulation files
├── constraints/             # FPGA constraints
├── scripts/                 # Build and simulation scripts
│   ├── build/               # Build scripts
│   ├── sim/                 # Simulation scripts
│   └── tools/               # Utility scripts
├── data/                    # Data resources
│   ├── raw/                 # Raw data
│   ├── processed/           # Processed data
│   └── test/                # Test vectors
├── docs/                    # Documentation
│   ├── paper.md             # IEEE paper
│   ├── technical_report.md  # Technical report
│   ├── README.md            # Usage instructions
│   └── pdf/                 # PDF versions of documentation
└── LICENSE                  # MIT license
```

## Major Components

1. **Top Module (`semantic_segmentation_top.v`)**: System coordination
2. **Image Loader (`image_loader.v`)**: SDRAM interface for reading images
3. **Segmentation Processor (`segmentation_processor.v`)**: Pipeline control
4. **Encoder (`encoder.v`, `encoder_stages.v`)**: Feature extraction
5. **Bottleneck (`bottleneck.v`)**: Feature processing
6. **Decoder (`decoder.v`, `decoder_stages.v`)**: Upsampling and segmentation
7. **Result Display (`result_display.v`)**: VGA output of results

## Performance Metrics

- **Processing Time**: 33.2 ms per 224×224 RGB image
- **Throughput**: 30.1 frames per second
- **Power Consumption**: 4.7W during operation
- **Energy Efficiency**: 0.156 J per frame (vs. 11.21 J for CPU, 8.26 J for GPU)
- **Segmentation Accuracy**: 65.8% mIoU (vs. 67.8% for floating-point implementation)

## Build and Usage Instructions

### Building the Project

1. Install Intel Quartus Prime 18.1 or later
2. Change to the project directory
3. Run the build script:
   ```bash
   cd semantic_segmentation_fpga/scripts/build
   quartus_sh -t quartus_build.tcl
   ```

### Running Simulations

```bash
cd semantic_segmentation_fpga/scripts/sim
vsim -do run_modelsim.tcl
```

### Generating Documentation

```bash
cd semantic_segmentation_fpga/scripts/tools
# For Windows users
convert_docs.bat
# For Linux/Mac users
./convert_docs.sh
```

## Future Work

1. **Higher Resolution Support**: Extend to 512×512 or 1024×1024 images
2. **Advanced Architectures**: Implement DeepLabv3+ or other architectures
3. **Quantization Optimization**: Mixed-precision and dynamic quantization
4. **Real-Time Applications**: Integration with autonomous vehicles or medical imaging
5. **Other FPGA Platforms**: Port to additional FPGA devices

## Conclusion

This project demonstrates the feasibility of implementing complex neural networks on FPGA hardware. The results show that FPGAs can provide a good balance between performance and power consumption for real-time semantic segmentation tasks, making them suitable for edge devices and embedded systems. 