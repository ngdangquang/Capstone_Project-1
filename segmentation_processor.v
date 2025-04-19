// Semantic segmentation processor module (U-Net simplified)
module segmentation_processor #(
    parameter INPUT_WIDTH = 224,
    parameter INPUT_HEIGHT = 224,
    parameter INPUT_CHANNELS = 3,
    parameter NUM_CLASSES = 21
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [7:0] input_buffer [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1],
    output reg [7:0] output_buffer [0:INPUT_WIDTH*INPUT_HEIGHT-1],
    output reg done
);
    // Network parameters
    localparam ENCODER_STAGE1_CHANNELS = 64;
    localparam ENCODER_STAGE2_CHANNELS = 128;
    localparam ENCODER_STAGE3_CHANNELS = 256;
    
    // Processing states
    localparam IDLE = 3'd0;
    localparam PREPROCESS = 3'd1;
    localparam ENCODE = 3'd2;
    localparam BOTTLENECK = 3'd3;
    localparam DECODE = 3'd4;
    localparam POSTPROCESS = 3'd5;
    
    reg [2:0] state, next_state;
    
    // Control signals
    reg encode_start, bottleneck_start, decode_start;
    wire encode_done, bottleneck_done, decode_done;
    
    // Feature maps memory (between layers)
    reg [15:0] scaled_input [0:INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS-1];
    reg [15:0] encoder_stage1 [0:INPUT_WIDTH/2*INPUT_HEIGHT/2*ENCODER_STAGE1_CHANNELS-1];
    reg [15:0] encoder_stage2 [0:INPUT_WIDTH/4*INPUT_HEIGHT/4*ENCODER_STAGE2_CHANNELS-1];
    reg [15:0] encoder_stage3 [0:INPUT_WIDTH/8*INPUT_HEIGHT/8*ENCODER_STAGE3_CHANNELS-1];
    reg [15:0] bottleneck [0:INPUT_WIDTH/8*INPUT_HEIGHT/8*ENCODER_STAGE3_CHANNELS-1];
    reg [15:0] decoder_stage1 [0:INPUT_WIDTH/4*INPUT_HEIGHT/4*ENCODER_STAGE2_CHANNELS-1];
    reg [15:0] decoder_stage2 [0:INPUT_WIDTH/2*INPUT_HEIGHT/2*ENCODER_STAGE1_CHANNELS-1];
    reg [15:0] logits [0:INPUT_WIDTH*INPUT_HEIGHT*NUM_CLASSES-1];
    
    // Counters and sequences
    reg [31:0] process_counter;
    reg [15:0] class_scores [0:NUM_CLASSES-1];
    reg [7:0] max_class;
    reg [15:0] max_score;
    
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
        encode_start = 1'b0;
        bottleneck_start = 1'b0;
        decode_start = 1'b0;
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = PREPROCESS;
            end
            
            PREPROCESS: begin
                next_state = ENCODE;
                encode_start = 1'b1;
            end
            
            ENCODE: begin
                if (encode_done) begin
                    next_state = BOTTLENECK;
                    bottleneck_start = 1'b1;
                end
            end
            
            BOTTLENECK: begin
                if (bottleneck_done) begin
                    next_state = DECODE;
                    decode_start = 1'b1;
                end
            end
            
            DECODE: begin
                if (decode_done)
                    next_state = POSTPROCESS;
            end
            
            POSTPROCESS: begin
                if (process_counter >= INPUT_WIDTH*INPUT_HEIGHT)
                    next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Image preprocessing (normalization)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            process_counter <= 32'h0;
            // Initialize scaled_input array
            integer i;
            for (i = 0; i < INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS; i = i + 1) begin
                scaled_input[i] <= 16'h0;
            end
        end else if (state == PREPROCESS) begin
            if (process_counter < INPUT_WIDTH*INPUT_HEIGHT*INPUT_CHANNELS) begin
                // Normalize pixel from 0-255 to fixed-point 8.8 format
                scaled_input[process_counter] <= {8'h0, input_buffer[process_counter]};
                process_counter <= process_counter + 1;
            end else begin
                process_counter <= 32'h0;
            end
        end else if (state != PREPROCESS) begin
            process_counter <= 32'h0;
        end
    end
    
    // Post-processing (argmax to get class labels)
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            process_counter <= 32'h0;
            // Initialize output_buffer array
            integer i;
            for (i = 0; i < INPUT_WIDTH*INPUT_HEIGHT; i = i + 1) begin
                output_buffer[i] <= 8'h0;
            end
            done <= 1'b0;
        end else if (state == POSTPROCESS) begin
            done <= 1'b0;
            if (process_counter < INPUT_WIDTH*INPUT_HEIGHT) begin
                // Find class with highest score
                max_score <= 16'h0;
                max_class <= 8'h0;
                
                // Process each class score and find max
                integer c;
                for (c = 0; c < NUM_CLASSES; c = c + 1) begin
                    class_scores[c] <= logits[process_counter*NUM_CLASSES + c];
                    if (logits[process_counter*NUM_CLASSES + c] > max_score) begin
                        max_score <= logits[process_counter*NUM_CLASSES + c];
                        max_class <= c[7:0];
                    end
                end
                
                output_buffer[process_counter] <= max_class;
                process_counter <= process_counter + 1;
            end else begin
                done <= 1'b1;
            end
        end else if (state == IDLE) begin
            process_counter <= 32'h0;
            done <= 1'b0;
        end
    end
    
    // Instantiate CNN modules
    encoder #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INPUT_HEIGHT(INPUT_HEIGHT),
        .INPUT_CHANNELS(INPUT_CHANNELS),
        .STAGE1_CHANNELS(ENCODER_STAGE1_CHANNELS),
        .STAGE2_CHANNELS(ENCODER_STAGE2_CHANNELS),
        .STAGE3_CHANNELS(ENCODER_STAGE3_CHANNELS)
    ) encoder_inst (
        .clk(clk),
        .rst(rst),
        .start(encode_start),
        .input_data(scaled_input),
        .stage1_output(encoder_stage1),
        .stage2_output(encoder_stage2),
        .stage3_output(encoder_stage3),
        .done(encode_done)
    );
    
    bottleneck #(
        .INPUT_WIDTH(INPUT_WIDTH/8),
        .INPUT_HEIGHT(INPUT_HEIGHT/8),
        .CHANNELS(ENCODER_STAGE3_CHANNELS)
    ) bottleneck_inst (
        .clk(clk),
        .rst(rst),
        .start(bottleneck_start),
        .input_data(encoder_stage3),
        .output_data(bottleneck),
        .done(bottleneck_done)
    );
    
    decoder #(
        .INPUT_WIDTH(INPUT_WIDTH),
        .INPUT_HEIGHT(INPUT_HEIGHT),
        .STAGE1_CHANNELS(ENCODER_STAGE1_CHANNELS),
        .STAGE2_CHANNELS(ENCODER_STAGE2_CHANNELS),
        .STAGE3_CHANNELS(ENCODER_STAGE3_CHANNELS),
        .NUM_CLASSES(NUM_CLASSES)
    ) decoder_inst (
        .clk(clk),
        .rst(rst),
        .start(decode_start),
        .bottleneck_data(bottleneck),
        .enc_stage1_data(encoder_stage1),
        .enc_stage2_data(encoder_stage2),
        .enc_stage3_data(encoder_stage3),
        .stage1_output(decoder_stage1),
        .stage2_output(decoder_stage2),
        .logits_output(logits),
        .done(decode_done)
    );

endmodule 