#!/bin/bash
# Shell script to convert all documentation to PDF
# Requires pandoc to be installed

echo "Converting documentation to PDF..."

# Create output directory if it doesn't exist
mkdir -p ../../docs/pdf

# Run the conversion script for each document
python3 convert_to_pdf.py \
  ../../docs/README.md \
  ../../docs/CODE_EXPLANATION.md \
  "../../docs/GIẢI THÍCH MÃ NGUỒN.md" \
  ../../docs/technical_report.md \
  ../../docs/paper.md \
  -o ../../docs/pdf \
  --toc

echo "Conversion completed. PDFs are in docs/pdf directory." 