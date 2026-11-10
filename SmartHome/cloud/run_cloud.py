"""
SmartHome Cloud Backend - Local/Production Launcher
一键启动云端中枢服务
"""

import sys
import uvicorn
from pathlib import Path

# 添加当前目录至模块搜索路径
cur_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(cur_dir))

from app.config import config

if __name__ == "__main__":
    print(f"===========================================================")
    print(f"  SmartHome Cloud Hub 正在启动...")
    print(f"  服务监听: http://{config.HOST}:{config.PORT}")
    print(f"  Web 控制台: http://localhost:{config.PORT}")
    print(f"  数据存储: {config.DB_PATH}")
    print(f"===========================================================")
    uvicorn.run("app.main:app", host=config.HOST, port=config.PORT, reload=False)
