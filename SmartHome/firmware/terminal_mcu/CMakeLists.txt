# ESP-IDF v5.4 Root CMakeLists.txt for MCU Smart Terminal
cmake_minimum_required(VERSION 3.16)

# 显式禁用 ccache，防止 Windows 环境下中文路径触发编码异常
set(CCACHE_ENABLE 0 CACHE BOOL "Disable ccache" FORCE)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(terminal_mcu)
