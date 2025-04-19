# Code Explanation: Semantic Segmentation on FPGA

This document provides a detailed explanation of the semantic segmentation implementation on the DE10-Standard FPGA kit.

## Overall Architecture

The system implements a simplified U-Net architecture, a convolutional neural network (CNN) commonly used for image segmentation tasks. The implementation includes the following main components:

1. **Top Module** (`semantic_segmentation_top.v`): Coordinates all operations and data flow between components
2. **Image Loader** (`image_loader.v`): Reads image data from SDRAM
3. **Segmentation Processor** (`segmentation_processor.v`): Main processing pipeline
4. **Encoder** (`encoder.v`): Downsampling path of the U-Net
5. **Bottleneck** (`bottleneck.v`): Middle layer of the U-Net
6. **Decoder** (`decoder.v`): Upsampling path of the U-Net
7. **Result Display** (`result_display.v`): Outputs results to VGA display

## Data Flow

The system operates with the following data flow:

1. Image data is loaded from SDRAM into the input buffer
2. The segmentation processor normalizes the image data
3. The encoder extracts features through convolution and downsampling
4. The bottleneck processes the compressed representation
5. The decoder upsamples the features and combines them with skip connections
6. The segmentation processor performs post-processing to determine class labels
7. The result display maps class labels to colors and outputs to VGA

## Module Descriptions

### Top Module (`semantic_segmentation_top.v`)

The top module implements a state machine with four states:
- **IDLE**: Waiting for start signal
- **LOAD_IMAGE**: Loading image data from SDRAM
- **PROCESS**: Processing the image through the segmentation network
- **DISPLAY_RESULT**: Displaying segmentation results

It coordinates all other modules and handles data transfer between them.

### Image Loader (`image_loader.v`)

This module interfaces with SDRAM to read image data. It implements a state machine to issue read commands and process received data. Features:
- Reads 32-bit words from SDRAM and breaks them into individual bytes (RGB pixels)
- Supports burst reads for improved performance
- Writes pixels to the input buffer of the top module

### Segmentation Processor (`segmentation_processor.v`)

The heart of the system, implementing a state machine with six states:
- **IDLE**: Waiting for start signal
- **PREPROCESS**: Normalizing input pixel data to fixed-point format
- **ENCODE**: Running the encoder stages
- **BOTTLENECK**: Running the bottleneck layer
- **DECODE**: Running the decoder stages
- **POSTPROCESS**: Converting network outputs to class labels

In the post-processing step, it performs an "argmax" operation to find the class with the highest probability for each pixel.

### Encoder (`encoder.v`)

Implements the downsampling path of the U-Net. It includes three encoder stages, each containing:
- Convolution layers
- ReLU activation
- Max pooling

Each stage doubles the number of channels and halves the spatial dimensions:
- Stage 1: 3→64 channels, 224×224→112×112
- Stage 2: 64→128 channels, 112×112→56×56
- Stage 3: 128→256 channels, 56×56→28×28

### Bottleneck (`bottleneck.v`)

The central part of the U-Net processing the most compressed representation. It performs:
- ReLU activation on input features
- In a full implementation, it would perform additional convolutions

### Decoder (`decoder.v`)

Implements the upsampling path of the U-Net. It includes three decoder stages, each containing:
- Upsampling of feature maps
- Concatenation with skip connections from encoder
- Convolution to reduce the number of channels

Each stage halves the number of channels and doubles the spatial dimensions:
- Stage 1: 256→128 channels, 28×28→56×56
- Stage 2: 128→64 channels, 56×56→112×112
- Stage 3: 64→21 channels, 112×112→224×224

The final stage outputs logits for each of the 21 classes.

### Result Display (`result_display.v`)

This module handles VGA timing and displays segmentation results. Features:
- Generates VGA timing signals
- Maps class indices to RGB colors
- Scales output image to fit the display

## Implementation Details

### Fixed-Point Arithmetic

All internal calculations use fixed-point arithmetic in 8.8 format (8 bits for integer part, 8 bits for fractional part). This provides a good balance between precision and resource usage.

### Convolution Implementation

Convolutions are implemented using a simplified approach:
1. Processing one output pixel at a time
2. For each output pixel, calculating the weighted sum of input pixels in a 3×3 neighborhood
3. Adding bias
4. Applying ReLU activation

### Memory Organization

- Input images: Stored in SDRAM in RGB888 format (8 bits per channel)
- Feature maps: Stored in block RAM within the FPGA
- Weights: Randomly initialized in this demo (would be loaded from memory in a real application)

### Optimization Techniques

Several optimization techniques are used to make the implementation efficient on FPGA:
1. **Sequential Processing**: Operations are performed sequentially to reduce resource usage
2. **State Machines**: Each module uses a state machine to control processing flow
3. **Operation Simplification**: Complex operations are simplified where possible
4. **Resource Sharing**: Operations are reused where possible

## Performance Considerations

The current implementation prioritizes resource usage over speed. For higher performance:
1. More parallel processing could be introduced in convolution operations
2. Pipeline stages could be added
3. More efficient memory access patterns could be used

## Future Enhancements

Possible enhancements for future versions:
1. Support for loading pre-trained weights
2. Implementation of batch normalization
3. Support for different input image sizes
4. Hardware acceleration for convolution operations
5. Support for video processing
6. Implementation of more complex network architectures 