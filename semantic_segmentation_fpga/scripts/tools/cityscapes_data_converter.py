#!/usr/bin/env python3
"""
Cityscapes Data Converter for FPGA Semantic Segmentation

This script converts Cityscapes dataset images to a binary format
suitable for loading into the FPGA's SDRAM.
"""

import os
import sys
import argparse
import numpy as np
from PIL import Image

def resize_image(image, target_size=(224, 224)):
    """Resize image to target size while preserving aspect ratio"""
    img = Image.open(image)
    width, height = img.size
    
    # Calculate new size while preserving aspect ratio
    ratio = min(target_size[0] / width, target_size[1] / height)
    new_size = (int(width * ratio), int(height * ratio))
    
    # Resize image
    img_resized = img.resize(new_size, Image.LANCZOS)
    
    # Create new image with black padding
    padded_img = Image.new("RGB", target_size, (0, 0, 0))
    
    # Paste resized image in center
    offset = ((target_size[0] - new_size[0]) // 2,
              (target_size[1] - new_size[1]) // 2)
    padded_img.paste(img_resized, offset)
    
    return np.array(padded_img)

def convert_to_binary(image_data):
    """Convert image data to 32-bit binary format for SDRAM"""
    # Flatten RGB channels
    flat_data = image_data.reshape(-1)
    
    # Ensure the length is a multiple of 4 (for 32-bit words)
    padding = (4 - (len(flat_data) % 4)) % 4
    if padding:
        flat_data = np.pad(flat_data, (0, padding), 'constant')
    
    # Reshape to 32-bit words
    words = flat_data.reshape(-1, 4)
    
    # Convert to 32-bit binary values
    binary_data = np.zeros(words.shape[0], dtype=np.uint32)
    for i in range(words.shape[0]):
        # Pack 4 bytes into a 32-bit word
        binary_data[i] = (int(words[i, 0]) |
                         (int(words[i, 1]) << 8) |
                         (int(words[i, 2]) << 16) |
                         (int(words[i, 3]) << 24))
    
    return binary_data

def save_memory_file(binary_data, output_file):
    """Save binary data to memory initialization file"""
    with open(output_file, 'w') as f:
        for i, word in enumerate(binary_data):
            # Write address and data in hex format
            f.write(f"{i:08x}: {word:08x}\n")

def save_binary_file(binary_data, output_file):
    """Save binary data to raw binary file"""
    with open(output_file, 'wb') as f:
        binary_data.tofile(f)

def process_directory(input_dir, output_dir, format_type='binary'):
    """Process all image files in a directory"""
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    for root, _, files in os.walk(input_dir):
        for file in files:
            if file.lower().endswith(('.png', '.jpg', '.jpeg')):
                input_path = os.path.join(root, file)
                rel_path = os.path.relpath(input_path, input_dir)
                
                # Create output filename
                if format_type == 'binary':
                    output_path = os.path.join(output_dir, 
                                              os.path.splitext(rel_path)[0] + '.bin')
                else:
                    output_path = os.path.join(output_dir, 
                                              os.path.splitext(rel_path)[0] + '.mem')
                
                # Ensure output directory exists
                os.makedirs(os.path.dirname(output_path), exist_ok=True)
                
                # Process image
                try:
                    img_data = resize_image(input_path)
                    binary_data = convert_to_binary(img_data)
                    
                    if format_type == 'binary':
                        save_binary_file(binary_data, output_path)
                    else:
                        save_memory_file(binary_data, output_path)
                    
                    print(f"Processed: {input_path} -> {output_path}")
                except Exception as e:
                    print(f"Error processing {input_path}: {e}")

def main():
    parser = argparse.ArgumentParser(
        description='Convert Cityscapes images for FPGA SDRAM')
    
    parser.add_argument('input', help='Input image file or directory')
    parser.add_argument('output', help='Output binary file or directory')
    parser.add_argument('--format', choices=['binary', 'mem'], default='binary',
                        help='Output format (binary or memory initialization file)')
    
    args = parser.parse_args()
    
    if os.path.isdir(args.input):
        process_directory(args.input, args.output, args.format)
    else:
        # Process single file
        try:
            img_data = resize_image(args.input)
            binary_data = convert_to_binary(img_data)
            
            if args.format == 'binary':
                save_binary_file(binary_data, args.output)
            else:
                save_memory_file(binary_data, args.output)
            
            print(f"Processed: {args.input} -> {args.output}")
        except Exception as e:
            print(f"Error processing {args.input}: {e}")
            sys.exit(1)

if __name__ == "__main__":
    main() 