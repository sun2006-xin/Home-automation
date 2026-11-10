<#
.SYNOPSIS
    ESP32-C3 SuperMini 窗帘节点 (C01) 一键烧录脚本
.DESCRIPTION
    自动使用 esptool 或 idf.py 将编译好的三合一固件烧录到 ESP32-C3
.EXAMPLE
    .\flash.ps1 -Port COM3
#>
param(
    [string]$Port = ""
)

$ErrorActionPreference = "Stop"

if (-not $Port) {
    # 尝试自动检测 ESP32 串口
    Write-Host "[*] 正在扫描可用 COM 端口..." -ForegroundColor Cyan
    $ports = [System.IO.Ports.SerialPort]::GetPortNames()
    if ($ports.Count -eq 0) {
        Write-Error "未发现任何 COM 串口设备，请插入 ESP32-C3 并确保驱动正常！"
        exit 1
    } elseif ($ports.Count -eq 1) {
        $Port = $ports[0]
        Write-Host "[+] 自动选中唯一检测到的端口: $Port" -ForegroundColor Green
    } else {
        Write-Host "检测到多个串口: $($ports -join ', ')" -ForegroundColor Yellow
        $Port = Read-Host "请输入要烧录的串口号 (例如 $($ports[0]))"
    }
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$binDir = Join-Path $scriptDir "build_output"
$bootloader = Join-Path $binDir "bootloader.bin"
$partition = Join-Path $binDir "partition-table.bin"
$app = Join-Path $binDir "nodeESP.bin"

if (-not (Test-Path $app)) {
    Write-Error "未找到固件文件 $app，请先执行编译！"
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " ESP32-C3 智能窗帘节点 (C01) 固件烧录程序 " -ForegroundColor Cyan
Write-Host " 目标端口: $Port" -ForegroundColor Cyan
Write-Host " 波特率:   460800" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 优先查找 ESP-IDF Python 环境下的 esptool
$pythonPath = "D:\esp\.espressif\python_env\idf5.4_py3.11_env\Scripts\python.exe"
if (-not (Test-Path $pythonPath)) {
    $pythonPath = "python"
}

& $pythonPath -m esptool --chip esp32c3 -p $Port -b 460800 `
    --before default_reset --after hard_reset `
    write_flash --flash_mode dio --flash_size 4MB --flash_freq 80m `
    0x0 $bootloader `
    0x8000 $partition `
    0x10000 $app

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[✓] 固件烧录成功！ESP32-C3 窗帘节点已就绪。" -ForegroundColor Green
    Write-Host "[i] BLE广播名称: SH_CURTAIN_C01" -ForegroundColor Yellow
    Write-Host "[i] 控制引脚: GPIO4/5/6/7 (ULN2003 IN1~IN4), 按键: GPIO9, LED: GPIO8" -ForegroundColor Yellow
} else {
    Write-Error "`n[✗] 烧录失败，请检查端口是否被占用，或长按 Boot 键按一下 Reset 键进入下载模式重试。"
}
