// Top module cho Semantic Segmentation trên DE10 Standard Kit
module semantic_segmentation_top (
    input wire clk,
    input wire reset_n,
    // Giao diện điều khiển
    input wire start_process,
    output wire processing_done,
    // Giao diện bộ nhớ
    output wire [19:0] sdram_addr,
    inout wire [31:0] sdram_data,
    output wire sdram_we_n,
    output wire sdram_cs_n,
    output wire sdram_ras_n,
    output wire sdram_cas_n,
    // Giao diện VGA
    output wire [7:0] vga_r,
    output wire [7:0] vga_g,
    output wire [7:0] vga_b,
    output wire vga_hsync,
    output wire vga_vsync,
    output wire vga_blank_n,
    output wire vga_sync_n,
    output wire vga_clk,
    // Giao diện LED
    output wire [9:0] leds
);

    // Các tham số của mạng
    localparam INPUT_WIDTH = 224;
    localparam INPUT_HEIGHT = 224;
    localparam INPUT_CHANNELS = 3;
    localparam NUM_CLASSES = 21; // Cho Pascal VOC dataset
    
    // Tín hiệu đồng hồ và reset
    wire sys_clk;
    wire sys_rst;
    wire vga_pll_clk;
    
    // PLL cho đồng hồ hệ thống và VGA
    pll system_pll (
        .inclk0(clk),
        .c0(sys_clk),
        .c1(vga_pll_clk)
    );
    
    // Đồng bộ hóa reset
    reg [2:0] reset_sync;
    always @(posedge sys_clk or negedge reset_n) begin
        if (!reset_n)
            reset_sync <= 3'b111;
        else
            reset_sync <= {reset_sync[1:0], 1'b0};
    end
    assign sys_rst = reset_sync[2];
    
    // Giao diện người dùng - trạng thái máy trạng thái chính
    localparam IDLE = 3'd0;
    localparam LOAD_IMAGE = 3'd1;
    localparam PROCESS = 3'd2;
    localparam DISPLAY_RESULT = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Tín hiệu điều khiển
    reg start_loading, start_processing, start_display;
    wire loading_done, processing_done_int, display_done;
    
    // Bộ nhớ ảnh đầu vào
    reg [7:0] input_buffer [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1];
    wire [19:0] input_write_addr;
    wire input_write_en;
    wire [7:0] input_pixel_data;
    
    // Bộ nhớ kết quả
    reg [7:0] output_buffer [0:INPUT_WIDTH*INPUT_HEIGHT-1];
    wire [19:0] output_read_addr;
    wire [7:0] output_pixel_data;
    
    // Máy trạng thái chính
    always @(posedge sys_clk or posedge sys_rst) begin
        if (sys_rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Logic trạng thái tiếp theo
    always @(*) begin
        next_state = state;
        start_loading = 1'b0;
        start_processing = 1'b0;
        start_display = 1'b0;
        
        case (state)
            IDLE: begin
                if (start_process) begin
                    next_state = LOAD_IMAGE;
                    start_loading = 1'b1;
                end
            end
            
            LOAD_IMAGE: begin
                if (loading_done) begin
                    next_state = PROCESS;
                    start_processing = 1'b1;
                end
            end
            
            PROCESS: begin
                if (processing_done_int) begin
                    next_state = DISPLAY_RESULT;
                    start_display = 1'b1;
                end
            end
            
            DISPLAY_RESULT: begin
                if (display_done) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Hiển thị trạng thái trên LED
    assign leds[2:0] = state;
    assign leds[3] = loading_done;
    assign leds[4] = processing_done_int;
    assign leds[5] = display_done;
    assign leds[9:6] = 4'b0;
    
    // Tín hiệu trạng thái
    assign processing_done = (state == IDLE);
    
    // Module đọc dữ liệu ảnh từ SDRAM
    image_loader #(
        .IMAGE_WIDTH(INPUT_WIDTH),
        .IMAGE_HEIGHT(INPUT_HEIGHT),
        .CHANNELS(INPUT_CHANNELS)
    ) loader (
        .clk(sys_clk),
        .rst(sys_rst),
        .start(start_loading),
        .sdram_addr(sdram_addr),
        .sdram_data(sdram_data),
        .sdram_we_n(sdram_we_n),
        .sdram_cs_n(sdram_cs_n),
        .sdram_ras_n(sdram_ras_n),
        .sdram_cas_n(sdram_cas_n),
        .pixel_data(input_pixel_data),
        .pixel_addr(input_write_addr),
        .pixel_we(input_write_en),
        .done(loading_done)
    );
    
    // Module xử lý semantic segmentation chính
    segmentation_processor #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INPUT_HEIGHT(INPUT_HEIGHT),
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .NUM_CLASSES(NUM_CLASSES)
    ) processor (
        .clk(sys_clk),
        .rst(sys_rst),
        .start(start_processing),
        .input_buffer(input_buffer),
        .output_buffer(output_buffer),
        .done(processing_done_int)
    );
    
    // Module hiển thị kết quả
    result_display #(
        .IMAGE_WIDTH(INPUT_WIDTH),
        .IMAGE_HEIGHT(INPUT_HEIGHT)
    ) display (
        .clk(sys_clk),
        .vga_clk(vga_pll_clk),
        .rst(sys_rst),
        .start(start_display),
        .output_buffer(output_buffer),
        .pixel_addr(output_read_addr),
        .pixel_data(output_pixel_data),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_blank_n(vga_blank_n),
        .vga_sync_n(vga_sync_n),
        .vga_clk(vga_clk),
        .done(display_done)
    );
    
    // Đọc dữ liệu input để xử lý
    always @(posedge sys_clk) begin
        if (input_write_en) begin
            input_buffer[input_write_addr] <= input_pixel_data;
        end
    end

endmodule

// Module tải ảnh từ SDRAM
module image_loader #(
    parameter IMAGE_WIDTH = 224,
    parameter IMAGE_HEIGHT = 224,
    parameter CHANNELS = 3
)(
    input wire clk,
    input wire rst,
    input wire start,
    output reg [19:0] sdram_addr,
    inout wire [31:0] sdram_data,
    output reg sdram_we_n,
    output reg sdram_cs_n,
    output reg sdram_ras_n,
    output reg sdram_cas_n,
    output reg [7:0] pixel_data,
    output reg [19:0] pixel_addr,
    output reg pixel_we,
    output reg done
);
    // Tham số của SDRAM
    localparam BASE_ADDR = 20'h00000;
    localparam BURST_LEN = 8;
    
    // Các trạng thái
    localparam IDLE = 3'd0;
    localparam INIT = 3'd1;
    localparam READ_CMD = 3'd2;
    localparam READ_DATA = 3'd3;
    localparam WAIT_NEXT = 3'd4;
    localparam FINISH = 3'd5;
    
    // Thanh ghi trạng thái và điều khiển
    reg [2:0] state, next_state;
    reg [19:0] mem_addr;
    reg [19:0] pixel_cnt;
    reg [2:0] burst_cnt;
    reg [31:0] pixel_buffer;
    reg [1:0] byte_cnt;
    
    // Định nghĩa trạng thái
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Logic trạng thái tiếp theo
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
            end
            
            INIT: begin
                next_state = READ_CMD;
            end
            
            READ_CMD: begin
                next_state = READ_DATA;
            end
            
            READ_DATA: begin
                if (burst_cnt == BURST_LEN-1)
                    next_state = WAIT_NEXT;
            end
            
            WAIT_NEXT: begin
                if (pixel_cnt >= IMAGE_WIDTH*IMAGE_HEIGHT*CHANNELS)
                    next_state = FINISH;
                else
                    next_state = READ_CMD;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Điều khiển đọc SDRAM và pixel
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sdram_addr <= 20'h0;
            sdram_we_n <= 1'b1;
            sdram_cs_n <= 1'b1;
            sdram_ras_n <= 1'b1;
            sdram_cas_n <= 1'b1;
            pixel_data <= 8'h0;
            pixel_addr <= 20'h0;
            pixel_we <= 1'b0;
            done <= 1'b0;
            mem_addr <= BASE_ADDR;
            pixel_cnt <= 20'h0;
            burst_cnt <= 3'h0;
            byte_cnt <= 2'h0;
            pixel_buffer <= 32'h0;
        end else begin
            case (state)
                IDLE: begin
                    sdram_cs_n <= 1'b1;
                    pixel_we <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        mem_addr <= BASE_ADDR;
                        pixel_cnt <= 20'h0;
                    end
                end
                
                INIT: begin
                    sdram_cs_n <= 1'b1;
                    pixel_we <= 1'b0;
                end
                
                READ_CMD: begin
                    sdram_addr <= mem_addr;
                    sdram_cs_n <= 1'b0;
                    sdram_ras_n <= 1'b0;
                    sdram_cas_n <= 1'b0;
                    sdram_we_n <= 1'b1;  // Đọc
                    burst_cnt <= 3'h0;
                    byte_cnt <= 2'h0;
                end
                
                READ_DATA: begin
                    burst_cnt <= burst_cnt + 1'b1;
                    pixel_buffer <= sdram_data;
                    
                    // Xử lý từng byte trong từ 32-bit 
                    case (byte_cnt)
                        2'h0: begin
                            pixel_data <= pixel_buffer[7:0];
                            pixel_addr <= pixel_cnt;
                            pixel_we <= 1'b1;
                            pixel_cnt <= pixel_cnt + 1'b1;
                            byte_cnt <= 2'h1;
                        end
                        2'h1: begin
                            pixel_data <= pixel_buffer[15:8];
                            pixel_addr <= pixel_cnt;
                            pixel_we <= 1'b1;
                            pixel_cnt <= pixel_cnt + 1'b1;
                            byte_cnt <= 2'h2;
                        end
                        2'h2: begin
                            pixel_data <= pixel_buffer[23:16];
                            pixel_addr <= pixel_cnt;
                            pixel_we <= 1'b1;
                            pixel_cnt <= pixel_cnt + 1'b1;
                            byte_cnt <= 2'h3;
                        end
                        2'h3: begin
                            pixel_data <= pixel_buffer[31:24];
                            pixel_addr <= pixel_cnt;
                            pixel_we <= 1'b1;
                            pixel_cnt <= pixel_cnt + 1'b1;
                            byte_cnt <= 2'h0;
                        end
                    endcase
                end
                
                WAIT_NEXT: begin
                    sdram_cs_n <= 1'b1;
                    pixel_we <= 1'b0;
                    mem_addr <= mem_addr + (BURST_LEN * 4); // Mỗi đọc 4 byte
                end
                
                FINISH: begin
                    done <= 1'b1;
                    pixel_we <= 1'b0;
                    sdram_cs_n <= 1'b1;
                end
            endcase
        end
    end
    
endmodule

// Module xử lý semantic segmentation (U-Net simplified)
module segmentation_processor #(
    parameter INPUT_WIDTH = 224,
    parameter INPUT_HEIGHT = 224,
    parameter INPUT_CHANNELS = 3,
    parameter NUM_CLASSES = 21
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [7:0] input_buffer [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1],
    output reg [7:0] output_buffer [0:INPUT_WIDTH*INPUT_HEIGHT-1],
    output reg done
);
    // Tham số mạng
    localparam ENCODER_STAGE1_CHANNELS = 64;
    localparam ENCODER_STAGE2_CHANNELS = 128;
    localparam ENCODER_STAGE3_CHANNELS = 256;
    
    // Trạng thái xử lý
    localparam IDLE = 3'd0;
    localparam PREPROCESS = 3'd1;
    localparam ENCODE = 3'd2;
    localparam BOTTLENECK = 3'd3;
    localparam DECODE = 3'd4;
    localparam POSTPROCESS = 3'd5;
    
    reg [2:0] state, next_state;
    
    // Tín hiệu điều khiển
    reg encode_start, bottleneck_start, decode_start;
    wire encode_done, bottleneck_done, decode_done;
    
    // Bộ nhớ feature maps (giữa các lớp)
    reg [15:0] scaled_input [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1];
    reg [15:0] encoder_stage1 [0:INPUT_WIDTH/2*INPUT_HEIGHT/2*ENCODER_STAGE1_CHANNELS-1];
    reg [15:0] encoder_stage2 [0:INPUT_WIDTH/4*INPUT_HEIGHT/4*ENCODER_STAGE2_CHANNELS-1];
    reg [15:0] encoder_stage3 [0:INPUT_WIDTH/8*INPUT_HEIGHT/8*ENCODER_STAGE3_CHANNELS-1];
    reg [15:0] bottleneck [0:INPUT_WIDTH/8*INPUT_HEIGHT/8*ENCODER_STAGE3_CHANNELS-1];
    reg [15:0] decoder_stage1 [0:INPUT_WIDTH/4*INPUT_HEIGHT/4*ENCODER_STAGE2_CHANNELS-1];
    reg [15:0] decoder_stage2 [0:INPUT_WIDTH/2*INPUT_HEIGHT/2*ENCODER_STAGE1_CHANNELS-1];
    reg [15:0] logits [0:INPUT_WIDTH*INPUT_HEIGHT*NUM_CLASSES-1];
    
    // Bộ đếm và trình tự
    reg [31:0] process_counter;
    reg [15:0] class_scores [0:NUM_CLASSES-1];
    reg [7:0] max_class;
    reg [15:0] max_score;
    
    // Máy trạng thái
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Logic trạng thái tiếp theo
    always @(*) begin
        next_state = state;
        encode_start = 1'b0;
        bottleneck_start = 1'b0;
        decode_start = 1'b0;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = PREPROCESS;
            end
            
            PREPROCESS: begin
                next_state = ENCODE;
                encode_start = 1'b1;
            end
            
            ENCODE: begin
                if (encode_done) begin
                    next_state = BOTTLENECK;
                    bottleneck_start = 1'b1;
                end
            end
            
            BOTTLENECK: begin
                if (bottleneck_done) begin
                    next_state = DECODE;
                    decode_start = 1'b1;
                end
            end
            
            DECODE: begin
                if (decode_done)
                    next_state = POSTPROCESS;
            end
            
            POSTPROCESS: begin
                if (process_counter >= INPUT_WIDTH*INPUT_HEIGHT)
                    next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Tiền xử lý ảnh đầu vào (chuẩn hóa)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            process_counter <= 32'h0;
            for (integer i = 0; i < INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS; i = i + 1) begin
                scaled_input[i] <= 16'h0;
            end
        end else if (state == PREPROCESS) begin
            if (process_counter < INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS) begin
                // Chuẩn hóa pixel từ 0-255 sang định dạng fixed-point 8.8
                scaled_input[process_counter] <= {8'h0, input_buffer[process_counter]};
                process_counter <= process_counter + 1;
            end else begin
                process_counter <= 32'h0;
            end
        end else if (state != PREPROCESS) begin
            process_counter <= 32'h0;
        end
    end
    
    // Hậu xử lý (argmax để lấy nhãn lớp)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            process_counter <= 32'h0;
            for (integer i = 0; i < INPUT_WIDTH*INPUT_HEIGHT; i = i + 1) begin
                output_buffer[i] <= 8'h0;
            end
            done <= 1'b0;
        end else if (state == POSTPROCESS) begin
            done <= 1'b0;
            if (process_counter < INPUT_WIDTH*INPUT_HEIGHT) begin
                // Tìm lớp có điểm số cao nhất
                max_score <= 16'h0;
                max_class <= 8'h0;
                
                for (integer c = 0; c < NUM_CLASSES; c = c + 1) begin
                    class_scores[c] <= logits[process_counter*NUM_CLASSES + c];
                    if (logits[process_counter*NUM_CLASSES + c] > max_score) begin
                        max_score <= logits[process_counter*NUM_CLASSES + c];
                        max_class <= c[7:0];
                    end
                end
                
                output_buffer[process_counter] <= max_class;
                process_counter <= process_counter + 1;
            end else begin
                done <= 1'b1;
            end
        end else if (state == IDLE) begin
            process_counter <= 32'h0;
            done <= 1'b0;
        end
    end
    
    // Instantiate CNN modules
    encoder #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INPUT_HEIGHT(INPUT_HEIGHT),
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .STAGE1_CHANNELS(ENCODER_STAGE1_CHANNELS),
        .STAGE2_CHANNELS(ENCODER_STAGE2_CHANNELS),
        .STAGE3_CHANNELS(ENCODER_STAGE3_CHANNELS)
    ) encoder_inst (
        .clk(clk),
        .rst(rst),
        .start(encode_start),
        .input_data(scaled_input),
        .stage1_output(encoder_stage1),
        .stage2_output(encoder_stage2),
        .stage3_output(encoder_stage3),
        .done(encode_done)
    );
    
    bottleneck #(
        .INPUT_WIDTH(INPUT_WIDTH/8),
        .INPUT_HEIGHT(INPUT_HEIGHT/8),
        .CHANNELS(ENCODER_STAGE3_CHANNELS)
    ) bottleneck_inst (
        .clk(clk),
        .rst(rst),
        .start(bottleneck_start),
        .input_data(encoder_stage3),
        .output_data(bottleneck),
        .done(bottleneck_done)
    );
    
    decoder #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INPUT_HEIGHT(INPUT_HEIGHT),
        .STAGE1_CHANNELS(ENCODER_STAGE1_CHANNELS),
        .STAGE2_CHANNELS(ENCODER_STAGE2_CHANNELS),
        .STAGE3_CHANNELS(ENCODER_STAGE3_CHANNELS),
        .NUM_CLASSES(NUM_CLASSES)
    ) decoder_inst (
        .clk(clk),
        .rst(rst),
        .start(decode_start),
        .bottleneck_data(bottleneck),
        .enc_stage1_data(encoder_stage1),
        .enc_stage2_data(encoder_stage2),
        .enc_stage3_data(encoder_stage3),
        .stage1_output(decoder_stage1),
        .stage2_output(decoder_stage2),
        .logits_output(logits),
        .done(decode_done)
    );

endmodule

// Module mã hóa encoder của kiến trúc U-Net
module encoder #(
    parameter INPUT_WIDTH = 224,
    parameter INPUT_HEIGHT = 224,
    parameter INPUT_CHANNELS = 3,
    parameter STAGE1_CHANNELS = 64,
    parameter STAGE2_CHANNELS = 128,
    parameter STAGE3_CHANNELS = 256
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [15:0] input_data [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1],
    output reg [15:0] stage1_output [0:INPUT_WIDTH/2*INPUT_HEIGHT/2*STAGE1_CHANNELS-1],
    output reg [15:0] stage2_output [0:INPUT_WIDTH/4*INPUT_HEIGHT/4*STAGE2_CHANNELS-1],
    output reg [15:0] stage3_output [0:INPUT_WIDTH/8*INPUT_HEIGHT/8*STAGE3_CHANNELS-1],
    output reg done
);
    // Trạng thái xử lý
    localparam IDLE = 3'd0;
    localparam STAGE1 = 3'd1;
    localparam STAGE2 = 3'd2;
    localparam STAGE3 = 3'd3;
    localparam FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Tín hiệu điều khiển cho từng stage
    reg stage1_start, stage2_start, stage3_start;
    wire stage1_done, stage2_done, stage3_done;
    
    // Bộ nhớ tạm
    reg [15:0] stage1_conv [0:INPUT_WIDTH*INPUT_HEIGHT*STAGE1_CHANNELS-1];
    reg [15:0] stage2_conv [0:INPUT_WIDTH/2*INPUT_HEIGHT/2*STAGE2_CHANNELS-1];
    reg [15:0] stage3_conv [0:INPUT_WIDTH/4*INPUT_HEIGHT/4*STAGE3_CHANNELS-1];
    
    // Máy trạng thái
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Logic trạng thái tiếp theo
    always @(*) begin
        next_state = state;
        stage1_start = 1'b0;
        stage2_start = 1'b0;
        stage3_start = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = STAGE1;
                    stage1_start = 1'b1;
                end
            end
            
            STAGE1: begin
                if (stage1_done) begin
                    next_state = STAGE2;
                    stage2_start = 1'b1;
                end
            end
            
            STAGE2: begin
                if (stage2_done) begin
                    next_state = STAGE3;
                    stage3_start = 1'b1;
                end
            end
            
            STAGE3: begin
                if (stage3_done)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Xử lý trạng thái kết thúc
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 1'b0;
        end else if (state == FINISH) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end
    
    // Các thành phần của encoder
    encoder_stage1 #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INPUT_HEIGHT(INPUT_HEIGHT),
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .OUTPUT_CHANNELS(STAGE1_CHANNELS)
    ) stage1_inst (
        .clk(clk),
        .rst(rst),
        .start(stage1_start),
        .input_data(input_data),
        .conv_output(stage1_conv),
        .pool_output(stage1_output),
        .done(stage1_done)
    );
    
    encoder_stage2 #(
        .INPUT_WIDTH(INPUT_WIDTH/2),
        .INPUT_HEIGHT(INPUT_HEIGHT/2),
        .INPUT_CHANNELS(STAGE1_CHANNELS),
        .OUTPUT_CHANNELS(STAGE2_CHANNELS)
    ) stage2_inst (
        .clk(clk),
        .rst(rst),
        .start(stage2_start),
        .input_data(stage1_output),
        .conv_output(stage2_conv),
        .pool_output(stage2_output),
        .done(stage2_done)
    );
    
    encoder_stage3 #(
        .INPUT_WIDTH(INPUT_WIDTH/4),
        .INPUT_HEIGHT(INPUT_HEIGHT/4),
        .INPUT_CHANNELS(STAGE2_CHANNELS),
        .OUTPUT_CHANNELS(STAGE3_CHANNELS)
    ) stage3_inst (
        .clk(clk),
        .rst(rst),
        .start(stage3_start),
        .input_data(stage2_output),
        .conv_output(stage3_conv),
        .pool_output(stage3_output),
        .done(stage3_done)
    );
    
endmodule

// Module bottleneck (lớp giữa encoder và decoder)
module bottleneck #(
    parameter INPUT_WIDTH = 28,
    parameter INPUT_HEIGHT = 28,
    parameter CHANNELS = 256
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [15:0] input_data [0:INPUT_WIDTH*INPUT_HEIGHT*CHANNELS-1],
    output reg [15:0] output_data [0:INPUT_WIDTH*INPUT_HEIGHT*CHANNELS-1],
    output reg done
);
    // Trạng thái xử lý
    localparam IDLE = 2'd0;
    localparam PROCESSING = 2'd1;
    localparam FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [31:0] counter;
    
    // Máy trạng thái
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Logic trạng thái tiếp theo
    always @(*) begin
        next_state = state;
        