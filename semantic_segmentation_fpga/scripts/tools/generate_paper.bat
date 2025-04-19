@echo off
echo Generating well-structured academic paper and converting to PDF...

:: Check if output directory exists and create if not
if not exist "..\..\docs" mkdir "..\..\docs"

:: Run the Python script to generate paper and convert to PDF
python generate_paper.py

echo.
echo If successful, the academic paper can be found at:
echo     semantic_segmentation_fpga\docs\academic_paper.pdf
echo.

pause 