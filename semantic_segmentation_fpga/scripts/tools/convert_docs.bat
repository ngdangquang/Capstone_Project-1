@echo off
rem Batch script to convert all documentation to PDF
rem Requires pandoc to be installed

echo Converting documentation to PDF...

rem Create output directory if it doesn't exist
if not exist "..\..\docs\pdf" mkdir "..\..\docs\pdf"

rem Run the conversion script for each document
python convert_to_pdf.py ^
  "..\..\docs\README.md" ^
  "..\..\docs\CODE_EXPLANATION.md" ^
  "..\..\docs\GIẢI THÍCH MÃ NGUỒN.md" ^
  "..\..\docs\technical_report.md" ^
  "..\..\docs\paper.md" ^
  -o "..\..\docs\pdf" ^
  --toc

echo Conversion completed. PDFs are in docs\pdf directory. 