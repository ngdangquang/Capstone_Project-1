`timescale 1ns/1ps

module tb_result_display;
    // Parameters
    parameter IMAGE_WIDTH = 32;  // Smaller size for testing
    parameter IMAGE_HEIGHT = 32;
    
    // Testbench signals
    reg clk;
    reg vga_clk;
    reg rst;
    reg start;
    reg [7:0] output_buffer [0:IMAGE_WIDTH*IMAGE_HEIGHT-1];
    wire [19:0] pixel_addr;
    wire [7:0] pixel_data;
    wire [7:0] vga_r;
    wire [7:0] vga_g;
    wire [7:0] vga_b;
    wire vga_hsync;
    wire vga_vsync;
    wire vga_blank_n;
    wire vga_sync_n;
    wire vga_out_clk;
    wire done;
    
    // DUT instantiation
    result_display #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT)
    ) dut (
        .clk(clk),
        .vga_clk(vga_clk),
        .rst(rst),
        .start(start),
        .output_buffer(output_buffer),
        .pixel_addr(pixel_addr),
        .pixel_data(pixel_data),
        .vga_r(vga_r),
        .vga_g(vga_g),
        .vga_b(vga_b),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_blank_n(vga_blank_n),
        .vga_sync_n(vga_sync_n),
        .vga_clk(vga_out_clk),
        .done(done)
    );
    
    // Assign pixel data based on address request
    assign pixel_data = output_buffer[pixel_addr];
    
    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock (20 ns period)
    end
    
    // VGA clock generation (25 MHz)
    initial begin
        vga_clk = 0;
        forever #20 vga_clk = ~vga_clk; // 25 MHz clock (40 ns period)
    end
    
    // Test sequence
    initial begin
        integer i, j, idx;
        integer frame_count;
        
        // Initialize input data with class IDs (0-20)
        // Create a test pattern with different classes
        for (i = 0; i < IMAGE_HEIGHT; i = i + 1) begin
            for (j = 0; j < IMAGE_WIDTH; j = j + 1) begin
                idx = i * IMAGE_WIDTH + j;
                
                // Create a checkboard pattern of classes
                if ((i/4) % 2 == 0 && (j/4) % 2 == 0)
                    output_buffer[idx] = 1;  // Class 1 (typically roads)
                else if ((i/4) % 2 == 1 && (j/4) % 2 == 1)
                    output_buffer[idx] = 2;  // Class 2 (typically sidewalk)
                else if (i > IMAGE_HEIGHT*3/4)
                    output_buffer[idx] = 3;  // Class 3 (typically building)
                else if (j > IMAGE_WIDTH*3/4)
                    output_buffer[idx] = 7;  // Class 7 (typically car)
                else if (i < IMAGE_HEIGHT/4 && j < IMAGE_WIDTH/4)
                    output_buffer[idx] = 10; // Class 10 (typically sky)
                else
                    output_buffer[idx] = 0;  // Class 0 (background)
            end
        end
        
        // Initialize test signals
        rst = 1;
        start = 0;
        frame_count = 0;
        
        // Apply reset
        #100;
        rst = 0;
        #100;
        
        // Start display
        $display("Starting result display at time %t", $time);
        start = 1;
        #20;
        start = 0;
        
        // Monitor VGA signals for a few frames
        @(posedge vga_vsync); // Wait for first vsync
        $display("First VGA frame starting at time %t", $time);
        frame_count = 1;
        
        repeat (3) begin // Monitor 3 frames
            @(posedge vga_vsync);
            frame_count = frame_count + 1;
            $display("VGA frame %d completed at time %t", frame_count, $time);
        end
        
        // Wait for display completion
        wait(done);
        $display("Display completed at time %t", $time);
        
        // Continue monitoring for a bit
        #10000;
        
        // Finish simulation
        $display("Test completed");
        $finish;
    end
    
    // Monitor VGA timing signals
    initial begin
        integer hsync_count = 0;
        integer vsync_count = 0;
        integer active_pixels = 0;
        
        forever begin
            @(posedge vga_clk);
            
            // Count sync pulses
            if (vga_hsync == 1'b0 && $past(vga_hsync) == 1'b1)
                hsync_count = hsync_count + 1;
                
            if (vga_vsync == 1'b0 && $past(vga_vsync) == 1'b1)
                vsync_count = vsync_count + 1;
                
            // Count active pixels
            if (vga_blank_n == 1'b1)
                active_pixels = active_pixels + 1;
                
            // Periodically display statistics
            if (active_pixels % 10000 == 0 && active_pixels > 0)
                $display("VGA Stats - HSync: %d, VSync: %d, Active Pixels: %d", 
                         hsync_count, vsync_count, active_pixels);
        end
    end
    
    // Monitor color outputs during active display
    always @(posedge vga_clk) begin
        if (vga_blank_n == 1'b1) begin
            // Check if colors are reasonable for the class mapping
            if (vga_r == 8'h00 && vga_g == 8'h00 && vga_b == 8'h00)
                ; // Background is black, no output needed
            else if (^{vga_r, vga_g, vga_b} === 1'bx)
                $display("WARNING: Undefined color output at time %t", $time);
            else if (vga_r > 8'h00 || vga_g > 8'h00 || vga_b > 8'h00)
                ; // Valid non-zero color, no output needed to reduce logs
        end
    end
    
    // Dump waveform
    initial begin
        $dumpfile("result_display_tb.vcd");
        $dumpvars(0, tb_result_display);
    end
    
endmodule 