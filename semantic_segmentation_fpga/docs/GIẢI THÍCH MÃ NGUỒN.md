# Giải Thích Mã Nguồn: Phân Đoạn Ngữ Nghĩa (Semantic Segmentation) trên FPGA

Tài liệu này cung cấp giải thích chi tiết về triển khai phân đoạn ngữ nghĩa trên kit FPGA DE10-Standard.

## Kiến Trúc Tổng Thể

Hệ thống triển khai kiến trúc U-Net đơn giản hóa, một mạng nơ-ron tích chập (CNN) được sử dụng phổ biến cho các tác vụ phân đoạn hình ảnh. Triển khai bao gồm các thành phần chính sau:

1. **Module Đầu Mối** (`semantic_segmentation_top.v`): Điều phối tất cả các hoạt động và luồng dữ liệu giữa các thành phần
2. **Bộ Tải Hình Ảnh** (`image_loader.v`): Đọc dữ liệu hình ảnh từ SDRAM
3. **Bộ Xử Lý Phân Đoạn** (`segmentation_processor.v`): Đường dẫn xử lý chính
4. **Encoder** (`encoder.v`): Đường dẫn giảm mẫu của U-Net
5. **Bottleneck** (`bottleneck.v`): Lớp giữa của U-Net
6. **Decoder** (`decoder.v`): Đường dẫn tăng mẫu của U-Net
7. **Hiển Thị Kết Quả** (`result_display.v`): Xuất kết quả ra màn hình VGA

## Luồng Dữ Liệu

Hệ thống hoạt động theo luồng dữ liệu sau:

1. Dữ liệu hình ảnh được tải từ SDRAM vào bộ đệm đầu vào
2. Bộ xử lý phân đoạn chuẩn hóa dữ liệu hình ảnh
3. Encoder trích xuất đặc trưng thông qua tích chập và giảm mẫu
4. Bottleneck xử lý biểu diễn đã nén
5. Decoder tăng mẫu các đặc trưng và kết hợp chúng với các kết nối tắt (skip connections)
6. Bộ xử lý phân đoạn thực hiện hậu xử lý để xác định nhãn lớp
7. Bộ hiển thị kết quả ánh xạ nhãn lớp sang màu sắc và xuất ra VGA

## Mô Tả Các Module

### Module Đầu Mối (`semantic_segmentation_top.v`)

Module đầu mối triển khai một máy trạng thái với bốn trạng thái:
- **IDLE**: Chờ tín hiệu bắt đầu
- **LOAD_IMAGE**: Tải dữ liệu hình ảnh từ SDRAM
- **PROCESS**: Xử lý hình ảnh qua mạng phân đoạn
- **DISPLAY_RESULT**: Hiển thị kết quả phân đoạn

Nó điều phối tất cả các module khác và xử lý việc truyền dữ liệu giữa chúng.

### Bộ Tải Hình Ảnh (`image_loader.v`)

Module này giao tiếp với SDRAM để đọc dữ liệu hình ảnh. Nó triển khai một máy trạng thái để phát lệnh đọc và xử lý dữ liệu nhận được. Tính năng:
- Đọc từ 32-bit từ SDRAM và tách chúng thành các byte riêng lẻ (pixel RGB)
- Hỗ trợ đọc dạng burst để tăng hiệu suất
- Ghi pixel vào bộ đệm đầu vào của module đầu mối

### Bộ Xử Lý Phân Đoạn (`segmentation_processor.v`)

Trung tâm của hệ thống, triển khai một máy trạng thái với sáu trạng thái:
- **IDLE**: Chờ tín hiệu bắt đầu
- **PREPROCESS**: Chuẩn hóa dữ liệu pixel đầu vào sang định dạng số cố định
- **ENCODE**: Chạy các giai đoạn encoder
- **BOTTLENECK**: Chạy lớp bottleneck
- **DECODE**: Chạy các giai đoạn decoder
- **POSTPROCESS**: Chuyển đổi đầu ra mạng thành nhãn lớp

Trong bước hậu xử lý, nó thực hiện thao tác "argmax" để tìm lớp có xác suất cao nhất cho mỗi pixel.

### Encoder (`encoder.v`)

Triển khai đường dẫn giảm mẫu của U-Net. Nó bao gồm ba giai đoạn encoder, mỗi giai đoạn chứa:
- Các lớp tích chập
- Kích hoạt ReLU
- Max pooling

Mỗi giai đoạn tăng gấp đôi số kênh và giảm một nửa kích thước không gian:
- Giai đoạn 1: 3→64 kênh, 224×224→112×112
- Giai đoạn 2: 64→128 kênh, 112×112→56×56
- Giai đoạn 3: 128→256 kênh, 56×56→28×28

### Bottleneck (`bottleneck.v`)

Phần trung tâm của U-Net xử lý biểu diễn nén nhất. Nó thực hiện:
- Kích hoạt ReLU trên các đặc trưng đầu vào
- Trong một triển khai đầy đủ, nó sẽ thực hiện các tích chập bổ sung

### Decoder (`decoder.v`)

Triển khai đường dẫn tăng mẫu của U-Net. Nó bao gồm ba giai đoạn decoder, mỗi giai đoạn chứa:
- Tăng mẫu của bản đồ đặc trưng
- Nối (concatenation) với các kết nối tắt từ encoder
- Tích chập để giảm số kênh

Mỗi giai đoạn giảm một nửa số kênh và tăng gấp đôi kích thước không gian:
- Giai đoạn 1: 256→128 kênh, 28×28→56×56
- Giai đoạn 2: 128→64 kênh, 56×56→112×112
- Giai đoạn 3: 64→21 kênh, 112×112→224×224

Giai đoạn cuối cùng xuất logits cho mỗi lớp trong số 21 lớp.

### Hiển Thị Kết Quả (`result_display.v`)

Module này xử lý thời gian VGA và hiển thị kết quả phân đoạn. Tính năng:
- Tạo tín hiệu thời gian VGA
- Ánh xạ chỉ số lớp sang màu RGB
- Điều chỉnh kích thước hình ảnh đầu ra để phù hợp với màn hình

## Chi Tiết Triển Khai

### Số Học Điểm Cố Định

Tất cả các tính toán nội bộ sử dụng số học điểm cố định ở định dạng 8.8 (8 bit cho phần nguyên, 8 bit cho phần phân số). Điều này cung cấp sự cân bằng tốt giữa độ chính xác và sử dụng tài nguyên.

### Triển Khai Tích Chập

Tích chập được triển khai bằng cách sử dụng một phương pháp đơn giản hóa:
1. Xử lý một pixel đầu ra tại một thời điểm
2. Đối với mỗi pixel đầu ra, tính tổng có trọng số của các pixel đầu vào trong vùng lân cận 3×3
3. Thêm bias
4. Áp dụng kích hoạt ReLU

### Tổ Chức Bộ Nhớ

- Hình ảnh đầu vào: Được lưu trữ trong SDRAM ở định dạng RGB888 (8 bit cho mỗi kênh)
- Bản đồ đặc trưng: Được lưu trữ trong khối RAM trong FPGA
- Trọng số: Được khởi tạo ngẫu nhiên trong demo này (sẽ được tải từ bộ nhớ trong ứng dụng thực tế)

### Kỹ Thuật Tối Ưu Hóa

Nhiều phương pháp tối ưu hóa được sử dụng để làm cho triển khai hiệu quả trên FPGA:
1. **Xử Lý Tuần Tự**: Các thao tác được thực hiện tuần tự để giảm sử dụng tài nguyên
2. **Máy Trạng Thái**: Mỗi module sử dụng một máy trạng thái để kiểm soát luồng xử lý
3. **Đơn Giản Hóa Thao Tác**: Các thao tác phức tạp được đơn giản hóa khi có thể
4. **Chia Sẻ Tài Nguyên**: Các phép toán được tái sử dụng khi có thể

## Cân Nhắc Hiệu Suất

Triển khai hiện tại ưu tiên sử dụng tài nguyên hơn tốc độ. Để có hiệu suất cao hơn:
1. Có thể đưa ra nhiều xử lý song song hơn trong các hoạt động tích chập
2. Có thể thêm các giai đoạn pipeline
3. Có thể sử dụng các mẫu truy cập bộ nhớ hiệu quả hơn

## Cải Tiến Trong Tương Lai

Những cải tiến có thể cho các phiên bản tương lai:
1. Hỗ trợ tải trọng số đã được huấn luyện trước
2. Triển khai chuẩn hóa batch (batch normalization)
3. Hỗ trợ cho các kích thước hình ảnh đầu vào khác nhau
4. Tăng tốc phần cứng cho các hoạt động tích chập
5. Hỗ trợ xử lý video
6. Triển khai các kiến trúc mạng phức tạp hơn 








semantic_segmentation_fpga/
├── hdl/                              # Mã nguồn Verilog
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