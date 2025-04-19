// Encoder stage modules for U-Net architecture

// Encoder stage 1 module
module encoder_stage1 #(
    parameter INPUT_WIDTH = 224,
    parameter INPUT_HEIGHT = 224,
    parameter INPUT_CHANNELS = 3,
    parameter OUTPUT_CHANNELS = 64
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [15:0] input_data [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1],
    output reg [15:0] conv_output [0:INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS-1],
    output reg [15:0] pool_output [0:INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS-1],
    output reg done
);
    // Processing states
    localparam IDLE = 3'd0;
    localparam CONV = 3'd1;
    localparam RELU = 3'd2;
    localparam POOL = 3'd3;
    localparam FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [31:0] conv_cnt, relu_cnt, pool_cnt;
    
    // Kernel weights (3x3) - hardcoded for simplicity
    reg signed [7:0] kernel [0:INPUT_CHANNELS-1][0:8][0:OUTPUT_CHANNELS-1];
    reg signed [7:0] bias [0:OUTPUT_CHANNELS-1];
    
    // Initialize random weights (in real implementation, load from memory)
    integer i, j, k;
    initial begin
        for (i = 0; i < INPUT_CHANNELS; i = i + 1) begin
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
                    next_state = CONV;
            end
            
            CONV: begin
                if (conv_cnt >= INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS)
                    next_state = RELU;
            end
            
            RELU: begin
                if (relu_cnt >= INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS)
                    next_state = POOL;
            end
            
            POOL: begin
                if (pool_cnt >= INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Convolution, ReLU and max pooling processing
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_cnt <= 32'h0;
            relu_cnt <= 32'h0;
            pool_cnt <= 32'h0;
            done <= 1'b0;
            
            integer i;
            for (i = 0; i < INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS; i = i + 1) begin
                conv_output[i] <= 16'h0;
            end
            
            for (i = 0; i < INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS; i = i + 1) begin
                pool_output[i] <= 16'h0;
            end
        end else begin
            case (state)
                IDLE: begin
                    conv_cnt <= 32'h0;
                    relu_cnt <= 32'h0;
                    pool_cnt <= 32'h0;
                    done <= 1'b0;
                end
                
                CONV: begin
                    // Simplified convolution processing
                    if (conv_cnt < INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, kh, kw, ic;
                        reg signed [31:0] sum;
                        
                        out_ch = conv_cnt / (INPUT_WIDTH*INPUT_HEIGHT);
                        out_h = (conv_cnt % (INPUT_WIDTH*INPUT_HEIGHT)) / INPUT_WIDTH;
                        out_w = (conv_cnt % (INPUT_WIDTH*INPUT_HEIGHT)) % INPUT_WIDTH;
                        
                        sum = bias[out_ch];  // Bias
                        
                        // Simple 3x3 convolution
                        for (ic = 0; ic < INPUT_CHANNELS; ic = ic + 1) begin
                            for (kh = 0; kh < 3; kh = kh + 1) begin
                                for (kw = 0; kw < 3; kw = kw + 1) begin
                                    integer in_h, in_w, in_pos, kernel_idx;
                                    
                                    in_h = out_h - 1 + kh;
                                    in_w = out_w - 1 + kw;
                                    
                                    if (in_h >= 0 && in_h < INPUT_HEIGHT && in_w >= 0 && in_w < INPUT_WIDTH) begin
                                        in_pos = (in_h * INPUT_WIDTH + in_w) * INPUT_CHANNELS + ic;
                                        kernel_idx = ic * 9 + kh * 3 + kw;
                                        
                                        sum = sum + input_data[in_pos] * kernel[ic][kh*3+kw][out_ch];
                                    end
                                end
                            end
                        end
                        
                        // Scale and store result
                        conv_output[conv_cnt] <= sum[15:0];
                        conv_cnt <= conv_cnt + 1;
                    end
                end
                
                RELU: begin
                    // ReLU activation
                    if (relu_cnt < INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS) begin
                        conv_output[relu_cnt] <= (conv_output[relu_cnt][15]) ? 16'h0 : conv_output[relu_cnt];
                        relu_cnt <= relu_cnt + 1;
                    end
                end
                
                POOL: begin
                    // 2x2 max pooling
                    if (pool_cnt < INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, ph, pw;
                        reg [15:0] max_val;
                        
                        out_ch = pool_cnt / (INPUT_WIDTH/2*INPUT_HEIGHT/2);
                        out_h = (pool_cnt % (INPUT_WIDTH/2*INPUT_HEIGHT/2)) / (INPUT_WIDTH/2);
                        out_w = (pool_cnt % (INPUT_WIDTH/2*INPUT_HEIGHT/2)) % (INPUT_WIDTH/2);
                        
                        max_val = 16'h0;
                        
                        for (ph = 0; ph < 2; ph = ph + 1) begin
                            for (pw = 0; pw < 2; pw = pw + 1) begin
                                integer in_h, in_w, in_pos;
                                
                                in_h = out_h * 2 + ph;
                                in_w = out_w * 2 + pw;
                                in_pos = (in_h * INPUT_WIDTH + in_w) * OUTPUT_CHANNELS + out_ch;
                                
                                if (conv_output[in_pos] > max_val) begin
                                    max_val = conv_output[in_pos];
                                end
                            end
                        end
                        
                        pool_output[pool_cnt] <= max_val;
                        pool_cnt <= pool_cnt + 1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
endmodule

// Encoder stage 2 module
module encoder_stage2 #(
    parameter INPUT_WIDTH = 112,
    parameter INPUT_HEIGHT = 112,
    parameter INPUT_CHANNELS = 64,
    parameter OUTPUT_CHANNELS = 128
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [15:0] input_data [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1],
    output reg [15:0] conv_output [0:INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS-1],
    output reg [15:0] pool_output [0:INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS-1],
    output reg done
);
    // Processing states
    localparam IDLE = 3'd0;
    localparam CONV = 3'd1;
    localparam RELU = 3'd2;
    localparam POOL = 3'd3;
    localparam FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [31:0] conv_cnt, relu_cnt, pool_cnt;
    
    // Kernel weights (3x3) - hardcoded for simplicity
    reg signed [7:0] kernel [0:INPUT_CHANNELS-1][0:8][0:OUTPUT_CHANNELS-1];
    reg signed [7:0] bias [0:OUTPUT_CHANNELS-1];
    
    // Initialize random weights (in real implementation, load from memory)
    integer i, j, k;
    initial begin
        for (i = 0; i < INPUT_CHANNELS; i = i + 1) begin
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
                    next_state = CONV;
            end
            
            CONV: begin
                if (conv_cnt >= INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS)
                    next_state = RELU;
            end
            
            RELU: begin
                if (relu_cnt >= INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS)
                    next_state = POOL;
            end
            
            POOL: begin
                if (pool_cnt >= INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Convolution, ReLU and max pooling processing
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_cnt <= 32'h0;
            relu_cnt <= 32'h0;
            pool_cnt <= 32'h0;
            done <= 1'b0;
            
            integer i;
            for (i = 0; i < INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS; i = i + 1) begin
                conv_output[i] <= 16'h0;
            end
            
            for (i = 0; i < INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS; i = i + 1) begin
                pool_output[i] <= 16'h0;
            end
        end else begin
            case (state)
                IDLE: begin
                    conv_cnt <= 32'h0;
                    relu_cnt <= 32'h0;
                    pool_cnt <= 32'h0;
                    done <= 1'b0;
                end
                
                CONV: begin
                    // Simplified convolution processing
                    if (conv_cnt < INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, kh, kw, ic;
                        reg signed [31:0] sum;
                        
                        out_ch = conv_cnt / (INPUT_WIDTH*INPUT_HEIGHT);
                        out_h = (conv_cnt % (INPUT_WIDTH*INPUT_HEIGHT)) / INPUT_WIDTH;
                        out_w = (conv_cnt % (INPUT_WIDTH*INPUT_HEIGHT)) % INPUT_WIDTH;
                        
                        sum = bias[out_ch];  // Bias
                        
                        // Simple 3x3 convolution
                        for (ic = 0; ic < INPUT_CHANNELS; ic = ic + 1) begin
                            for (kh = 0; kh < 3; kh = kh + 1) begin
                                for (kw = 0; kw < 3; kw = kw + 1) begin
                                    integer in_h, in_w, in_pos, kernel_idx;
                                    
                                    in_h = out_h - 1 + kh;
                                    in_w = out_w - 1 + kw;
                                    
                                    if (in_h >= 0 && in_h < INPUT_HEIGHT && in_w >= 0 && in_w < INPUT_WIDTH) begin
                                        in_pos = (in_h * INPUT_WIDTH + in_w) * INPUT_CHANNELS + ic;
                                        kernel_idx = ic * 9 + kh * 3 + kw;
                                        
                                        sum = sum + input_data[in_pos] * kernel[ic][kh*3+kw][out_ch];
                                    end
                                end
                            end
                        end
                        
                        // Scale and store result
                        conv_output[conv_cnt] <= sum[15:0];
                        conv_cnt <= conv_cnt + 1;
                    end
                end
                
                RELU: begin
                    // ReLU activation
                    if (relu_cnt < INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS) begin
                        conv_output[relu_cnt] <= (conv_output[relu_cnt][15]) ? 16'h0 : conv_output[relu_cnt];
                        relu_cnt <= relu_cnt + 1;
                    end
                end
                
                POOL: begin
                    // 2x2 max pooling
                    if (pool_cnt < INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, ph, pw;
                        reg [15:0] max_val;
                        
                        out_ch = pool_cnt / (INPUT_WIDTH/2*INPUT_HEIGHT/2);
                        out_h = (pool_cnt % (INPUT_WIDTH/2*INPUT_HEIGHT/2)) / (INPUT_WIDTH/2);
                        out_w = (pool_cnt % (INPUT_WIDTH/2*INPUT_HEIGHT/2)) % (INPUT_WIDTH/2);
                        
                        max_val = 16'h0;
                        
                        for (ph = 0; ph < 2; ph = ph + 1) begin
                            for (pw = 0; pw < 2; pw = pw + 1) begin
                                integer in_h, in_w, in_pos;
                                
                                in_h = out_h * 2 + ph;
                                in_w = out_w * 2 + pw;
                                in_pos = (in_h * INPUT_WIDTH + in_w) * OUTPUT_CHANNELS + out_ch;
                                
                                if (conv_output[in_pos] > max_val) begin
                                    max_val = conv_output[in_pos];
                                end
                            end
                        end
                        
                        pool_output[pool_cnt] <= max_val;
                        pool_cnt <= pool_cnt + 1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
endmodule

// Encoder stage 3 module
module encoder_stage3 #(
    parameter INPUT_WIDTH = 56,
    parameter INPUT_HEIGHT = 56,
    parameter INPUT_CHANNELS = 128,
    parameter OUTPUT_CHANNELS = 256
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [15:0] input_data [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1],
    output reg [15:0] conv_output [0:INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS-1],
    output reg [15:0] pool_output [0:INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS-1],
    output reg done
);
    // Processing states
    localparam IDLE = 3'd0;
    localparam CONV = 3'd1;
    localparam RELU = 3'd2;
    localparam POOL = 3'd3;
    localparam FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    reg [31:0] conv_cnt, relu_cnt, pool_cnt;
    
    // Kernel weights (3x3) - hardcoded for simplicity
    reg signed [7:0] kernel [0:INPUT_CHANNELS-1][0:8][0:OUTPUT_CHANNELS-1];
    reg signed [7:0] bias [0:OUTPUT_CHANNELS-1];
    
    // Initialize random weights (in real implementation, load from memory)
    integer i, j, k;
    initial begin
        for (i = 0; i < INPUT_CHANNELS; i = i + 1) begin
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
                    next_state = CONV;
            end
            
            CONV: begin
                if (conv_cnt >= INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS)
                    next_state = RELU;
            end
            
            RELU: begin
                if (relu_cnt >= INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS)
                    next_state = POOL;
            end
            
            POOL: begin
                if (pool_cnt >= INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Convolution, ReLU and max pooling processing
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            conv_cnt <= 32'h0;
            relu_cnt <= 32'h0;
            pool_cnt <= 32'h0;
            done <= 1'b0;
            
            integer i;
            for (i = 0; i < INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS; i = i + 1) begin
                conv_output[i] <= 16'h0;
            end
            
            for (i = 0; i < INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS; i = i + 1) begin
                pool_output[i] <= 16'h0;
            end
        end else begin
            case (state)
                IDLE: begin
                    conv_cnt <= 32'h0;
                    relu_cnt <= 32'h0;
                    pool_cnt <= 32'h0;
                    done <= 1'b0;
                end
                
                CONV: begin
                    // Simplified convolution processing
                    if (conv_cnt < INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, kh, kw, ic;
                        reg signed [31:0] sum;
                        
                        out_ch = conv_cnt / (INPUT_WIDTH*INPUT_HEIGHT);
                        out_h = (conv_cnt % (INPUT_WIDTH*INPUT_HEIGHT)) / INPUT_WIDTH;
                        out_w = (conv_cnt % (INPUT_WIDTH*INPUT_HEIGHT)) % INPUT_WIDTH;
                        
                        sum = bias[out_ch];  // Bias
                        
                        // Simple 3x3 convolution
                        for (ic = 0; ic < INPUT_CHANNELS; ic = ic + 1) begin
                            for (kh = 0; kh < 3; kh = kh + 1) begin
                                for (kw = 0; kw < 3; kw = kw + 1) begin
                                    integer in_h, in_w, in_pos, kernel_idx;
                                    
                                    in_h = out_h - 1 + kh;
                                    in_w = out_w - 1 + kw;
                                    
                                    if (in_h >= 0 && in_h < INPUT_HEIGHT && in_w >= 0 && in_w < INPUT_WIDTH) begin
                                        in_pos = (in_h * INPUT_WIDTH + in_w) * INPUT_CHANNELS + ic;
                                        kernel_idx = ic * 9 + kh * 3 + kw;
                                        
                                        sum = sum + input_data[in_pos] * kernel[ic][kh*3+kw][out_ch];
                                    end
                                end
                            end
                        end
                        
                        // Scale and store result
                        conv_output[conv_cnt] <= sum[15:0];
                        conv_cnt <= conv_cnt + 1;
                    end
                end
                
                RELU: begin
                    // ReLU activation
                    if (relu_cnt < INPUT_WIDTH*INPUT_HEIGHT*OUTPUT_CHANNELS) begin
                        conv_output[relu_cnt] <= (conv_output[relu_cnt][15]) ? 16'h0 : conv_output[relu_cnt];
                        relu_cnt <= relu_cnt + 1;
                    end
                end
                
                POOL: begin
                    // 2x2 max pooling
                    if (pool_cnt < INPUT_WIDTH/2*INPUT_HEIGHT/2*OUTPUT_CHANNELS) begin
                        integer out_ch, out_h, out_w, ph, pw;
                        reg [15:0] max_val;
                        
                        out_ch = pool_cnt / (INPUT_WIDTH/2*INPUT_HEIGHT/2);
                        out_h = (pool_cnt % (INPUT_WIDTH/2*INPUT_HEIGHT/2)) / (INPUT_WIDTH/2);
                        out_w = (pool_cnt % (INPUT_WIDTH/2*INPUT_HEIGHT/2)) % (INPUT_WIDTH/2);
                        
                        max_val = 16'h0;
                        
                        for (ph = 0; ph < 2; ph = ph + 1) begin
                            for (pw = 0; pw < 2; pw = pw + 1) begin
                                integer in_h, in_w, in_pos;
                                
                                in_h = out_h * 2 + ph;
                                in_w = out_w * 2 + pw;
                                in_pos = (in_h * INPUT_WIDTH + in_w) * OUTPUT_CHANNELS + out_ch;
                                
                                if (conv_output[in_pos] > max_val) begin
                                    max_val = conv_output[in_pos];
                                end
                            end
                        end
                        
                        pool_output[pool_cnt] <= max_val;
                        pool_cnt <= pool_cnt + 1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
endmodule 