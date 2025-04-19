// Module for loading image from SDRAM
module image_loader #(
    parameter IMAGE_WIDTH = 224,
    parameter IMAGE_HEIGHT = 224,
    parameter CHANNELS = 3
)(
    input wire clk,
    input wire rst,
    input wire start,
    output reg [19:0] sdram_addr,
    inout wire [31:0] sdram_data,
    output reg sdram_we_n,
    output reg sdram_cs_n,
    output reg sdram_ras_n,
    output reg sdram_cas_n,
    output reg [7:0] pixel_data,
    output reg [19:0] pixel_addr,
    output reg pixel_we,
    output reg done
);
    // SDRAM parameters
    localparam BASE_ADDR = 20'h00000;
    localparam BURST_LEN = 8;
    
    // States
    localparam IDLE = 3'd0;
    localparam INIT = 3'd1;
    localparam READ_CMD = 3'd2;
    localparam READ_DATA = 3'd3;
    localparam WAIT_NEXT = 3'd4;
    localparam FINISH = 3'd5;
    
    // State and control registers
    reg [2:0] state, next_state;
    reg [19:0] mem_addr;
    reg [19:0] pixel_cnt;
    reg [2:0] burst_cnt;
    reg [31:0] pixel_buffer;
    reg [1:0] byte_cnt;
    
    // State definitions
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
                    next_state = INIT;
            end
            
            INIT: begin
                next_state = READ_CMD;
            end
            
            READ_CMD: begin
                next_state = READ_DATA;
            end
            
            READ_DATA: begin
                if (burst_cnt == BURST_LEN-1)
                    next_state = WAIT_NEXT;
            end
            
            WAIT_NEXT: begin
                if (pixel_cnt >= IMAGE_WIDTH*IMAGE_HEIGHT*CHANNELS)
                    next_state = FINISH;
                else
                    next_state = READ_CMD;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // SDRAM read control and pixel handling
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sdram_addr <= 20'h0;
            sdram_we_n <= 1'b1;
            sdram_cs_n <= 1'b1;
            sdram_ras_n <= 1'b1;
            sdram_cas_n <= 1'b1;
            pixel_data <= 8'h0;
            pixel_addr <= 20'h0;
            pixel_we <= 1'b0;
            done <= 1'b0;
            mem_addr <= BASE_ADDR;
            pixel_cnt <= 20'h0;
            burst_cnt <= 3'h0;
            byte_cnt <= 2'h0;
            pixel_buffer <= 32'h0;
        end else begin
            case (state)
                IDLE: begin
                    sdram_cs_n <= 1'b1;
                    pixel_we <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        mem_addr <= BASE_ADDR;
                        pixel_cnt <= 20'h0;
                    end
                end
                
                INIT: begin
                    sdram_cs_n <= 1'b1;
                    pixel_we <= 1'b0;
                end
                
                READ_CMD: begin
                    sdram_addr <= mem_addr;
                    sdram_cs_n <= 1'b0;
                    sdram_ras_n <= 1'b0;
                    sdram_cas_n <= 1'b0;
                    sdram_we_n <= 1'b1;  // Read
                    burst_cnt <= 3'h0;
                    byte_cnt <= 2'h0;
                end
                
                READ_DATA: begin
                    burst_cnt <= burst_cnt + 1'b1;
                    pixel_buffer <= sdram_data;
                    
                    // Process each byte in 32-bit word
                    case (byte_cnt)
                        2'h0: begin
                            pixel_data <= pixel_buffer[7:0];
                            pixel_addr <= pixel_cnt;
                            pixel_we <= 1'b1;
                            pixel_cnt <= pixel_cnt + 1'b1;
                            byte_cnt <= 2'h1;
                        end
                        2'h1: begin
                            pixel_data <= pixel_buffer[15:8];
                            pixel_addr <= pixel_cnt;
                            pixel_we <= 1'b1;
                            pixel_cnt <= pixel_cnt + 1'b1;
                            byte_cnt <= 2'h2;
                        end
                        2'h2: begin
                            pixel_data <= pixel_buffer[23:16];
                            pixel_addr <= pixel_cnt;
                            pixel_we <= 1'b1;
                            pixel_cnt <= pixel_cnt + 1'b1;
                            byte_cnt <= 2'h3;
                        end
                        2'h3: begin
                            pixel_data <= pixel_buffer[31:24];
                            pixel_addr <= pixel_cnt;
                            pixel_we <= 1'b1;
                            pixel_cnt <= pixel_cnt + 1'b1;
                            byte_cnt <= 2'h0;
                        end
                    endcase
                end
                
                WAIT_NEXT: begin
                    sdram_cs_n <= 1'b1;
                    pixel_we <= 1'b0;
                    mem_addr <= mem_addr + (BURST_LEN * 4); // Each read is 4 bytes
                end
                
                FINISH: begin
                    done <= 1'b1;
                    pixel_we <= 1'b0;
                    sdram_cs_n <= 1'b1;
                end
            endcase
        end
    end
    
endmodule 