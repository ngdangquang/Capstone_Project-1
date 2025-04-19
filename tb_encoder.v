`timescale 1ns/1ps

module tb_encoder;
    // Parameters (reduced size for simulation)
    parameter INPUT_WIDTH = 16;
    parameter INPUT_HEIGHT = 16;
    parameter INPUT_CHANNELS = 3;
    
    // Testbench signals
    reg clk;
    reg rst;
    reg start;
    wire done;
    
    // Input and output feature maps
    reg [15:0] input_feature_map [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1];
    wire [15:0] stage1_output [0:(INPUT_WIDTH/2)*(INPUT_HEIGHT/2)*64-1];
    wire [15:0] stage2_output [0:(INPUT_WIDTH/4)*(INPUT_HEIGHT/4)*128-1];
    wire [15:0] stage3_output [0:(INPUT_WIDTH/8)*(INPUT_HEIGHT/8)*256-1];
    
    // Skip connections for later use in decoder
    wire [15:0] skip1 [0:(INPUT_WIDTH/2)*(INPUT_HEIGHT/2)*64-1];
    wire [15:0] skip2 [0:(INPUT_WIDTH/4)*(INPUT_HEIGHT/4)*128-1];
    wire [15:0] skip3 [0:(INPUT_WIDTH/8)*(INPUT_HEIGHT/8)*256-1];
    
    // DUT instantiation
    encoder #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INPUT_HEIGHT(INPUT_HEIGHT),
        .INPUT_CHANNELS(INPUT_CHANNELS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_feature_map(input_feature_map),
        .stage1_output(stage1_output),
        .stage2_output(stage2_output),
        .stage3_output(stage3_output),
        .skip1(skip1),
        .skip2(skip2),
        .skip3(skip3),
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
        
        // Initialize input feature map with a simple pattern
        // Create a pattern that should produce distinct feature maps
        for (i = 0; i < INPUT_HEIGHT; i = i + 1) begin
            for (j = 0; j < INPUT_WIDTH; j = j + 1) begin
                for (k = 0; k < INPUT_CHANNELS; k = k + 1) begin
                    idx = (i * INPUT_WIDTH * INPUT_CHANNELS) + (j * INPUT_CHANNELS) + k;
                    
                    // Different patterns for each channel
                    case (k)
                        0: input_feature_map[idx] = 16'h0100 + ((i*j) & 16'h00FF); // Checkerboard
                        1: input_feature_map[idx] = 16'h0100 + ((i+j) & 16'h00FF); // Diagonal gradient
                        2: input_feature_map[idx] = 16'h0100 + ((i-j) & 16'h00FF); // Inverse gradient
                    endcase
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
        
        // Start encoding
        $display("Starting encoder processing at time %t", $time);
        start = 1;
        #20;
        start = 0;
        
        // Wait for encoding to complete
        wait(done);
        $display("Encoder processing completed at time %t", $time);
        
        // Analyze output results
        #100;
        check_feature_maps();
        
        // Finish simulation
        #1000;
        $display("Test completed");
        $finish;
    end
    
    // Task to check feature maps
    task check_feature_maps;
        integer i, j, c;
        integer stage1_size, stage2_size, stage3_size;
        real stage1_sum, stage2_sum, stage3_sum;
        begin
            // Calculate expected sizes
            stage1_size = (INPUT_WIDTH/2) * (INPUT_HEIGHT/2) * 64;
            stage2_size = (INPUT_WIDTH/4) * (INPUT_HEIGHT/4) * 128;
            stage3_size = (INPUT_WIDTH/8) * (INPUT_HEIGHT/8) * 256;
            
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
            
            // Verify skip connections match the outputs
            for (i = 0; i < stage1_size; i = i + 1) begin
                if (skip1[i] != stage1_output[i]) begin
                    $display("ERROR: Skip1 connection mismatch at index %d", i);
                end
            end
            
            for (i = 0; i < stage2_size; i = i + 1) begin
                if (skip2[i] != stage2_output[i]) begin
                    $display("ERROR: Skip2 connection mismatch at index %d", i);
                end
            end
            
            for (i = 0; i < stage3_size; i = i + 1) begin
                if (skip3[i] != stage3_output[i]) begin
                    $display("ERROR: Skip3 connection mismatch at index %d", i);
                end
            end
            
            $display("Skip connection verification completed");
        end
    endtask
    
    // Dump waveform
    initial begin
        $dumpfile("encoder_tb.vcd");
        $dumpvars(0, tb_encoder);
    end
    
endmodule 