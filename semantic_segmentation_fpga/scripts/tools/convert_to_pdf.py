#!/usr/bin/env python3
"""
Convert Markdown Documentation to PDF using Pandoc

This script converts Markdown files to PDF format using pandoc.
It can process multiple files at once and supports custom styling.
"""

import os
import sys
import argparse
import subprocess
from pathlib import Path

def check_pandoc_installed():
    """Check if pandoc is installed"""
    try:
        subprocess.run(['pandoc', '--version'], 
                       stdout=subprocess.PIPE, 
                       stderr=subprocess.PIPE, 
                       check=True)
        return True
    except (subprocess.SubprocessError, FileNotFoundError):
        print("Error: pandoc is not installed or not in PATH.")
        print("Please install pandoc from https://pandoc.org/installing.html")
        return False

def convert_to_pdf(markdown_file, output_file=None, template=None, 
                   reference_doc=None, include_toc=False, paper_size='a4'):
    """Convert a markdown file to PDF using pandoc"""
    if not output_file:
        output_file = Path(markdown_file).with_suffix('.pdf')
    
    cmd = ['pandoc', markdown_file, '-o', output_file, 
           '--pdf-engine=xelatex', f'--variable=papersize:{paper_size}']
    
    if template:
        cmd.extend(['--template', template])
    
    if reference_doc:
        cmd.extend(['--reference-doc', reference_doc])
    
    if include_toc:
        cmd.append('--toc')
    
    print(f"Converting {markdown_file} to {output_file}...")
    try:
        result = subprocess.run(cmd, 
                                stdout=subprocess.PIPE, 
                                stderr=subprocess.PIPE, 
                                check=True, 
                                text=True)
        print(f"Successfully converted to {output_file}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error converting {markdown_file} to PDF:")
        print(e.stderr)
        return False

def main():
    parser = argparse.ArgumentParser(
        description='Convert Markdown files to PDF using pandoc')
    
    parser.add_argument('input_files', nargs='+', 
                        help='Input Markdown files to convert')
    parser.add_argument('-o', '--output-dir', 
                        help='Output directory for PDF files')
    parser.add_argument('-t', '--template', 
                        help='Path to pandoc template file')
    parser.add_argument('-r', '--reference-doc', 
                        help='Path to reference document (for styling)')
    parser.add_argument('--toc', action='store_true', 
                        help='Include table of contents')
    parser.add_argument('--paper', default='a4', 
                        choices=['a4', 'letter'], 
                        help='Paper size')
    
    args = parser.parse_args()
    
    if not check_pandoc_installed():
        sys.exit(1)
    
    # Create output directory if it doesn't exist
    if args.output_dir:
        os.makedirs(args.output_dir, exist_ok=True)
    
    success_count = 0
    for input_file in args.input_files:
        if not os.path.exists(input_file):
            print(f"Error: Input file {input_file} does not exist.")
            continue
        
        if args.output_dir:
            output_file = os.path.join(args.output_dir, 
                                       Path(input_file).with_suffix('.pdf').name)
        else:
            output_file = None
        
        if convert_to_pdf(input_file, output_file, args.template,
                          args.reference_doc, args.toc, args.paper):
            success_count += 1
    
    print(f"\nConversion summary: {success_count}/{len(args.input_files)} files successful")

if __name__ == "__main__":
    main() 