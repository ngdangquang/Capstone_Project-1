// Module for Cityscapes class mapping and color visualization
// Based on Cityscapes class definitions - https://github.com/mcordts/cityscapesScripts

module cityscapes_class_mapping (
    input wire [7:0] class_id,         // Input class ID (0-29)
    output reg [7:0] mapped_class_id,  // Mapped class ID (0-18)
    output reg [7:0] r,                // Red channel for visualization
    output reg [7:0] g,                // Green channel for visualization
    output reg [7:0] b                 // Blue channel for visualization
);

    // Cityscapes has 30 classes, but for semantic segmentation
    // we typically use the 19 evaluation classes
    // This module provides both the Cityscapes color map and
    // the class ID mapping for training/evaluation
    
    always @(*) begin
        case (class_id)
            // Class 0: Unlabeled/void
            8'd0, 8'd1, 8'd2, 8'd3, 8'd4, 8'd5, 8'd6: begin
                mapped_class_id = 8'd0;
                r = 8'h00; g = 8'h00; b = 8'h00; // Black
            end
            
            // Class 7: Road
            8'd7: begin
                mapped_class_id = 8'd1;
                r = 8'h80; g = 8'h80; b = 8'h80; // Gray
            end
            
            // Class 8: Sidewalk
            8'd8: begin
                mapped_class_id = 8'd2;
                r = 8'hC0; g = 8'h80; b = 8'h80; // Light red-gray
            end
            
            // Class 9: Building
            8'd11: begin
                mapped_class_id = 8'd3;
                r = 8'h80; g = 8'h00; b = 8'h80; // Purple
            end
            
            // Class 10: Wall
            8'd12: begin
                mapped_class_id = 8'd4;
                r = 8'hA0; g = 8'h60; b = 8'h60; // Gray-red
            end
            
            // Class 11: Fence
            8'd13: begin
                mapped_class_id = 8'd5;
                r = 8'hA0; g = 8'h80; b = 8'h60; // Gray-yellow
            end
            
            // Class 12: Pole
            8'd17: begin
                mapped_class_id = 8'd6;
                r = 8'hA0; g = 8'hA0; b = 8'h60; // Yellow-gray
            end
            
            // Class 13: Traffic Light
            8'd19: begin
                mapped_class_id = 8'd7;
                r = 8'hE0; g = 8'hE0; b = 8'h00; // Yellow
            end
            
            // Class 14: Traffic Sign
            8'd20: begin
                mapped_class_id = 8'd8;
                r = 8'hE0; g = 8'h60; b = 8'h00; // Orange
            end
            
            // Class 15: Vegetation
            8'd21: begin
                mapped_class_id = 8'd9;
                r = 8'h00; g = 8'h80; b = 8'h00; // Green
            end
            
            // Class 16: Terrain
            8'd22: begin
                mapped_class_id = 8'd10;
                r = 8'h60; g = 8'h80; b = 8'h00; // Olive
            end
            
            // Class 17: Sky
            8'd23: begin
                mapped_class_id = 8'd11;
                r = 8'h00; g = 8'h00; b = 8'h80; // Blue
            end
            
            // Class 18: Person
            8'd24: begin
                mapped_class_id = 8'd12;
                r = 8'hE0; g = 8'h00; b = 8'h00; // Red
            end
            
            // Class 19: Rider
            8'd25: begin
                mapped_class_id = 8'd13;
                r = 8'hC0; g = 8'h00; b = 8'h40; // Magenta
            end
            
            // Class 20: Car
            8'd26: begin
                mapped_class_id = 8'd14;
                r = 8'h00; g = 8'h00; b = 8'hE0; // Blue
            end
            
            // Class 21: Truck
            8'd27: begin
                mapped_class_id = 8'd15;
                r = 8'h00; g = 8'h80; b = 8'hC0; // Cyan-blue
            end
            
            // Class 22: Bus
            8'd28: begin
                mapped_class_id = 8'd16;
                r = 8'h00; g = 8'h80; b = 8'h80; // Cyan
            end
            
            // Class 23: Train
            8'd31: begin
                mapped_class_id = 8'd17;
                r = 8'h00; g = 8'h40; b = 8'h80; // Dark blue
            end
            
            // Class 24: Motorcycle
            8'd32: begin
                mapped_class_id = 8'd18;
                r = 8'h80; g = 8'h00; b = 8'h00; // Maroon
            end
            
            // Class 25: Bicycle
            8'd33: begin
                mapped_class_id = 8'd19;
                r = 8'h80; g = 8'h40; b = 8'h00; // Brown
            end
            
            // Default (any other class ID) - Map to void/unlabeled
            default: begin
                mapped_class_id = 8'd0;
                r = 8'h00; g = 8'h00; b = 8'h00; // Black
            end
        endcase
    end

endmodule 