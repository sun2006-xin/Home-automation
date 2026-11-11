@echo off
chcp 65001 >nul
echo ==================================================
echo   SmartHome 窗帘节点 (C01) 一键烧录 [S3 / C3 通用]
echo ==================================================

set PORT=%1
set CHIP=%2

if "%PORT%"=="" (
    set /p PORT="请输入 ESP32 对应的 COM 端口号 (例如 COM3): "
)

if "%CHIP%"=="" (
    echo 请选择目标芯片型号:
    echo   [1] ESP32-S3  ^(默认^)
    echo   [2] ESP32-C3  SuperMini
    set /p CHIP_CHOICE="输入选项 [1/2, 直接回车选 1]: "
    if "%CHIP_CHOICE%"=="2" (
        set CHIP=esp32c3
    ) else (
        set CHIP=esp32s3
    )
)

if /i "%CHIP%"=="esp32c3" (
    set SUBDIR=c3
) else (
    set CHIP=esp32s3
    set SUBDIR=s3
)

set SCRIPT_DIR=%~dp0
set BIN_DIR=%SCRIPT_DIR%build_output\%SUBDIR%
set BOOTLOADER=%BIN_DIR%\bootloader.bin
set PARTITION=%BIN_DIR%\partition-table.bin
set APP=%BIN_DIR%\nodeESP.bin

if not exist "%APP%" (
    echo [错误] 未在 %BIN_DIR% 找到 %CHIP% 固件，请先编译对应芯片！
    pause
    exit /b 1
)

set PYTHON_BIN=D:\esp\.espressif\python_env\idf5.4_py3.11_env\Scripts\python.exe
if not exist "%PYTHON_BIN%" (
    set PYTHON_BIN=python
)

echo [*] 开始烧录 %CHIP% 固件到 %PORT% ...
"%PYTHON_BIN%" -m esptool --chip %CHIP% -p %PORT% -b 460800 --before default_reset --after hard_reset write_flash --flash_mode dio --flash_size 4MB --flash_freq 80m 0x0 "%BOOTLOADER%" 0x8000 "%PARTITION%" 0x10000 "%APP%"

if %ERRORLEVEL% equ 0 (
    echo.
    echo [OK] %CHIP% 固件烧录成功！设备重启后开始广播 BLE: SH_CURTAIN_C01
) else (
    echo.
    echo [FAIL] 烧录失败，请检查串口号，或按住 BOOT 键按一下 RST 进入下载模式重试！
)

pause
