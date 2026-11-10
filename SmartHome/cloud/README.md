# SmartHome Cloud Hub · 工业级智慧家庭公网云端中枢

> **定位与第一性原理**：云端本质上就是一台具备公网 IP 的远端服务器。本系统**坚决摒弃**受限于单一 Wi-Fi 路由器的局域网 UDP 广播/组播机制（局域网广播在跨网、4G/5G、跨 NAT 路由器以及云服务器部署时会 100% 彻底瘫痪）。
> 
> 本中枢采用 **标准公网可路由协议族（RESTful API + 全双工 WebSocket 长连接 + MQTT 桥接）**，天然支持家庭 NAT 穿透。终端与边缘节点只需出站发起 TCP/WSS 握手，即可实现毫秒级双向遥控与状态同步。

---

## 1. 核心架构与通信拓扑

```
[手机中控终端 / Kiosk] ──WebSocket (Duplex)──┐
                                             │
[Web 远程仪表盘]      ──REST & WebSocket────┼──→ 【SmartHome Cloud Hub】(FastAPI 异步微服务)
                                             │         │
[ESP32 / MCU 节点]    ──MQTT / Bridge───────┘         ├── SQLite / WAL 预写日志持久化
                                                       ├── 遥测时序与审计追踪
                                                       └── 增量广播调度器 (SyncManager)
```

### 1.1 协议规范与端口规划

| 协议 | 端口 | 用途 | 说明 |
| :--- | :--- | :--- | :--- |
| **HTTP / REST** | `8000` (开发) / `443` (生产 HTTPS) | 设备检索、全量批量同步、健康检查 | 无状态请求，带 Bearer Token 鉴权 |
| **WebSocket** | `/ws/terminal` | 终端双向实时流式同步、毫秒级下发与上报 | 主动出站穿透 NAT，自带 15s 心跳探测与自动重连 |
| **MQTT** | `1883` / `8883` (TLS) | ESP32-C3 边缘节点与专用介质总线接入 | 标准 `sh/{home}/{dev}/state` 与 `cmd` 主题 |

---

## 2. 快速启动与本地测试

当前开发阶段，本地电脑即充当“云端服务器”运行本中枢：

### 2.1 本地单机运行

```bash
cd SmartHome/cloud
# 安装依赖
pip install -r requirements.txt
# 启动云服务
python run_cloud.py
```
启动后即可访问：
- **Web 可视化控制台**：`http://localhost:8000/`
- **Swagger API 文档**：`http://localhost:8000/docs`
- **健康检查**：`http://localhost:8000/health`

---

## 3. 生产级公网 VPS 部署指南（阿里云 / 腾讯云 / AWS）

本目录包含完整的生产级 `Dockerfile` 与 `docker-compose.yml`，在云端 Linux VPS 上只需 **1 条命令** 即可容器化运行：

### 3.1 一键容器部署

```bash
cd SmartHome/cloud
docker compose up -d
```

### 3.2 环境变量配置 (`.env` 或 Docker Compose)

```ini
SMARTHOME_CLOUD_HOST=0.0.0.0
SMARTHOME_CLOUD_PORT=8000
SMARTHOME_HOME_ID=h01
SMARTHOME_CLOUD_TOKEN=smarthome_cloud_secret_token_2026
ENABLE_MQTT_BRIDGE=false
```

### 3.3 终端无缝切换上云

终端（手机/中控屏）代码无需改动任何一行。在终端界面的 **【工程设置】->【☁️ 云端同步与远程部署】** 中：
1. 将 **云端服务器 IP / 域名** 改为您的公网服务器 IP（如 `47.100.xx.xx`）或解析好的域名（如 `cloud.mysmarthome.com`）；
2. 点击 **【连接云端】**，即刻完成与公网云中枢的实时握手与双向同步！

---

## 4. 关键 API 接口清单

| 方法 | 路径 | 描述 |
| :--- | :--- | :--- |
| `GET` | `/health` | 服务健康与存活探测 |
| `GET` | `/api/v1/cloud/info` | 云端基本信息、在线终端数与通信协议状态 |
| `GET` | `/api/v1/devices` | 获取云端全屋电器最新状态列表 |
| `POST` | `/api/v1/devices/{id}/state` | 修改单台设备状态（自动持久化并实时广播全网） |
| `POST` | `/api/v1/sync` | 终端全量设备与房间配置镜像上传 / 同步 |
| `GET` | `/api/v1/telemetry/{id}` | 查询指定设备历史状态变化时序日志 |
| `WS` | `/ws/terminal` | 终端全双工实时同步管道（`client_id`, `home_id`） |
