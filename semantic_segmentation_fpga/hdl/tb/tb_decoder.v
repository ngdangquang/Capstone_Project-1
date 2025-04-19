`timescale 1ns/1ps

module tb_decoder;
    // Parameters (reduced size for simulation)
    parameter INPUT_WIDTH = 16;
    parameter INPUT_HEIGHT = 16;
    parameter NUM_CLASSES = 21;
    
    // Testbench signals
    reg clk;
    reg rst;
    reg start;
    wire done;
    
    // Input bottleneck feature map
    reg [15:0] bottleneck_feature_map [0:(INPUT_WIDTH/8)*(INPUT_HEIGHT/8)*256-1];
    
    // Skip connections
    reg [15:0] skip1 [0:(INPUT_WIDTH/2)*(INPUT_HEIGHT/2)*64-1];
    reg [15:0] skip2 [0:(INPUT_WIDTH/4)*(INPUT_HEIGHT/4)*128-1];
    reg [15:0] skip3 [0:(INPUT_WIDTH/8)*(INPUT_HEIGHT/8)*256-1];
    
    // Output feature maps
    wire [15:0] stage1_output [0:(INPUT_WIDTH/4)*(INPUT_HEIGHT/4)*128-1];
    wire [15:0] stage2_output [0:(INPUT_WIDTH/2)*(INPUT_HEIGHT/2)*64-1];
    wire [15:0] stage3_output [0:INPUT_WIDTH*INPUT_HEIGHT*NUM_CLASSES-1];
    
    // DUT instantiation
    decoder #(
        .INPUT_WIDTH(INPUT_WIDTH/8),  // Start from bottleneck size
        .INPUT_HEIGHT(INPUT_HEIGHT/8),
        .NUM_CLASSES(NUM_CLASSES)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .bottleneck_feature_map(bottleneck_feature_map),
        .skip1(skip1),
        .skip2(skip2),
        .skip3(skip3),
        .stage1_output(stage1_output),
        .stage2_output(stage2_output),
        .stage3_output(stage3_output),
        .done(done)
    );
    
    // Clock generation (50 MHz)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock (20 ns period)
    end
    
    // Test sequence
    initial begin
        integer i, j, k, c, idx;
        integer bottleneck_size, stage1_size, stage2_size, stage3_size;
        
        // Calculate sizes
        bottleneck_size = (INPUT_WIDTH/8) * (INPUT_HEIGHT/8) * 256;
        stage1_size = (INPUT_WIDTH/4) * (INPUT_HEIGHT/4) * 128;
        stage2_size = (INPUT_WIDTH/2) * (INPUT_HEIGHT/2) * 64;
        stage3_size = INPUT_WIDTH * INPUT_HEIGHT * NUM_CLASSES;
        
        // Initialize input with a simple pattern
        // Create gradient patterns for bottleneck and skip connections
        for (i = 0; i < bottleneck_size; i = i + 1) begin
            bottleneck_feature_map[i] = 16'h0100 + (i & 16'h00FF);
            skip3[i] = 16'h0200 + (i & 16'h00FF);
        end
        
        for (i = 0; i < stage2_size; i = i + 1) begin
            skip2[i] = 16'h0300 + (i & 16'h00FF);
        end
        
        for (i = 0; i < stage1_size; i = i + 1) begin
            skip1[i] = 16'h0400 + (i & 16'h00FF);
        end
        
        // Initialize test signals
        rst = 1;
        start = 0;
        
        // Apply reset
        #100;
        rst = 0;
        #100;
        
        // Start decoding
        $display("Starting decoder processing at time %t", $time);
        start = 1;
        #20;
        start = 0;
        
        // Wait for decoding to complete
        wait(done);
        $display("Decoder processing completed at time %t", $time);
        
        // Analyze output results
        #100;
        check_output_feature_maps();
        
        // Finish simulation
        #1000;
        $display("Test completed");
        $finish;
    end
    
    // Task to check output feature maps
    task check_output_feature_maps;
        integer i, j, c;
        integer stage1_size, stage2_size, stage3_size;
        real stage1_sum, stage2_sum, stage3_sum;
        real class_sums[0:20]; // For 21 classes
        integer max_class_idx;
        real max_class_val;
        begin
            // Calculate expected sizes
            stage1_size = (INPUT_WIDTH/4) * (INPUT_HEIGHT/4) * 128;
            stage2_size = (INPUT_WIDTH/2) * (INPUT_HEIGHT/2) * 64;
            stage3_size = INPUT_WIDTH * INPUT_HEIGHT * NUM_CLASSES;
            
            // Calculate average values to check for non-zero activation
            stage1_sum = 0;
            stage2_sum = 0;
            stage3_sum = 0;
            
            for (i = 0; i < stage1_size; i = i + 1) begin
                stage1_sum = stage1_sum + $signed(stage1_output[i]);
            end
            
            for (i = 0; i < stage2_size; i = i + 1) begin
                stage2_sum = stage2_sum + $signed(stage2_output[i]);
            end
            
            for (i = 0; i < stage3_size; i = i + 1) begin
                stage3_sum = stage3_sum + $signed(stage3_output[i]);
            end
            
            $display("Stage 1 - Size: %d, Average value: %f", 
                     stage1_size, stage1_sum / stage1_size);
            $display("Stage 2 - Size: %d, Average value: %f", 
                     stage2_size, stage2_sum / stage2_size);
            $display("Stage 3 - Size: %d, Average value: %f", 
                     stage3_size, stage3_sum / stage3_size);
            
            // Check class distribution in final output (stage3)
            for (c = 0; c < NUM_CLASSES; c = c + 1) begin
                class_sums[c] = 0;
                for (i = 0; i < INPUT_HEIGHT; i = i + 1) begin
                    for (j = 0; j < INPUT_WIDTH; j = j + 1) begin
                        class_sums[c] = class_sums[c] + 
                            $signed(stage3_output[(i*INPUT_WIDTH + j)*NUM_CLASSES + c]);
                    end
                end
                $display("Class %d sum: %f", c, class_sums[c]);
            end
            
            // Find class with max activation
            max_class_val = class_sums[0];
            max_class_idx = 0;
            for (c = 1; c < NUM_CLASSES; c = c + 1) begin
                if (class_sums[c] > max_class_val) begin
                    max_class_val = class_sums[c];
                    max_class_idx = c;
                end
            end
            
            $display("Class with highest activation: %d", max_class_idx);
            
            // Check if there's significant activation
            if (stage1_sum != 0 && stage2_sum != 0 && stage3_sum != 0) begin
                $display("PASS: Decoder shows activation through all stages");
            end else begin
                $display("WARNING: One or more decoder stages have zero activation");
            end
        end
    endtask
    
    // Dump waveform
    initial begin
        $dumpfile("decoder_tb.vcd");
        $dumpvars(0, tb_decoder);
    end
    
endmodule 