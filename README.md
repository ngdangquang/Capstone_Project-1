semantic_segmentation_top.v: Module top-level
image_loader.v: Module đọc ảnh từ SDRAM
segmentation_processor.v: Module xử lý semantic segmentation
encoder.v: Module encoder cho kiến trúc U-Net
bottleneck.v: Module bottleneck (lớp giữa encoder và decoder)
decoder.v: Module decoder cho kiến trúc U-Net
result_display.v: Module hiển thị kết quả
pll.v: Module PLL cho đồng hồ hệ thống
encoder_stages.v: Các module encoder stage
decoder_stages.v: Các module decoder stage


# Semantic Segmentation Project for DE10-Standard FPGA Kit

## Overview

This project implements a U-Net based semantic segmentation system on the DE10-Standard FPGA development kit. The system processes pre-loaded images from SDRAM and displays segmentation results through the VGA interface.

## Features

- Processes 224x224 RGB images
- Implements U-Net architecture with 3 encoder/decoder stages
- Supports up to 21 semantic classes (Pascal VOC dataset format)
- Loads images from SDRAM
- Displays results via VGA output
- Uses LED indicators for system status

## Hardware Requirements

- DE10-Standard FPGA kit (Terasic)
- VGA-compatible display
- SDRAM with pre-loaded image data
- Power supply

## Directory Structure

```
├── semantic_segmentation_top.v  # Top-level module
├── image_loader.v               # Module for loading image from SDRAM
├── segmentation_processor.v     # Core segmentation processing
├── encoder.v                    # Encoder part of U-Net
├── bottleneck.v                 # Central bottleneck of U-Net
├── decoder.v                    # Decoder part of U-Net
├── encoder_stages.v             # Individual encoder stage modules
├── decoder_stages.v             # Individual decoder stage modules
├── result_display.v             # Display results via VGA
└── pll.v                        # Clock generation
```

## Usage Instructions

### Preparing Image Data

1. Convert your image to 224x224 pixel format
2. Upload the image data to SDRAM using the Quartus Memory Editor or custom loader software
3. The image data should be stored as raw RGB pixels (8-bit per channel) starting from the base address defined in the `image_loader.v` file (default: 0x00000)

### Running the System

1. Connect the VGA output of DE10-Standard to a display
2. Power on the board
3. Press the activation button (connected to `start_process` input) to start processing
4. The system will load the image from SDRAM, process it, and display the segmentation results

### Status LEDs

- LEDs[2:0]: Current state (0=IDLE, 1=LOAD_IMAGE, 2=PROCESS, 3=DISPLAY_RESULT)
- LED3: Image loading completed
- LED4: Processing completed
- LED5: Display completed

### Modifying the Project

To change the number of classes or image dimensions:
- Modify the parameters in `semantic_segmentation_top.v`
- Adjust the color mapping in `result_display.v` to match your classes

## Timing

- Image loading: Depends on SDRAM speed (typically a few milliseconds)
- Processing: Variable based on FPGA clock speed (typically under 1 second)
- Results are displayed immediately after processing

## Implementation Details

This implementation uses fixed-point arithmetic (8.8 format) for all internal calculations. Weights are randomly initialized in this demo version - for actual deployment, pre-trained weights should be loaded from memory.

---

# Dự Án Phân Đoạn Ngữ Nghĩa (Semantic Segmentation) cho FPGA DE10-Standard

## Tổng Quan

Dự án này triển khai hệ thống phân đoạn ngữ nghĩa dựa trên kiến trúc U-Net trên kit phát triển FPGA DE10-Standard. Hệ thống xử lý các hình ảnh được tải sẵn từ SDRAM và hiển thị kết quả phân đoạn qua giao diện VGA.

## Tính Năng

- Xử lý hình ảnh RGB kích thước 224x224
- Triển khai kiến trúc U-Net với 3 tầng encoder/decoder
- Hỗ trợ tối đa 21 lớp ngữ nghĩa (định dạng dataset Pascal VOC)
- Tải hình ảnh từ SDRAM
- Hiển thị kết quả qua đầu ra VGA
- Sử dụng đèn LED để hiển thị trạng thái hệ thống

## Yêu Cầu Phần Cứng

- Kit FPGA DE10-Standard (Terasic)
- Màn hình tương thích VGA
- SDRAM với dữ liệu hình ảnh được tải trước
- Nguồn điện

## Cấu Trúc Thư Mục

```
├── semantic_segmentation_top.v  # Module cấp cao nhất
├── image_loader.v               # Module tải hình ảnh từ SDRAM
├── segmentation_processor.v     # Xử lý phân đoạn cốt lõi
├── encoder.v                    # Phần encoder của U-Net
├── bottleneck.v                 # Phần bottleneck trung tâm của U-Net
├── decoder.v                    # Phần decoder của U-Net
├── encoder_stages.v             # Các module tầng encoder
├── decoder_stages.v             # Các module tầng decoder
├── result_display.v             # Hiển thị kết quả qua VGA
└── pll.v                        # Tạo tín hiệu đồng hồ
```

## Hướng Dẫn Sử Dụng

### Chuẩn Bị Dữ Liệu Hình Ảnh

1. Chuyển đổi hình ảnh của bạn sang định dạng 224x224 pixel
2. Tải dữ liệu hình ảnh lên SDRAM sử dụng Quartus Memory Editor hoặc phần mềm tải tùy chỉnh
3. Dữ liệu hình ảnh nên được lưu trữ dưới dạng pixel RGB thô (8-bit cho mỗi kênh) bắt đầu từ địa chỉ cơ sở được định nghĩa trong file `image_loader.v` (mặc định: 0x00000)

### Chạy Hệ Thống

1. Kết nối đầu ra VGA của DE10-Standard với màn hình
2. Bật nguồn board
3. Nhấn nút kích hoạt (được kết nối với đầu vào `start_process`) để bắt đầu xử lý
4. Hệ thống sẽ tải hình ảnh từ SDRAM, xử lý và hiển thị kết quả phân đoạn

### Đèn LED Trạng Thái

- LEDs[2:0]: Trạng thái hiện tại (0=IDLE, 1=LOAD_IMAGE, 2=PROCESS, 3=DISPLAY_RESULT)
- LED3: Đã hoàn thành tải hình ảnh
- LED4: Đã hoàn thành xử lý
- LED5: Đã hoàn thành hiển thị

### Sửa Đổi Dự Án

Để thay đổi số lượng lớp hoặc kích thước hình ảnh:
- Sửa đổi các tham số trong `semantic_segmentation_top.v`
- Điều chỉnh bảng màu trong `result_display.v` để phù hợp với các lớp của bạn

## Thời Gian

- Tải hình ảnh: Phụ thuộc vào tốc độ SDRAM (thường vài mili giây)
- Xử lý: Thay đổi dựa trên tốc độ đồng hồ FPGA (thường dưới 1 giây)
- Kết quả được hiển thị ngay sau khi xử lý

## Chi Tiết Triển Khai

Triển khai này sử dụng số học định điểm cố định (dạng 8.8) cho tất cả các tính toán bên trong. Trọng số được khởi tạo ngẫu nhiên trong phiên bản demo này - để triển khai thực tế, các trọng số đã được huấn luyện trước nên được tải từ bộ nhớ. 








semantic_segmentation_fpga/
├── hdl/                              # Verilog
│   ├── rtl/                          # Register Transfer Level design
│   │   ├── top/
│   │   │   └── semantic_segmentation_top.v
│   │   ├── core/
│   │   │   ├── image_loader.v
│   │   │   ├── segmentation_processor.v
│   │   │   ├── result_display.v
│   │   │   └── pll.v
│   │   └── network/
│   │       ├── encoder.v
│   │       ├── encoder_stages.v
│   │       ├── bottleneck.v
│   │       ├── decoder.v
│   │       ├── decoder_stages.v
│   │       └── cityscapes_class_mapping.v
│   ├── tb/                           # Testbenches
│   │   ├── tb_semantic_segmentation_top.v
│   │   ├── tb_image_loader.v
│   │   ├── tb_segmentation_processor.v
│   │   ├── tb_encoder.v
│   │   ├── tb_bottleneck.v
│   │   ├── tb_decoder.v
│   │   └── tb_result_display.v
│   └── sim/                          # Simulation control files
│       ├── tb_top.v                  # Top-level testbench
│       └── includes.v                # Common include file
│
├── constraints/                      # FPGA timing constraints
│   └── de10_standard.sdc             # Timing constraints for DE10-Standard
│
├── scripts/                          # Scripts for build, test, etc.
│   ├── build/
│   │   ├── quartus_build.tcl         # Quartus build script
│   │   └── vivado_build.tcl          # Vivado build script (optional)
│   ├── sim/
│   │   ├── run_testbenches.sh        # Linux/Mac simulation script
│   │   └── run_testbenches.bat       # Windows simulation script
│   └── tools/
│       └── cityscapes_data_converter.py  # Data conversion utility
│
├── data/                             # Data resources
│   ├── raw/                          # Raw data sources
│   │   └── cityscapes/               # Original Cityscapes data
│   ├── processed/                    # Processed data for FPGA
│   │   └── bin/                      # Binary files for SDRAM
│   └── test/                         # Test vectors
│       └── images/                   # Test images
│
├── docs/                             # Documentation
│   ├── specs/
│   │   ├── requirements.md           # Project requirements
│   │   └── architecture.md           # Architecture description
│   ├── design/
│   │   ├── block_diagrams/           # Block diagrams
│   │   └── state_machines/           # State machine diagrams
│   ├── reports/                      # Test reports, utilization, timing
│   │   └── timing_report.pdf
│   ├── README.md                     # Main project README
│   ├── CODE_EXPLANATION.md           # English code explanation
│   └── GIẢI THÍCH MÃ NGUỒN.md        # Vietnamese code explanation
│
├── ip/                               # IP cores (if needed)
│   └── external/                     # 3rd party IP
│
├── build/                            # Build outputs
│   ├── quartus/                      # Quartus build files
│   │   └── output_files/             # Quartus outputs
│   └── simulation/                   # Simulation outputs
│       ├── log/                      # Simulation logs
│       └── waves/                    # Waveform dumps
│
├── tools/                            # Supplementary tools
│   └── memory_editor/                # Memory editor for SDRAM
│
├── .gitignore                        # Git ignore file
└── LICENSE                           # Project license
