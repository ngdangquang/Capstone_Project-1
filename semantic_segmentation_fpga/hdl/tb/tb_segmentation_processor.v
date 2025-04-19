`timescale 1ns/1ps

module tb_segmentation_processor;
    // Parameters for testing (small image for faster simulation)
    parameter INPUT_WIDTH = 16;
    parameter INPUT_HEIGHT = 16;
    parameter INPUT_CHANNELS = 3;
    parameter NUM_CLASSES = 21;
    
    // Testbench signals
    reg clk;
    reg rst;
    reg start;
    wire done;
    
    // Image buffers
    reg [7:0] input_buffer [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1];
    reg [7:0] output_buffer [0:INPUT_WIDTH*INPUT_HEIGHT-1];
    
    // DUT instantiation
    segmentation_processor #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INPUT_HEIGHT(INPUT_HEIGHT),
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .NUM_CLASSES(NUM_CLASSES)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_buffer(input_buffer),
        .output_buffer(output_buffer),
        .done(done)
    );
    
    // Clock generation (50 MHz)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock (20 ns period)
    end
    
    // Test sequence
    initial begin
        integer i, j, k, idx;
        
        // Initialize input with a simple pattern
        // Create a pattern that should be recognizable after processing
        // In the center, create a square that should be classified as class 1
        for (i = 0; i < INPUT_HEIGHT; i = i + 1) begin
            for (j = 0; j < INPUT_WIDTH; j = j + 1) begin
                for (k = 0; k < INPUT_CHANNELS; k = k + 1) begin
                    idx = (i * INPUT_WIDTH * INPUT_CHANNELS) + (j * INPUT_CHANNELS) + k;
                    
                    // Create a centered square pattern with high values
                    if (i >= INPUT_HEIGHT/4 && i < INPUT_HEIGHT*3/4 && 
                        j >= INPUT_WIDTH/4 && j < INPUT_WIDTH*3/4) begin
                        // Center square: high value in first channel
                        if (k == 0) input_buffer[idx] = 8'hFF;
                        else input_buffer[idx] = 8'h40;
                    end else begin
                        // Rest of image: lower values
                        input_buffer[idx] = 8'h20 + ((i+j) & 8'h1F);
                    end
                end
            end
        end
        
        // Initialize test signals
        rst = 1;
        start = 0;
        
        // Apply reset
        #100;
        rst = 0;
        #100;
        
        // Start processing
        $display("Starting segmentation processing at time %t", $time);
        start = 1;
        #20;
        start = 0;
        
        // Wait for processing to complete
        wait(done);
        $display("Segmentation processing completed at time %t", $time);
        
        // Analyze output results
        #100;
        $display("Output segmentation map:");
        for (i = 0; i < INPUT_HEIGHT; i = i + 1) begin
            for (j = 0; j < INPUT_WIDTH; j = j + 1) begin
                $write("%2d ", output_buffer[i*INPUT_WIDTH + j]);
            end
            $write("\n");
        end
        
        // Check for at least some class differentiation in the results
        check_segmentation_results();
        
        // Finish simulation
        #1000;
        $display("Test completed");
        $finish;
    end
    
    // Task to check if segmentation results show some differentiation
    task check_segmentation_results;
        integer i, j, center_class, edge_class, center_count, edge_count;
        begin
            center_class = -1;
            edge_class = -1;
            center_count = 0;
            edge_count = 0;
            
            // Check center region
            for (i = INPUT_HEIGHT/4; i < INPUT_HEIGHT*3/4; i = i + 1) begin
                for (j = INPUT_WIDTH/4; j < INPUT_WIDTH*3/4; j = j + 1) begin
                    if (center_class == -1) begin
                        center_class = output_buffer[i*INPUT_WIDTH + j];
                    end
                    
                    if (output_buffer[i*INPUT_WIDTH + j] == center_class) begin
                        center_count = center_count + 1;
                    end
                end
            end
            
            // Check edge regions
            for (i = 0; i < INPUT_HEIGHT; i = i + 1) begin
                for (j = 0; j < INPUT_WIDTH; j = j + 1) begin
                    if (i < INPUT_HEIGHT/4 || i >= INPUT_HEIGHT*3/4 || 
                        j < INPUT_WIDTH/4 || j >= INPUT_WIDTH*3/4) begin
                        if (edge_class == -1) begin
                            edge_class = output_buffer[i*INPUT_WIDTH + j];
                        end
                        
                        if (output_buffer[i*INPUT_WIDTH + j] == edge_class) begin
                            edge_count = edge_count + 1;
                        end
                    end
                end
            end
            
            $display("Center region class: %d (count: %d)", center_class, center_count);
            $display("Edge region class: %d (count: %d)", edge_class, edge_count);
            
            if (center_class != edge_class && center_count > 0 && edge_count > 0) begin
                $display("PASS: Segmentation shows differentiation between regions");
            end else begin
                $display("WARNING: Segmentation does not show clear differentiation");
            end
        end
    endtask
    
    // Dump waveform
    initial begin
        $dumpfile("segmentation_processor_tb.vcd");
        $dumpvars(0, tb_segmentation_processor);
    end
    
endmodule 