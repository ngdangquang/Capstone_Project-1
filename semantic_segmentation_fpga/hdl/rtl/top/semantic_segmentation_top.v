// Top module for Semantic Segmentation on DE10 Standard Kit
module semantic_segmentation_top (
    input wire clk,
    input wire reset_n,
    // Control interface
    input wire start_process,
    output wire processing_done,
    // Memory interface
    output wire [19:0] sdram_addr,
    inout wire [31:0] sdram_data,
    output wire sdram_we_n,
    output wire sdram_cs_n,
    output wire sdram_ras_n,
    output wire sdram_cas_n,
    // VGA interface
    output wire [7:0] vga_r,
    output wire [7:0] vga_g,
    output wire [7:0] vga_b,
    output wire vga_hsync,
    output wire vga_vsync,
    output wire vga_blank_n,
    output wire vga_sync_n,
    output wire vga_clk,
    // LED interface
    output wire [9:0] leds
);

    // Network parameters
    localparam INPUT_WIDTH = 224;
    localparam INPUT_HEIGHT = 224;
    localparam INPUT_CHANNELS = 3;
    localparam NUM_CLASSES = 21; // For Pascal VOC dataset
    
    // Clock and reset signals
    wire sys_clk;
    wire sys_rst;
    wire vga_pll_clk;
    
    // PLL for system and VGA clocks
    pll system_pll (
        .inclk0(clk),
        .c0(sys_clk),
        .c1(vga_pll_clk)
    );
    
    // Reset synchronization
    reg [2:0] reset_sync;
    always @(posedge sys_clk or negedge reset_n) begin
        if (!reset_n)
            reset_sync <= 3'b111;
        else
            reset_sync <= {reset_sync[1:0], 1'b0};
    end
    assign sys_rst = reset_sync[2];
    
    // User interface - main state machine states
    localparam IDLE = 3'd0;
    localparam LOAD_IMAGE = 3'd1;
    localparam PROCESS = 3'd2;
    localparam DISPLAY_RESULT = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Control signals
    reg start_loading, start_processing, start_display;
    wire loading_done, processing_done_int, display_done;
    
    // Input image memory
    reg [7:0] input_buffer [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1];
    wire [19:0] input_write_addr;
    wire input_write_en;
    wire [7:0] input_pixel_data;
    
    // Result memory
    reg [7:0] output_buffer [0:INPUT_WIDTH*INPUT_HEIGHT-1];
    wire [19:0] output_read_addr;
    wire [7:0] output_pixel_data;
    
    // Main state machine
    always @(posedge sys_clk or posedge sys_rst) begin
        if (sys_rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
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
    
    // Display state on LEDs
    assign leds[2:0] = state;
    assign leds[3] = loading_done;
    assign leds[4] = processing_done_int;
    assign leds[5] = display_done;
    assign leds[9:6] = 4'b0;
    
    // Status signals
    assign processing_done = (state == IDLE);
    
    // Image loading module from SDRAM
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
    
    // Main semantic segmentation processing module
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
    
    // Result display module
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
    
    // Read input data for processing
    always @(posedge sys_clk) begin
        if (input_write_en) begin
            input_buffer[input_write_addr] <= input_pixel_data;
        end
    end

endmodule 