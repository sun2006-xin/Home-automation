<#
.SYNOPSIS
    智慧家庭终端与节点全链路调试中心启动脚本
#>
param(
    [switch]$Check,
    [switch]$PhoneInstall,
    [switch]$PhoneScreenshot,
    [switch]$PhoneLogs,
    [string]$FlashMcu,
    [string]$MonitorMcu
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir

$pythonBin = "D:\esp\.espressif\python_env\idf5.4_py3.11_env\Scripts\python.exe"
if (-not (Test-Path $pythonBin)) {
    $pythonBin = "python"
}

$argsList = @()
if ($Check) { $argsList += "--check" }
if ($PhoneInstall) { $argsList += "--phone-install" }
if ($PhoneScreenshot) { $argsList += "--phone-screenshot" }
if ($PhoneLogs) { $argsList += "--phone-logs" }
if ($PSBoundParameters.ContainsKey('FlashMcu')) {
    if ($FlashMcu) { $argsList += @("--flash-mcu", $FlashMcu) }
    else { $argsList += "--flash-mcu" }
}
if ($PSBoundParameters.ContainsKey('MonitorMcu')) {
    if ($MonitorMcu) { $argsList += @("--monitor-mcu", $MonitorMcu) }
    else { $argsList += "--monitor-mcu" }
}

& $pythonBin terminal_debugger.py $argsList
