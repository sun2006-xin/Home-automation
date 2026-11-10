"""
SmartHome Cloud Backend - Configuration Settings
支持环境变量注入，适用于本地开发测试及公网云端服务器 (Alibaba Cloud, Tencent Cloud, AWS 等) 容器化部署。
"""

import os
from pathlib import Path
from pydantic import BaseModel

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "data"
DATA_DIR.mkdir(parents=True, exist_ok=True)

class CloudConfig(BaseModel):
    # 服务网络绑定
    HOST: str = os.getenv("SMARTHOME_CLOUD_HOST", "0.0.0.0")
    PORT: int = int(os.getenv("SMARTHOME_CLOUD_PORT", "8000"))
    
    # 租户与家庭标识
    HOME_ID: str = os.getenv("SMARTHOME_HOME_ID", "h01")
    
    # 安全凭证
    AUTH_TOKEN: str = os.getenv("SMARTHOME_CLOUD_TOKEN", "smarthome_cloud_secret_token_2026")
    
    # 数据持久化
    DB_PATH: str = str(DATA_DIR / "smarthome_cloud.db")
    
    # 消息总线 MQTT 桥接配置 (可选连接到远程或本地 Mosquitto/EMQX)
    ENABLE_MQTT_BRIDGE: bool = os.getenv("ENABLE_MQTT_BRIDGE", "false").lower() in ("true", "1", "yes")
    MQTT_BROKER_HOST: str = os.getenv("MQTT_BROKER_HOST", "127.0.0.1")
    MQTT_BROKER_PORT: int = int(os.getenv("MQTT_BROKER_PORT", "1883"))
    MQTT_USERNAME: str = os.getenv("MQTT_USERNAME", "")
    MQTT_PASSWORD: str = os.getenv("MQTT_PASSWORD", "")

    # 心跳与超时 (秒)
    HEARTBEAT_INTERVAL: int = 15
    CLIENT_TIMEOUT: int = 45

config = CloudConfig()
