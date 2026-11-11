<#
.SYNOPSIS
    ESP32-S3 / ESP32-C3 智能窗帘节点 (C01) 一键烧录脚本
.DESCRIPTION
    自动使用 ESP-IDF 环境中的 esptool 将预编译固件烧录到指定目标芯片 (默认 esp32s3)。
.EXAMPLE
    .\flash.ps1 -Chip esp32s3 -Port COM3
    .\flash.ps1 -Chip esp32c3 -Port COM5
#>
param(
    [string]$Port = "",
    [ValidateSet("esp32s3", "esp32c3")]
    [string]$Chip = "esp32s3"
)

$ErrorActionPreference = "Stop"

$targetSubDir = if ($Chip -eq "esp32s3") { "s3" } else { "c3" }
$chipLabel = if ($Chip -eq "esp32s3") { "ESP32-S3" } else { "ESP32-C3 SuperMini" }
$pinHint = if ($Chip -eq "esp32s3") {
    "GPIO4/5/6/7 (ULN2003 IN1~IN4), BOOT按键: GPIO0, 外接LED: GPIO2 (高电平亮)"
} else {
    "GPIO4/5/6/7 (ULN2003 IN1~IN4), BOOT按键: GPIO9, 板载LED: GPIO8 (低电平亮)"
}

if (-not $Port) {
    Write-Host "[*] 正在扫描可用 COM 端口..." -ForegroundColor Cyan
    $ports = [System.IO.Ports.SerialPort]::GetPortNames()
    if ($ports.Count -eq 0) {
        Write-Error "未发现任何 COM 串口设备，请插入 $chipLabel 开发板并确保 USB/UART 驱动正常！"
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
$binDir = Join-Path (Join-Path $scriptDir "build_output") $targetSubDir
$bootloader = Join-Path $binDir "bootloader.bin"
$partition = Join-Path $binDir "partition-table.bin"
$app = Join-Path $binDir "nodeESP.bin"

if (-not (Test-Path $app)) {
    Write-Error "未找到 $chipLabel 固件文件 $app，请先执行对应芯片的 idf.py build！"
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " $chipLabel 智能窗帘节点 (C01) 固件烧录" -ForegroundColor Cyan
Write-Host " 目标芯片: $Chip (4MB Flash / dio / 80MHz)" -ForegroundColor Cyan
Write-Host " 目标端口: $Port" -ForegroundColor Cyan
Write-Host " 固件目录: build_output/$targetSubDir" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 优先查找 ESP-IDF Python 环境下的 esptool
$pythonPath = "D:\esp\.espressif\python_env\idf5.4_py3.11_env\Scripts\python.exe"
if (-not (Test-Path $pythonPath)) {
    $pythonPath = "python"
}

& $pythonPath -m esptool --chip $Chip -p $Port -b 460800 `
    --before default_reset --after hard_reset `
    write_flash --flash_mode dio --flash_size 4MB --flash_freq 80m `
    0x0 $bootloader `
    0x8000 $partition `
    0x10000 $app

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[✓] $chipLabel 固件烧录成功！窗帘节点已就绪。" -ForegroundColor Green
    Write-Host "[i] BLE 广播名称: SH_CURTAIN_C01" -ForegroundColor Yellow
    Write-Host "[i] 引脚映射: $pinHint" -ForegroundColor Yellow
} else {
    Write-Error "`n[✗] 烧录失败，请检查串口是否被占用，或按住 BOOT 键点按 RST 进入下载模式后重试。"
}
