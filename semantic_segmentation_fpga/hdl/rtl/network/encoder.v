// Encoder module for U-Net architecture
module encoder #(
    parameter INPUT_WIDTH = 224,
    parameter INPUT_HEIGHT = 224,
    parameter INPUT_CHANNELS = 3,
    parameter STAGE1_CHANNELS = 64,
    parameter STAGE2_CHANNELS = 128,
    parameter STAGE3_CHANNELS = 256
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [15:0] input_data [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1],
    output reg [15:0] stage1_output [0:INPUT_WIDTH/2*INPUT_HEIGHT/2*STAGE1_CHANNELS-1],
    output reg [15:0] stage2_output [0:INPUT_WIDTH/4*INPUT_HEIGHT/4*STAGE2_CHANNELS-1],
    output reg [15:0] stage3_output [0:INPUT_WIDTH/8*INPUT_HEIGHT/8*STAGE3_CHANNELS-1],
    output reg done
);
    // Processing states
    localparam IDLE = 3'd0;
    localparam STAGE1 = 3'd1;
    localparam STAGE2 = 3'd2;
    localparam STAGE3 = 3'd3;
    localparam FINISH = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Control signals for each stage
    reg stage1_start, stage2_start, stage3_start;
    wire stage1_done, stage2_done, stage3_done;
    
    // Temporary memory
    reg [15:0] stage1_conv [0:INPUT_WIDTH*INPUT_HEIGHT*STAGE1_CHANNELS-1];
    reg [15:0] stage2_conv [0:INPUT_WIDTH/2*INPUT_HEIGHT/2*STAGE2_CHANNELS-1];
    reg [15:0] stage3_conv [0:INPUT_WIDTH/4*INPUT_HEIGHT/4*STAGE3_CHANNELS-1];
    
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
        stage1_start = 1'b0;
        stage2_start = 1'b0;
        stage3_start = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = STAGE1;
                    stage1_start = 1'b1;
                end
            end
            
            STAGE1: begin
                if (stage1_done) begin
                    next_state = STAGE2;
                    stage2_start = 1'b1;
                end
            end
            
            STAGE2: begin
                if (stage2_done) begin
                    next_state = STAGE3;
                    stage3_start = 1'b1;
                end
            end
            
            STAGE3: begin
                if (stage3_done)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Final state processing
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            done <= 1'b0;
        end else if (state == FINISH) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end
    
    // Encoder components
    encoder_stage1 #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INPUT_HEIGHT(INPUT_HEIGHT),
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .OUTPUT_CHANNELS(STAGE1_CHANNELS)
    ) stage1_inst (
        .clk(clk),
        .rst(rst),
        .start(stage1_start),
        .input_data(input_data),
        .conv_output(stage1_conv),
        .pool_output(stage1_output),
        .done(stage1_done)
    );
    
    encoder_stage2 #(
        .INPUT_WIDTH(INPUT_WIDTH/2),
        .INPUT_HEIGHT(INPUT_HEIGHT/2),
        .INPUT_CHANNELS(STAGE1_CHANNELS),
        .OUTPUT_CHANNELS(STAGE2_CHANNELS)
    ) stage2_inst (
        .clk(clk),
        .rst(rst),
        .start(stage2_start),
        .input_data(stage1_output),
        .conv_output(stage2_conv),
        .pool_output(stage2_output),
        .done(stage2_done)
    );
    
    encoder_stage3 #(
        .INPUT_WIDTH(INPUT_WIDTH/4),
        .INPUT_HEIGHT(INPUT_HEIGHT/4),
        .INPUT_CHANNELS(STAGE2_CHANNELS),
        .OUTPUT_CHANNELS(STAGE3_CHANNELS)
    ) stage3_inst (
        .clk(clk),
        .rst(rst),
        .start(stage3_start),
        .input_data(stage2_output),
        .conv_output(stage3_conv),
        .pool_output(stage3_output),
        .done(stage3_done)
    );
    
endmodule 