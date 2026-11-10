# ESP-IDF v5.4 Root CMakeLists.txt
cmake_minimum_required(VERSION 3.16)

# 显式禁用 ccache，防止 Windows 环境下中文路径触发 std::filesystem 非 ASCII 转码异常
set(CCACHE_ENABLE 0 CACHE BOOL "Disable ccache" FORCE)

# Include ESP-IDF project definition
include($ENV{IDF_PATH}/tools/cmake/project.cmake)

project(nodeESP)
