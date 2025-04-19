// Decoder stage modules for U-Net architecture

// Decoder stage 1 module
module decoder_stage1 #(
    parameter INPUT_WIDTH = 28,
    parameter INPUT_HEIGHT = 28,
    parameter INPUT_CHANNELS = 256,
    parameter SKIP_CHANNELS = 256,
    parameter OUTPUT_CHANNELS = 128
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [15:0] input_data [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1],
    input wire [15:0] skip_data [0:INPUT_WIDTH*INPUT_HEIGHT*SKIP_CHANNELS-1],
    output reg [15:0] upsample_output [0:INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS-1],
    output reg [15:0] stage_output [0:INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS-1],
    output reg done
);
    // Processing states
    localparam IDLE = 3'd0;
    localparam UPSAMPLE = 3'd1;
    localparam CONCAT = 3'd2;
    localparam CONV = 3'd3;
    localparam FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [31:0] upsample_cnt, concat_cnt, conv_cnt;
    
    // Temporary memory for concatenated feature maps
    reg [15:0] concat_data [0:INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS)-1];
    
    // Kernel weights (3x3) - hardcoded for simplicity
    reg signed [7:0] kernel [0:(INPUT_CHANNELS+SKIP_CHANNELS)-1][0:8][0:OUTPUT_CHANNELS-1];
    reg signed [7:0] bias [0:OUTPUT_CHANNELS-1];
    
    // Initialize random weights (in real implementation, load from memory)
    integer i, j, k;
    initial begin
        for (i = 0; i < (INPUT_CHANNELS+SKIP_CHANNELS); i = i + 1) begin
            for (j = 0; j < 9; j = j + 1) begin
                for (k = 0; k < OUTPUT_CHANNELS; k = k + 1) begin
                    kernel[i][j][k] = $random % 256;  // -128 to 127
                end
            end
        end
        
        for (k = 0; k < OUTPUT_CHANNELS; k = k + 1) begin
            bias[k] = $random % 256;  // -128 to 127
        end
    end
    
    // State machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = UPSAMPLE;
            end
            
            UPSAMPLE: begin
                if (upsample_cnt >= INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS)
                    next_state = CONCAT;
            end
            
            CONCAT: begin
                if (concat_cnt >= INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS))
                    next_state = CONV;
            end
            
            CONV: begin
                if (conv_cnt >= INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Upsampling, concatenation and convolution processing
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            upsample_cnt <= 32'h0;
            concat_cnt <= 32'h0;
            conv_cnt <= 32'h0;
            done <= 1'b0;
            
            integer i;
            for (i = 0; i < INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS; i = i + 1) begin
                upsample_output[i] <= 16'h0;
            end
            
            for (i = 0; i < INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS); i = i + 1) begin
                concat_data[i] <= 16'h0;
            end
            
            for (i = 0; i < INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS; i = i + 1) begin
                stage_output[i] <= 16'h0;
            end
        end else begin
            case (state)
                IDLE: begin
                    upsample_cnt <= 32'h0;
                    concat_cnt <= 32'h0;
                    conv_cnt <= 32'h0;
                    done <= 1'b0;
                end
                
                UPSAMPLE: begin
                    // Nearest neighbor upsampling
                    if (upsample_cnt < INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, in_h, in_w, in_pos;
                        
                        out_ch = upsample_cnt / (INPUT_WIDTH*2*INPUT_HEIGHT*2);
                        out_h = (upsample_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) / (INPUT_WIDTH*2);
                        out_w = (upsample_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) % (INPUT_WIDTH*2);
                        
                        in_h = out_h / 2;
                        in_w = out_w / 2;
                        in_pos = (in_h * INPUT_WIDTH + in_w) * INPUT_CHANNELS + out_ch;
                        
                        upsample_output[upsample_cnt] <= input_data[in_pos];
                        upsample_cnt <= upsample_cnt + 1;
                    end
                end
                
                CONCAT: begin
                    // Concatenate upsampled feature maps with skip connection
                    if (concat_cnt < INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS)) begin
                        integer pos_h, pos_w, pos_ch;
                        
                        pos_ch = concat_cnt / (INPUT_WIDTH*2*INPUT_HEIGHT*2);
                        pos_h = (concat_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) / (INPUT_WIDTH*2);
                        pos_w = (concat_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) % (INPUT_WIDTH*2);
                        
                        if (pos_ch < INPUT_CHANNELS) begin
                            // Copy from upsampled data
                            concat_data[concat_cnt] <= upsample_output[(pos_h * INPUT_WIDTH*2 + pos_w) * INPUT_CHANNELS + pos_ch];
                        end else begin
                            // Copy from skip connection
                            concat_data[concat_cnt] <= skip_data[(pos_h * INPUT_WIDTH*2 + pos_w) * SKIP_CHANNELS + (pos_ch - INPUT_CHANNELS)];
                        end
                        
                        concat_cnt <= concat_cnt + 1;
                    end
                end
                
                CONV: begin
                    // Convolution on concatenated feature maps
                    if (conv_cnt < INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, kh, kw, ic;
                        reg signed [31:0] sum;
                        
                        out_ch = conv_cnt / (INPUT_WIDTH*2*INPUT_HEIGHT*2);
                        out_h = (conv_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) / (INPUT_WIDTH*2);
                        out_w = (conv_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) % (INPUT_WIDTH*2);
                        
                        sum = bias[out_ch];  // Bias
                        
                        // Simple 3x3 convolution
                        for (ic = 0; ic < (INPUT_CHANNELS+SKIP_CHANNELS); ic = ic + 1) begin
                            for (kh = 0; kh < 3; kh = kh + 1) begin
                                for (kw = 0; kw < 3; kw = kw + 1) begin
                                    integer in_h, in_w, in_pos, kernel_idx;
                                    
                                    in_h = out_h - 1 + kh;
                                    in_w = out_w - 1 + kw;
                                    
                                    if (in_h >= 0 && in_h < INPUT_HEIGHT*2 && in_w >= 0 && in_w < INPUT_WIDTH*2) begin
                                        in_pos = (in_h * INPUT_WIDTH*2 + in_w) * (INPUT_CHANNELS+SKIP_CHANNELS) + ic;
                                        kernel_idx = ic * 9 + kh * 3 + kw;
                                        
                                        sum = sum + concat_data[in_pos] * kernel[ic][kh*3+kw][out_ch];
                                    end
                                end
                            end
                        end
                        
                        // Scale, ReLU and store result
                        stage_output[conv_cnt] <= (sum[31]) ? 16'h0 : sum[15:0]; // ReLU
                        conv_cnt <= conv_cnt + 1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
endmodule

// Decoder stage 2 & 3 have similar structure, so just defining one generic module
// Decoder stage 2 module
module decoder_stage2 #(
    parameter INPUT_WIDTH = 56,
    parameter INPUT_HEIGHT = 56,
    parameter INPUT_CHANNELS = 128,
    parameter SKIP_CHANNELS = 128,
    parameter OUTPUT_CHANNELS = 64
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [15:0] input_data [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1],
    input wire [15:0] skip_data [0:INPUT_WIDTH*INPUT_HEIGHT*SKIP_CHANNELS-1],
    output reg [15:0] upsample_output [0:INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS-1],
    output reg [15:0] stage_output [0:INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS-1],
    output reg done
);
    // Processing states
    localparam IDLE = 3'd0;
    localparam UPSAMPLE = 3'd1;
    localparam CONCAT = 3'd2;
    localparam CONV = 3'd3;
    localparam FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [31:0] upsample_cnt, concat_cnt, conv_cnt;
    
    // Temporary memory for concatenated feature maps
    reg [15:0] concat_data [0:INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS)-1];
    
    // Kernel weights (3x3) - hardcoded for simplicity
    reg signed [7:0] kernel [0:(INPUT_CHANNELS+SKIP_CHANNELS)-1][0:8][0:OUTPUT_CHANNELS-1];
    reg signed [7:0] bias [0:OUTPUT_CHANNELS-1];
    
    // Initialize random weights (in real implementation, load from memory)
    integer i, j, k;
    initial begin
        for (i = 0; i < (INPUT_CHANNELS+SKIP_CHANNELS); i = i + 1) begin
            for (j = 0; j < 9; j = j + 1) begin
                for (k = 0; k < OUTPUT_CHANNELS; k = k + 1) begin
                    kernel[i][j][k] = $random % 256;  // -128 to 127
                end
            end
        end
        
        for (k = 0; k < OUTPUT_CHANNELS; k = k + 1) begin
            bias[k] = $random % 256;  // -128 to 127
        end
    end
    
    // State machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = UPSAMPLE;
            end
            
            UPSAMPLE: begin
                if (upsample_cnt >= INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS)
                    next_state = CONCAT;
            end
            
            CONCAT: begin
                if (concat_cnt >= INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS))
                    next_state = CONV;
            end
            
            CONV: begin
                if (conv_cnt >= INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Upsampling, concatenation and convolution processing
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            upsample_cnt <= 32'h0;
            concat_cnt <= 32'h0;
            conv_cnt <= 32'h0;
            done <= 1'b0;
            
            integer i;
            for (i = 0; i < INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS; i = i + 1) begin
                upsample_output[i] <= 16'h0;
            end
            
            for (i = 0; i < INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS); i = i + 1) begin
                concat_data[i] <= 16'h0;
            end
            
            for (i = 0; i < INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS; i = i + 1) begin
                stage_output[i] <= 16'h0;
            end
        end else begin
            case (state)
                IDLE: begin
                    upsample_cnt <= 32'h0;
                    concat_cnt <= 32'h0;
                    conv_cnt <= 32'h0;
                    done <= 1'b0;
                end
                
                UPSAMPLE: begin
                    // Nearest neighbor upsampling
                    if (upsample_cnt < INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, in_h, in_w, in_pos;
                        
                        out_ch = upsample_cnt / (INPUT_WIDTH*2*INPUT_HEIGHT*2);
                        out_h = (upsample_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) / (INPUT_WIDTH*2);
                        out_w = (upsample_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) % (INPUT_WIDTH*2);
                        
                        in_h = out_h / 2;
                        in_w = out_w / 2;
                        in_pos = (in_h * INPUT_WIDTH + in_w) * INPUT_CHANNELS + out_ch;
                        
                        upsample_output[upsample_cnt] <= input_data[in_pos];
                        upsample_cnt <= upsample_cnt + 1;
                    end
                end
                
                CONCAT: begin
                    // Concatenate upsampled feature maps with skip connection
                    if (concat_cnt < INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS)) begin
                        integer pos_h, pos_w, pos_ch;
                        
                        pos_ch = concat_cnt / (INPUT_WIDTH*2*INPUT_HEIGHT*2);
                        pos_h = (concat_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) / (INPUT_WIDTH*2);
                        pos_w = (concat_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) % (INPUT_WIDTH*2);
                        
                        if (pos_ch < INPUT_CHANNELS) begin
                            // Copy from upsampled data
                            concat_data[concat_cnt] <= upsample_output[(pos_h * INPUT_WIDTH*2 + pos_w) * INPUT_CHANNELS + pos_ch];
                        end else begin
                            // Copy from skip connection
                            concat_data[concat_cnt] <= skip_data[(pos_h * INPUT_WIDTH*2 + pos_w) * SKIP_CHANNELS + (pos_ch - INPUT_CHANNELS)];
                        end
                        
                        concat_cnt <= concat_cnt + 1;
                    end
                end
                
                CONV: begin
                    // Convolution on concatenated feature maps
                    if (conv_cnt < INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, kh, kw, ic;
                        reg signed [31:0] sum;
                        
                        out_ch = conv_cnt / (INPUT_WIDTH*2*INPUT_HEIGHT*2);
                        out_h = (conv_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) / (INPUT_WIDTH*2);
                        out_w = (conv_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) % (INPUT_WIDTH*2);
                        
                        sum = bias[out_ch];  // Bias
                        
                        // Simple 3x3 convolution
                        for (ic = 0; ic < (INPUT_CHANNELS+SKIP_CHANNELS); ic = ic + 1) begin
                            for (kh = 0; kh < 3; kh = kh + 1) begin
                                for (kw = 0; kw < 3; kw = kw + 1) begin
                                    integer in_h, in_w, in_pos, kernel_idx;
                                    
                                    in_h = out_h - 1 + kh;
                                    in_w = out_w - 1 + kw;
                                    
                                    if (in_h >= 0 && in_h < INPUT_HEIGHT*2 && in_w >= 0 && in_w < INPUT_WIDTH*2) begin
                                        in_pos = (in_h * INPUT_WIDTH*2 + in_w) * (INPUT_CHANNELS+SKIP_CHANNELS) + ic;
                                        kernel_idx = ic * 9 + kh * 3 + kw;
                                        
                                        sum = sum + concat_data[in_pos] * kernel[ic][kh*3+kw][out_ch];
                                    end
                                end
                            end
                        end
                        
                        // Scale, ReLU and store result
                        stage_output[conv_cnt] <= (sum[31]) ? 16'h0 : sum[15:0]; // ReLU
                        conv_cnt <= conv_cnt + 1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
endmodule

// Final decoder stage with output to classes
module decoder_stage3 #(
    parameter INPUT_WIDTH = 112,
    parameter INPUT_HEIGHT = 112,
    parameter INPUT_CHANNELS = 64,
    parameter SKIP_CHANNELS = 64,
    parameter OUTPUT_CHANNELS = 21  // Number of classes
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [15:0] input_data [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1],
    input wire [15:0] skip_data [0:INPUT_WIDTH*INPUT_HEIGHT*SKIP_CHANNELS-1],
    output reg [15:0] upsample_output [0:INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS-1],
    output reg [15:0] logits_output [0:INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS-1],
    output reg done
);
    // Processing states
    localparam IDLE = 3'd0;
    localparam UPSAMPLE = 3'd1;
    localparam CONCAT = 3'd2;
    localparam CONV = 3'd3;
    localparam FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [31:0] upsample_cnt, concat_cnt, conv_cnt;
    
    // Temporary memory for concatenated feature maps
    reg [15:0] concat_data [0:INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS)-1];
    
    // Kernel weights (3x3) - hardcoded for simplicity
    reg signed [7:0] kernel [0:(INPUT_CHANNELS+SKIP_CHANNELS)-1][0:8][0:OUTPUT_CHANNELS-1];
    reg signed [7:0] bias [0:OUTPUT_CHANNELS-1];
    
    // Initialize random weights (in real implementation, load from memory)
    integer i, j, k;
    initial begin
        for (i = 0; i < (INPUT_CHANNELS+SKIP_CHANNELS); i = i + 1) begin
            for (j = 0; j < 9; j = j + 1) begin
                for (k = 0; k < OUTPUT_CHANNELS; k = k + 1) begin
                    kernel[i][j][k] = $random % 256;  // -128 to 127
                end
            end
        end
        
        for (k = 0; k < OUTPUT_CHANNELS; k = k + 1) begin
            bias[k] = $random % 256;  // -128 to 127
        end
    end
    
    // State machine
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = UPSAMPLE;
            end
            
            UPSAMPLE: begin
                if (upsample_cnt >= INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS)
                    next_state = CONCAT;
            end
            
            CONCAT: begin
                if (concat_cnt >= INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS))
                    next_state = CONV;
            end
            
            CONV: begin
                if (conv_cnt >= INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Upsampling, concatenation and final 1x1 convolution
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            upsample_cnt <= 32'h0;
            concat_cnt <= 32'h0;
            conv_cnt <= 32'h0;
            done <= 1'b0;
            
            integer i;
            for (i = 0; i < INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS; i = i + 1) begin
                upsample_output[i] <= 16'h0;
            end
            
            for (i = 0; i < INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS); i = i + 1) begin
                concat_data[i] <= 16'h0;
            end
            
            for (i = 0; i < INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS; i = i + 1) begin
                logits_output[i] <= 16'h0;
            end
        end else begin
            case (state)
                IDLE: begin
                    upsample_cnt <= 32'h0;
                    concat_cnt <= 32'h0;
                    conv_cnt <= 32'h0;
                    done <= 1'b0;
                end
                
                UPSAMPLE: begin
                    // Nearest neighbor upsampling
                    if (upsample_cnt < INPUT_WIDTH*2*INPUT_HEIGHT*2*INPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, in_h, in_w, in_pos;
                        
                        out_ch = upsample_cnt / (INPUT_WIDTH*2*INPUT_HEIGHT*2);
                        out_h = (upsample_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) / (INPUT_WIDTH*2);
                        out_w = (upsample_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) % (INPUT_WIDTH*2);
                        
                        in_h = out_h / 2;
                        in_w = out_w / 2;
                        in_pos = (in_h * INPUT_WIDTH + in_w) * INPUT_CHANNELS + out_ch;
                        
                        upsample_output[upsample_cnt] <= input_data[in_pos];
                        upsample_cnt <= upsample_cnt + 1;
                    end
                end
                
                CONCAT: begin
                    // Concatenate upsampled feature maps with skip connection
                    if (concat_cnt < INPUT_WIDTH*2*INPUT_HEIGHT*2*(INPUT_CHANNELS+SKIP_CHANNELS)) begin
                        integer pos_h, pos_w, pos_ch;
                        
                        pos_ch = concat_cnt / (INPUT_WIDTH*2*INPUT_HEIGHT*2);
                        pos_h = (concat_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) / (INPUT_WIDTH*2);
                        pos_w = (concat_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) % (INPUT_WIDTH*2);
                        
                        if (pos_ch < INPUT_CHANNELS) begin
                            // Copy from upsampled data
                            concat_data[concat_cnt] <= upsample_output[(pos_h * INPUT_WIDTH*2 + pos_w) * INPUT_CHANNELS + pos_ch];
                        end else begin
                            // Copy from skip connection
                            concat_data[concat_cnt] <= skip_data[(pos_h * INPUT_WIDTH*2 + pos_w) * SKIP_CHANNELS + (pos_ch - INPUT_CHANNELS)];
                        end
                        
                        concat_cnt <= concat_cnt + 1;
                    end
                end
                
                CONV: begin
                    // Final 1x1 convolution to produce logits for each class
                    if (conv_cnt < INPUT_WIDTH*2*INPUT_HEIGHT*2*OUTPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, ic;
                        reg signed [31:0] sum;
                        
                        out_ch = conv_cnt / (INPUT_WIDTH*2*INPUT_HEIGHT*2);
                        out_h = (conv_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) / (INPUT_WIDTH*2);
                        out_w = (conv_cnt % (INPUT_WIDTH*2*INPUT_HEIGHT*2)) % (INPUT_WIDTH*2);
                        
                        sum = bias[out_ch];  // Bias
                        
                        // 1x1 convolution
                        for (ic = 0; ic < (INPUT_CHANNELS+SKIP_CHANNELS); ic = ic + 1) begin
                            integer in_pos;
                            in_pos = (out_h * INPUT_WIDTH*2 + out_w) * (INPUT_CHANNELS+SKIP_CHANNELS) + ic;
                            
                            // Simplified 1x1 conv - just multiply by a weight per channel
                            sum = sum + concat_data[in_pos] * kernel[ic][0][out_ch];
                        end
                        
                        // Store result (no activation for logits)
                        logits_output[conv_cnt] <= sum[15:0];
                        conv_cnt <= conv_cnt + 1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
endmodule 