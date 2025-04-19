// Module for displaying segmentation results via VGA
module result_display #(
    parameter IMAGE_WIDTH = 224,
    parameter IMAGE_HEIGHT = 224
)(
    input wire clk,
    input wire vga_clk,
    input wire rst,
    input wire start,
    input wire [7:0] output_buffer [0:IMAGE_WIDTH*IMAGE_HEIGHT-1],
    output reg [19:0] pixel_addr,
    output reg [7:0] pixel_data,
    output reg [7:0] vga_r,
    output reg [7:0] vga_g,
    output reg [7:0] vga_b,
    output reg vga_hsync,
    output reg vga_vsync,
    output reg vga_blank_n,
    output reg vga_sync_n,
    output reg vga_clk,
    output reg done
);
    // Processing states
    localparam IDLE = 2'd0;
    localparam DISPLAY = 2'd1;
    localparam FINISH = 2'd2;
    
    reg [1:0] state, next_state;
    
    // VGA parameters for 640x480@60Hz
    localparam H_VISIBLE = 640;
    localparam H_FRONT_PORCH = 16;
    localparam H_SYNC_PULSE = 96;
    localparam H_BACK_PORCH = 48;
    localparam H_TOTAL = H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE + H_BACK_PORCH;
    
    localparam V_VISIBLE = 480;
    localparam V_FRONT_PORCH = 10;
    localparam V_SYNC_PULSE = 2;
    localparam V_BACK_PORCH = 33;
    localparam V_TOTAL = V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE + V_BACK_PORCH;
    
    // Pixel position counter
    reg [9:0] h_count;
    reg [9:0] v_count;
    reg h_active, v_active;
    
    // Color mapping for classes
    reg [7:0] class_color_r [0:20]; // Pascal VOC has 21 classes (0-20)
    reg [7:0] class_color_g [0:20];
    reg [7:0] class_color_b [0:20];
    
    // Initialize color table
    initial begin
        // Background
        class_color_r[0] = 8'd0;
        class_color_g[0] = 8'd0;
        class_color_b[0] = 8'd0;
        
        // Person
        class_color_r[1] = 8'd255;
        class_color_g[1] = 8'd0;
        class_color_b[1] = 8'd0;
        
        // Car
        class_color_r[2] = 8'd0;
        class_color_g[2] = 8'd255;
        class_color_b[2] = 8'd0;
        
        // Other classes...
        // Add colors for classes 3-20
        // For example:
        class_color_r[3] = 8'd0;
        class_color_g[3] = 8'd0;
        class_color_b[3] = 8'd255;
        
        // ...
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
                    next_state = DISPLAY;
            end
            
            DISPLAY: begin
                if (h_count == H_TOTAL-1 && v_count == V_TOTAL-1)
                    next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // VGA timing control
    always @(posedge vga_clk or posedge rst) begin
        if (rst) begin
            h_count <= 10'd0;
            v_count <= 10'd0;
            h_active <= 1'b0;
            v_active <= 1'b0;
            vga_hsync <= 1'b0;
            vga_vsync <= 1'b0;
            vga_blank_n <= 1'b0;
            vga_sync_n <= 1'b1;
            vga_clk <= 1'b0;
            done <= 1'b0;
        end else begin
            vga_clk <= vga_clk;
            
            if (state == DISPLAY) begin
                // Horizontal counter
                if (h_count < H_TOTAL - 1)
                    h_count <= h_count + 1'b1;
                else begin
                    h_count <= 10'd0;
                    
                    // Vertical counter
                    if (v_count < V_TOTAL - 1)
                        v_count <= v_count + 1'b1;
                    else
                        v_count <= 10'd0;
                end
                
                // Horizontal sync
                if (h_count >= H_VISIBLE + H_FRONT_PORCH && h_count < H_VISIBLE + H_FRONT_PORCH + H_SYNC_PULSE)
                    vga_hsync <= 1'b0;
                else
                    vga_hsync <= 1'b1;
                
                // Vertical sync
                if (v_count >= V_VISIBLE + V_FRONT_PORCH && v_count < V_VISIBLE + V_FRONT_PORCH + V_SYNC_PULSE)
                    vga_vsync <= 1'b0;
                else
                    vga_vsync <= 1'b1;
                
                // Active video
                h_active <= (h_count < H_VISIBLE);
                v_active <= (v_count < V_VISIBLE);
                vga_blank_n <= h_active && v_active;
                
                // Read data from memory
                if (h_active && v_active) begin
                    // Scale from input image size to VGA
                    if (h_count < IMAGE_WIDTH && v_count < IMAGE_HEIGHT) begin
                        pixel_addr <= v_count * IMAGE_WIDTH + h_count;
                        pixel_data <= output_buffer[pixel_addr];
                        
                        // Map class index to color
                        vga_r <= class_color_r[pixel_data];
                        vga_g <= class_color_g[pixel_data];
                        vga_b <= class_color_b[pixel_data];
                    end else begin
                        vga_r <= 8'h0;
                        vga_g <= 8'h0;
                        vga_b <= 8'h0;
                    end
                end else begin
                    vga_r <= 8'h0;
                    vga_g <= 8'h0;
                    vga_b <= 8'h0;
                end
            end else if (state == FINISH) begin
                done <= 1'b1;
            end else begin
                h_count <= 10'd0;
                v_count <= 10'd0;
                done <= 1'b0;
            end
        end
    end
    
endmodule 