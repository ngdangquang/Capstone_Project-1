`timescale 1ns/1ps

module tb_image_loader;
    // Parameters
    parameter IMAGE_WIDTH = 24;  // Smaller size for testing
    parameter IMAGE_HEIGHT = 24;
    parameter CHANNELS = 3;
    
    // Testbench signals
    reg clk;
    reg rst;
    reg start;
    wire [19:0] sdram_addr;
    wire [31:0] sdram_data;
    wire sdram_we_n;
    wire sdram_cs_n;
    wire sdram_ras_n;
    wire sdram_cas_n;
    wire [7:0] pixel_data;
    wire [19:0] pixel_addr;
    wire pixel_we;
    wire done;
    
    // SDRAM model
    reg [31:0] sdram_mem [0:1048575];  // 4MB SDRAM model
    reg [31:0] sdram_data_reg;
    
    // Pixel memory (to store loaded pixels)
    reg [7:0] pixel_mem [0:IMAGE_WIDTH*IMAGE_HEIGHT*CHANNELS-1];
    
    // Bidirectional data bus handling
    assign sdram_data = (sdram_we_n) ? sdram_data_reg : 32'hzzzzzzzz;
    
    // Mock SDRAM response
    always @(posedge clk) begin
        if (!sdram_cs_n && !sdram_ras_n && !sdram_cas_n && sdram_we_n) begin
            // Read operation
            sdram_data_reg <= sdram_mem[sdram_addr];
        end
    end
    
    // Store pixels as they're output by the module
    always @(posedge clk) begin
        if (pixel_we) begin
            pixel_mem[pixel_addr] <= pixel_data;
        end
    end
    
    // DUT instantiation
    image_loader #(
        .IMAGE_WIDTH(IMAGE_WIDTH),
        .IMAGE_HEIGHT(IMAGE_HEIGHT),
        .CHANNELS(CHANNELS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .sdram_addr(sdram_addr),
        .sdram_data(sdram_data),
        .sdram_we_n(sdram_we_n),
        .sdram_cs_n(sdram_cs_n),
        .sdram_ras_n(sdram_ras_n),
        .sdram_cas_n(sdram_cas_n),
        .pixel_data(pixel_data),
        .pixel_addr(pixel_addr),
        .pixel_we(pixel_we),
        .done(done)
    );
    
    // Clock generation (50 MHz)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock (20 ns period)
    end
    
    // Task to check if pixels match the expected pattern
    task check_pixels;
        integer i, pixel_value;
        reg match;
        begin
            match = 1;
            for (i = 0; i < IMAGE_WIDTH*IMAGE_HEIGHT*CHANNELS; i = i + 1) begin
                // Calculate expected pixel value based on SDRAM content
                pixel_value = 8'h00 + ((i/4) & 8'hFF) + ((i%4) * 8'h40);
                
                if (pixel_mem[i] != pixel_value) begin
                    $display("Mismatch at pixel %d: Expected %h, Got %h", 
                             i, pixel_value, pixel_mem[i]);
                    match = 0;
                end
            end
            
            if (match)
                $display("All pixels match expected values!");
        end
    endtask
    
    // Test sequence
    initial begin
        integer i;
        
        // Initialize SDRAM with test pattern
        for (i = 0; i < 20000; i = i + 1) begin
            sdram_mem[i] = {8'h00 + (i & 8'hFF), 8'h40 + (i & 8'hFF), 
                           8'h80 + (i & 8'hFF), 8'hC0 + (i & 8'hFF)};
        end
        
        // Initialize
        rst = 1;
        start = 0;
        
        // Reset release
        #100;
        rst = 0;
        #100;
        
        // Start loading
        $display("Starting image loading at time %t", $time);
        start = 1;
        #20;
        start = 0;
        
        // Wait for loading to complete
        wait(done);
        $display("Image loading completed at time %t", $time);
        
        // Verify pixel data
        #100;
        check_pixels();
        
        // Finish simulation
        #1000;
        $display("Test completed");
        $finish;
    end
    
    // Monitor SDRAM activity
    always @(negedge sdram_cs_n) begin
        $display("Time %t: SDRAM access at address %h", $time, sdram_addr);
    end
    
    // Dump waveform
    initial begin
        $dumpfile("image_loader_tb.vcd");
        $dumpvars(0, tb_image_loader);
    end
    
endmodule 