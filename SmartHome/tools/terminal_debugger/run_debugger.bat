@echo off
chcp 65001 >nul
title 智慧家庭终端与节点全链路调试中心
cd /d "%~dp0"

set PYTHON_BIN=D:\esp\.espressif\python_env\idf5.4_py3.11_env\Scripts\python.exe
if not exist "%PYTHON_BIN%" (
    set PYTHON_BIN=python
)

"%PYTHON_BIN%" terminal_debugger.py %*
if %ERRORLEVEL% neq 0 (
    pause
)
