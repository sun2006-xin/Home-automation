@echo off
chcp 65001 >nul
echo ==================================================
echo   ESP32-C3 SuperMini 窗帘节点 (C01) 一键烧录程序
echo ==================================================

set PORT=%1
if "%PORT%"=="" (
    set /p PORT="请输入 ESP32 对应的 COM 端口号 (例如 COM3): "
)

set SCRIPT_DIR=%~dp0
set BIN_DIR=%SCRIPT_DIR%build_output
set BOOTLOADER=%BIN_DIR%\bootloader.bin
set PARTITION=%BIN_DIR%\partition-table.bin
set APP=%BIN_DIR%\nodeESP.bin

if not exist "%APP%" (
    echo [错误] 未在 %BIN_DIR% 找到固件，请检查文件！
    pause
    exit /b 1
)

set PYTHON_BIN=D:\esp\.espressif\python_env\idf5.4_py3.11_env\Scripts\python.exe
if not exist "%PYTHON_BIN%" (
    set PYTHON_BIN=python
)

echo [*] 开始烧录固件到 %PORT% ...
"%PYTHON_BIN%" -m esptool --chip esp32c3 -p %PORT% -b 460800 --before default_reset --after hard_reset write_flash --flash_mode dio --flash_size 4MB --flash_freq 80m 0x0 "%BOOTLOADER%" 0x8000 "%PARTITION%" 0x10000 "%APP%"

if %ERRORLEVEL% equ 0 (
    echo.
    echo [OK] 固件烧录成功！设备即将重启并开始广播 BLE: SH_CURTAIN_C01
) else (
    echo.
    echo [FAIL] 烧录失败，请检查串口是否正确连接，或按住 Boot 键重试！
)

pause
