`timescale 1ns/1ps

module tb_bottleneck;
    // Parameters (reduced size for simulation)
    parameter FEATURE_WIDTH = 8;
    parameter FEATURE_HEIGHT = 8;
    parameter CHANNELS = 256;
    
    // Testbench signals
    reg clk;
    reg rst;
    reg start;
    wire done;
    
    // Input feature map (output from last encoder stage)
    reg [15:0] input_feature_map [0:FEATURE_WIDTH*FEATURE_HEIGHT*CHANNELS-1];
    
    // Output feature map
    wire [15:0] output_feature_map [0:FEATURE_WIDTH*FEATURE_HEIGHT*CHANNELS-1];
    
    // DUT instantiation
    bottleneck #(
        .FEATURE_WIDTH(FEATURE_WIDTH),
        .FEATURE_HEIGHT(FEATURE_HEIGHT),
        .CHANNELS(CHANNELS)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .input_feature_map(input_feature_map),
        .output_feature_map(output_feature_map),
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
        integer feature_size;
        
        // Calculate feature map size
        feature_size = FEATURE_WIDTH * FEATURE_HEIGHT * CHANNELS;
        
        // Initialize input feature map with various patterns
        // Create both positive and negative values to test ReLU
        for (i = 0; i < FEATURE_HEIGHT; i = i + 1) begin
            for (j = 0; j < FEATURE_WIDTH; j = j + 1) begin
                for (k = 0; k < CHANNELS; k = k + 1) begin
                    idx = (i * FEATURE_WIDTH * CHANNELS) + (j * CHANNELS) + k;
                    
                    // Generate varying positive and negative values
                    if ((i+j) % 3 == 0) begin
                        // Negative value (should become 0 after ReLU)
                        input_feature_map[idx] = 16'hF000 | (16'h00FF & (i*j));
                    end else begin
                        // Positive value (should remain unchanged after ReLU)
                        input_feature_map[idx] = 16'h0100 + ((i*j) & 16'h00FF);
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
        
        // Start bottleneck processing
        $display("Starting bottleneck processing at time %t", $time);
        start = 1;
        #20;
        start = 0;
        
        // Wait for processing to complete
        wait(done);
        $display("Bottleneck processing completed at time %t", $time);
        
        // Analyze output results
        #100;
        check_relu_activation();
        
        // Finish simulation
        #1000;
        $display("Test completed");
        $finish;
    end
    
    // Task to verify ReLU activation
    task check_relu_activation;
        integer i;
        integer feature_size;
        integer negative_inputs, zero_outputs, passed_inputs;
        real sum_in, sum_out;
        begin
            feature_size = FEATURE_WIDTH * FEATURE_HEIGHT * CHANNELS;
            negative_inputs = 0;
            zero_outputs = 0;
            passed_inputs = 0;
            sum_in = 0;
            sum_out = 0;
            
            for (i = 0; i < feature_size; i = i + 1) begin
                // Count statistics on ReLU behavior
                sum_in = sum_in + $signed(input_feature_map[i]);
                sum_out = sum_out + $signed(output_feature_map[i]);
                
                if ($signed(input_feature_map[i]) < 0) begin
                    negative_inputs = negative_inputs + 1;
                    if (output_feature_map[i] != 0) begin
                        $display("ERROR: Negative input didn't result in zero output at index %d", i);
                        $display("       Input: %h, Output: %h", input_feature_map[i], output_feature_map[i]);
                    end
                end
                
                if (output_feature_map[i] == 0) begin
                    zero_outputs = zero_outputs + 1;
                end
                
                if ($signed(input_feature_map[i]) >= 0) begin
                    passed_inputs = passed_inputs + 1;
                    if (output_feature_map[i] != input_feature_map[i]) begin
                        $display("ERROR: Positive input changed at index %d", i);
                        $display("       Input: %h, Output: %h", input_feature_map[i], output_feature_map[i]);
                    end
                end
            end
            
            $display("Feature map size: %d", feature_size);
            $display("Negative inputs: %d", negative_inputs);
            $display("Zero outputs: %d", zero_outputs);
            $display("Passed through inputs: %d", passed_inputs);
            $display("Sum of inputs: %f", sum_in);
            $display("Sum of outputs: %f", sum_out);
            
            // Verify basic ReLU behavior
            if (negative_inputs == zero_outputs && sum_out >= 0) begin
                $display("PASS: ReLU activation is functioning correctly");
            end else begin
                $display("WARNING: ReLU behavior is not as expected");
            end
        end
    endtask
    
    // Dump waveform
    initial begin
        $dumpfile("bottleneck_tb.vcd");
        $dumpvars(0, tb_bottleneck);
    end
    
endmodule 