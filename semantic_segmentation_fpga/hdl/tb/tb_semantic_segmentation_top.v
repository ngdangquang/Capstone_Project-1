`timescale 1ns/1ps

module tb_semantic_segmentation_top;
    // Testbench signals
    reg clk;
    reg reset_n;
    reg start_process;
    wire processing_done;
    
    // Memory interface
    wire [19:0] sdram_addr;
    wire [31:0] sdram_data;
    wire sdram_we_n;
    wire sdram_cs_n;
    wire sdram_ras_n;
    wire sdram_cas_n;
    
    // VGA interface
    wire [7:0] vga_r;
    wire [7:0] vga_g;
    wire [7:0] vga_b;
    wire vga_hsync;
    wire vga_vsync;
    wire vga_blank_n;
    wire vga_sync_n;
    wire vga_clk;
    
    // LED interface
    wire [9:0] leds;
    
    // SDRAM model variables
    reg [31:0] sdram_mem [0:1048575]; // 4MB SDRAM model
    reg [31:0] sdram_data_reg;
    
    // Bidirectional data bus handling
    assign sdram_data = (sdram_we_n) ? sdram_data_reg : 32'hzzzzzzzz;
    
    // Mock SDRAM response
    always @(posedge clk) begin
        if (!sdram_cs_n && !sdram_ras_n && !sdram_cas_n && sdram_we_n) begin
            // Read operation
            sdram_data_reg <= sdram_mem[sdram_addr];
        end
    end
    
    // DUT instantiation
    semantic_segmentation_top dut (
        .clk(clk),
        .reset_n(reset_n),
        .start_process(start_process),
        .processing_done(processing_done),
        .sdram_addr(sdram_addr),
        .sdram_data(sdram_data),
        .sdram_we_n(sdram_we_n),
        .sdram_cs_n(sdram_cs_n),
        .sdram_ras_n(sdram_ras_n),
        .sdram_cas_n(sdram_cas_n),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_blank_n(vga_blank_n),
        .vga_sync_n(vga_sync_n),
        .vga_clk(vga_clk),
        .leds(leds)
    );
    
    // Clock generation (50 MHz)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock (20 ns period)
    end
    
    // Load test image data
    initial begin
        integer i;
        // Initialize SDRAM with test pattern (simple gradient)
        for (i = 0; i < 50176; i = i + 1) begin // 224*224*3/4 = 37632 pixels (in 32-bit words)
            sdram_mem[i] = {8'h00 + (i & 8'hFF), 8'h40 + (i & 8'hFF), 8'h80 + (i & 8'hFF), 8'hC0 + (i & 8'hFF)};
        end
    end
    
    // Test sequence
    initial begin
        // Initialize
        reset_n = 0;
        start_process = 0;
        
        // Apply reset
        #100;
        reset_n = 1;
        #100;
        
        // Start processing
        start_process = 1;
        #20;
        start_process = 0;
        
        // Wait for processing to complete
        wait(processing_done);
        $display("Processing complete at time %t", $time);
        
        // Continue monitoring
        #10000;
        
        $display("Test completed");
        $finish;
    end
    
    // Monitor LED status
    always @(leds) begin
        case(leds[2:0])
            3'd0: $display("Time %t: State = IDLE", $time);
            3'd1: $display("Time %t: State = LOAD_IMAGE", $time);
            3'd2: $display("Time %t: State = PROCESS", $time);
            3'd3: $display("Time %t: State = DISPLAY_RESULT", $time);
            default: $display("Time %t: State = UNKNOWN (%b)", $time, leds[2:0]);
        endcase
        
        if (leds[3]) $display("Time %t: Image loading completed", $time);
        if (leds[4]) $display("Time %t: Processing completed", $time);
        if (leds[5]) $display("Time %t: Display completed", $time);
    end
    
    // Dump waveform (for simulators that support it)
    initial begin
        $dumpfile("semantic_segmentation_top_tb.vcd");
        $dumpvars(0, tb_semantic_segmentation_top);
    end
    
endmodule 