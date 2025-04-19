// Bottleneck module (middle layer between encoder and decoder)
module bottleneck #(
    parameter INPUT_WIDTH = 28,
    parameter INPUT_HEIGHT = 28,
    parameter CHANNELS = 256
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [15:0] input_data [0:INPUT_WIDTH*INPUT_HEIGHT*CHANNELS-1],
    output reg [15:0] output_data [0:INPUT_WIDTH*INPUT_HEIGHT*CHANNELS-1],
    output reg done
);
    // Processing states
    localparam IDLE = 2'd0;
    localparam PROCESSING = 2'd1;
    localparam FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    reg [31:0] counter;
    
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
                if (start) begin
                    next_state = PROCESSING;
                end
            end
            
            PROCESSING: begin
                if (counter >= INPUT_WIDTH*INPUT_HEIGHT*CHANNELS)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Bottleneck processing - perform two 3x3 conv layers
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 32'h0;
            done <= 1'b0;
            integer i;
            for (i = 0; i < INPUT_WIDTH*INPUT_HEIGHT*CHANNELS; i = i + 1) begin
                output_data[i] <= 16'h0;
            end
        end else begin
            case (state)
                IDLE: begin
                    counter <= 32'h0;
                    done <= 1'b0;
                end
                
                PROCESSING: begin
                    // Simplified - just pass-through with ReLU
                    if (counter < INPUT_WIDTH*INPUT_HEIGHT*CHANNELS) begin
                        // ReLU
                        output_data[counter] <= (input_data[counter][15]) ? 16'h0 : input_data[counter];
                        counter <= counter + 1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
endmodule 