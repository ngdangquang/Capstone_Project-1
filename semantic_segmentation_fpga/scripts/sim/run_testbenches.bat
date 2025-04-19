@echo off
REM Script to run all testbenches for the semantic segmentation project on Windows

REM Directory structure
set RTL_DIR=rtl
set TB_DIR=testbench
set SIM_DIR=simulation

REM Create simulation directory if it doesn't exist
if not exist %SIM_DIR% mkdir %SIM_DIR%

echo Running testbenches for semantic segmentation project

REM Function to run a testbench (defined as a label)
goto :START

:RUN_TESTBENCH
echo Running testbench: %~1
REM Compile the design and testbench files
iverilog -o %SIM_DIR%\%~1.vvp ^
    %TB_DIR%\%~1.v ^
    %RTL_DIR%\top\semantic_segmentation_top.v ^
    %RTL_DIR%\core\image_loader.v ^
    %RTL_DIR%\core\segmentation_processor.v ^
    %RTL_DIR%\core\result_display.v ^
    %RTL_DIR%\core\pll.v ^
    %RTL_DIR%\network\encoder.v ^
    %RTL_DIR%\network\encoder_stages.v ^
    %RTL_DIR%\network\bottleneck.v ^
    %RTL_DIR%\network\decoder.v ^
    %RTL_DIR%\network\decoder_stages.v ^
    %RTL_DIR%\network\cityscapes_class_mapping.v

REM Check if compilation was successful
if %ERRORLEVEL% EQU 0 (
    REM Run the simulation
    vvp %SIM_DIR%\%~1.vvp
    
    REM Move VCD file if it exists
    if exist %~1.vcd (
        move %~1.vcd %SIM_DIR%\
        echo VCD file created: %SIM_DIR%\%~1.vcd
    )
) else (
    echo Compilation failed for %~1
)

echo -------------------------------------
exit /b

:START

REM Run each testbench
call :RUN_TESTBENCH tb_semantic_segmentation_top
call :RUN_TESTBENCH tb_image_loader
call :RUN_TESTBENCH tb_segmentation_processor
call :RUN_TESTBENCH tb_encoder
call :RUN_TESTBENCH tb_bottleneck
call :RUN_TESTBENCH tb_decoder
call :RUN_TESTBENCH tb_result_display

echo All testbenches completed.

REM Optional: Open GTKWave with the first testbench's waveform
where gtkwave >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    if exist %SIM_DIR%\tb_semantic_segmentation_top.vcd (
        echo Opening GTKWave with the first testbench waveform...
        start "" gtkwave %SIM_DIR%\tb_semantic_segmentation_top.vcd
    )
)

pause 