"""
SmartHome Cloud Backend - Production Gateway Entrypoint
基于 FastAPI + WebSocket 的高并发异步中枢服务，云原生容器化就绪。
"""

import json
import time
import logging
from contextlib import asynccontextmanager
from typing import Any, Dict, List, Optional
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Header, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from .config import config, BASE_DIR
from .models import (
    DeviceItem, StateUpdatePayload, SyncBatchRequest, SyncBatchResponse, WebSocketEnvelope
)
from . import database
from .sync_manager import sync_manager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("smarthome.cloud")

import asyncio
from . import rules_engine
from .mqtt_bridge import mqtt_bridge

start_time = time.time()


async def _dispatch_mqtt_state(device_id: str, delta_state: Dict[str, Any], src: str) -> Optional[DeviceItem]:
    """处理物理节点或模拟器通过 MQTT 上报的状态（不回传 MQTT）。"""
    return await apply_state_change(device_id, delta_state, src=src)


async def _dispatch_mqtt_discovery(doc: Dict[str, Any]) -> None:
    """处理物理节点上线自注册 `_discovery` 报文。"""
    item = DeviceItem(
        id=str(doc["id"]),
        name=str(doc.get("name") or doc["id"]),
        room=str(doc.get("room") or "未分配"),
        type=str(doc.get("type") or "switch"),
        subtype=doc.get("subtype"),
        state=dict(doc.get("state") or {"online": True}),
    )
    database.upsert_device(item)
    all_devs = database.get_all_devices()
    all_rooms = database.get_rooms()
    await sync_manager.broadcast(
        WebSocketEnvelope(
            type="SNAPSHOT_SYNC",
            payload={
                "src": f"mqtt:discovery:{item.id}",
                "devices": [d.model_dump() for d in all_devs],
                "rooms": all_rooms,
            },
        )
    )


async def _on_ws_state_updated(updated_dev: DeviceItem, delta_state: Dict[str, Any], src: str) -> None:
    mqtt_bridge.publish_device_command(updated_dev.id, delta_state, src=src)
    await rules_engine.rules_engine.evaluate_for_device(updated_dev, delta_state, src=src)


async def _on_rule_triggered(event_payload: Dict[str, Any]) -> None:
    await sync_manager.broadcast(WebSocketEnvelope(type="RULE_TRIGGERED", payload=event_payload))


async def apply_state_change(
    device_id: str,
    delta_state: Dict[str, Any],
    src: str = "cloud",
    exclude_ws: Any = None,
) -> Optional[DeviceItem]:
    """统一状态变更与联动调度管线。"""
    updated_dev = database.update_device_state(device_id, delta_state, src=src)
    if not updated_dev:
        return None

    await sync_manager.broadcast(
        WebSocketEnvelope(
            type="STATE_UPDATE",
            payload={
                "device_id": device_id,
                "state": updated_dev.state,
                "src": src,
                "updated_at": updated_dev.updated_at,
            },
        ),
        sender=exclude_ws,
    )
    mqtt_bridge.publish_device_command(device_id, delta_state, src=src)
    await rules_engine.rules_engine.evaluate_for_device(updated_dev, delta_state, src=src)
    return updated_dev

@asynccontextmanager
async def lifespan(app: FastAPI):
    # 启动初始化
    logger.info("Initializing SmartHome Cloud Database...")
    database.init_db()
    rules_engine.init_rules_schema()
    sync_manager.on_state_updated = _on_ws_state_updated
    rules_engine.rules_engine.configure(
        action_executor=lambda dev_id, st, src: apply_state_change(dev_id, st, src=src),
        notifier=_on_rule_triggered,
    )
    mqtt_bridge.configure_callbacks(
        loop=asyncio.get_running_loop(),
        on_state=_dispatch_mqtt_state,
        on_discovery=_dispatch_mqtt_discovery,
    )
    mqtt_bridge.start()
    
    # 检查是否已有初始设备，如无则写入基础全屋电器蓝本
    existing = database.get_all_devices()
    if not existing:
        logger.info("Seeding initial smart home devices template...")
        seed_devices = [
            DeviceItem(id="L01", name="客厅主灯", room="客厅", type="switch", subtype="light", state={"on": True}),
            DeviceItem(id="AC01", name="客厅立柜空调", room="客厅", type="climate", subtype="air_conditioner", state={"on": True, "targetTemp": 26.0, "mode": "cool"}),
            DeviceItem(id="C01", name="客厅主窗帘", room="客厅", type="cover", subtype="curtain", state={"pos": 80}),
            DeviceItem(id="L02", name="主卧吸顶灯", room="主卧", type="switch", subtype="light", state={"on": False}),
            DeviceItem(id="AC02", name="主卧变频空调", room="主卧", type="climate", subtype="air_conditioner", state={"on": False, "targetTemp": 25.0, "mode": "cool"}),
            DeviceItem(id="C02", name="主卧遮光帘", room="主卧", type="cover", subtype="curtain", state={"pos": 0}),
            DeviceItem(id="L03", name="南卧护眼灯", room="次卧(南)", type="switch", subtype="light", state={"on": True}),
            DeviceItem(id="AC03", name="南卧冷暖空调", room="次卧(南)", type="climate", subtype="air_conditioner", state={"on": False, "targetTemp": 26.0, "mode": "cool"}),
            DeviceItem(id="L04", name="北卧吸顶灯", room="次卧(北)", type="switch", subtype="light", state={"on": False}),
            DeviceItem(id="L05", name="餐厅艺术吊灯", room="餐厅", type="switch", subtype="light", state={"on": False}),
            DeviceItem(id="F01", name="餐厅静音风扇", room="餐厅", type="switch", subtype="fan", state={"on": True}),
            DeviceItem(id="L06", name="书房吸顶灯", room="书房", type="switch", subtype="light", state={"on": False}),
            DeviceItem(id="S01", name="书房智能排插", room="书房", type="switch", subtype="socket", state={"on": True}),
            DeviceItem(id="H01", name="储水热水器", room="卫生间", type="heater", subtype="water_heater", state={"on": True, "powerWatts": 1980.0, "heating": True, "remainingMinutes": 15}),
            DeviceItem(id="L07", name="镜前防雾灯", room="卫生间", type="switch", subtype="light", state={"on": False}),
        ]
        database.upsert_devices_batch(seed_devices)
    
    logger.info(f"SmartHome Cloud Backend Started on {config.HOST}:{config.PORT}")
    yield
    mqtt_bridge.stop()
    logger.info("SmartHome Cloud Backend Shutting Down...")

app = FastAPI(
    title="SmartHome Cloud Hub",
    description="工业级智慧家庭公网云端中枢 API · 支持手机中控与 MCU 跨网络数据双向同步",
    version="2.1.0",
    lifespan=lifespan
)

# 允许跨域（方便开发调试与远程 Web 仪表盘调用）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 挂载静态文件目录
STATIC_DIR = BASE_DIR / "static"
STATIC_DIR.mkdir(parents=True, exist_ok=True)
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")

# 认证验证辅助函数
def verify_token(x_token: Optional[str] = Header(None), token: Optional[str] = Query(None)):
    req_token = x_token or token
    if config.AUTH_TOKEN and req_token != config.AUTH_TOKEN:
        # 开发模式下如果没有提供且为默认 token 则允许
        if not req_token and config.AUTH_TOKEN == "smarthome_cloud_secret_token_2026":
            return
        raise HTTPException(status_code=401, detail="Invalid Authentication Token")

# --- 核心接口 ---

@app.get("/health")
def health_check():
    """云端健康检查"""
    return {
        "status": "online",
        "service": "SmartHome Cloud Hub",
        "version": "2.1.0",
        "uptime_seconds": round(time.time() - start_time, 2),
        "active_ws_clients": len(sync_manager.active_connections)
    }

@app.get("/api/v1/cloud/info")
def get_cloud_info():
    """获取云端基本拓扑信息与连接能力"""
    devices = database.get_all_devices()
    rooms = database.get_rooms()
    return {
        "server_time": time.time(),
        "home_id": config.HOME_ID,
        "device_count": len(devices),
        "room_count": len(rooms),
        "active_clients": len(sync_manager.active_connections),
        "mqtt_bridge_enabled": config.ENABLE_MQTT_BRIDGE,
        "mqtt_status": mqtt_bridge.status(),
        "rules_count": len(rules_engine.list_rules()),
        "protocols_supported": ["REST/JSON", "WebSocket/Duplex", "MQTT/1883"]
    }

@app.get("/api/v1/devices", response_model=List[DeviceItem])
def list_devices():
    """获取云端最新全量设备与运行状态"""
    return database.get_all_devices()

@app.get("/api/v1/devices/{device_id}", response_model=DeviceItem)
def get_device_detail(device_id: str):
    """查询单台设备详情与当前状态"""
    dev = database.get_device(device_id)
    if not dev:
        raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
    return dev

@app.post("/api/v1/devices/{device_id}/state", response_model=DeviceItem)
async def update_device_state_api(device_id: str, payload: StateUpdatePayload):
    """
    修改或下发设备状态（云端/手机/控制台统一入口）
    自动触发数据持久化与所有连接端（手机终端、Web 面板）实时全双工广播
    """
    updated_dev = await apply_state_change(device_id, payload.state, src=payload.src)
    if not updated_dev:
        raise HTTPException(status_code=404, detail=f"Device {device_id} not found")
    return updated_dev

@app.post("/api/v1/sync", response_model=SyncBatchResponse)
async def sync_batch(req: SyncBatchRequest):
    """
    终端与云端全量数据同步通道
    用于终端将本地添加的新电器、新房间布局全量镜像上云，或拉取云端数据
    """
    if req.rooms:
        database.save_rooms(req.rooms)
    
    if req.devices:
        database.upsert_devices_batch(req.devices)
    
    all_devs = database.get_all_devices()
    all_rooms = database.get_rooms()

    # 广播通知其余终端
    await sync_manager.broadcast(WebSocketEnvelope(
        type="SNAPSHOT_SYNC",
        payload={
            "devices": [d.model_dump() for d in all_devs],
            "rooms": all_rooms
        }
    ))

    return SyncBatchResponse(
        success=True,
        server_time=time.time(),
        synced_count=len(req.devices),
        devices=all_devs,
        rooms=all_rooms
    )

@app.get("/api/v1/rooms")
def get_rooms():
    """获取所有房间分类"""
    return database.get_rooms()

@app.get("/api/v1/telemetry/{device_id}")
def get_telemetry(device_id: str, limit: int = 50):
    """获取指定设备的历史状态变化轨迹"""
    return database.get_telemetry_history(device_id, limit=limit)

SCENE_NAMES = {
    "home": "回家模式",
    "away": "离家警戒",
    "sleep": "舒适睡眠",
    "all_off": "一键全关",
    "all_lights_off": "全屋关灯",
    "all_lights_on": "全屋照明",
}

def _resolve_scene_state(scene_id: str, dev: DeviceItem) -> Optional[dict]:
    """Compute target state delta for a device under a scene trigger."""
    if scene_id == "home":
        if dev.type == "cover":
            return {"pos": 100}
        if dev.id == "L01" or (dev.room == "客厅" and dev.subtype == "light"):
            return {"on": True}
        if dev.id == "AC01":
            return {"on": True}
    elif scene_id == "away":
        if dev.type in ("switch", "climate"):
            return {"on": False}
        if dev.type == "cover":
            return {"pos": 0}
    elif scene_id == "sleep":
        if dev.type == "switch":
            return {"on": False}
        if dev.type == "cover":
            return {"pos": 0}
        if dev.type == "climate":
            if dev.room == "主卧":
                return {"on": True, "targetTemp": 26.0, "mode": "cool"}
            return {"on": False}
    elif scene_id == "all_off":
        if dev.type in ("switch", "climate", "heater"):
            return {"on": False}
    elif scene_id == "all_lights_off":
        if dev.type == "switch" and dev.subtype == "light":
            return {"on": False}
    elif scene_id == "all_lights_on":
        if dev.type == "switch" and dev.subtype == "light":
            return {"on": True}
    return None

@app.post("/api/v1/scenes/{scene_id}/trigger")
async def trigger_scene(scene_id: str, src: str = Query("cloud")):
    """触发全屋快捷场景并同步广播至所有云端及终端节点"""
    if scene_id not in SCENE_NAMES:
        raise HTTPException(status_code=404, detail=f"Unknown scene: {scene_id}")

    devices = database.get_all_devices()
    updated_ids: List[str] = []
    for dev in devices:
        delta = _resolve_scene_state(scene_id, dev)
        if delta is not None:
            database.update_device_state(dev.id, delta, src=f"{src}:scene:{scene_id}")
            mqtt_bridge.publish_device_command(dev.id, delta, src=f"{src}:scene:{scene_id}")
            updated_ids.append(dev.id)

    all_devs = database.get_all_devices()
    all_rooms = database.get_rooms()
    await sync_manager.broadcast(WebSocketEnvelope(
        type="SNAPSHOT_SYNC",
        payload={
            "scene_id": scene_id,
            "scene_name": SCENE_NAMES[scene_id],
            "src": src,
            "devices": [d.model_dump() for d in all_devs],
            "rooms": all_rooms
        }
    ))

    return {
        "success": True,
        "scene_id": scene_id,
        "scene_name": SCENE_NAMES[scene_id],
        "updated_count": len(updated_ids),
        "updated_ids": updated_ids,
        "devices": all_devs,
    }

app.include_router(rules_engine.router)


@app.get("/api/v1/mqtt/status")
def get_mqtt_status():
    """查询云端 MQTT 桥接连接态与收发统计"""
    return mqtt_bridge.status()


@app.post("/api/v1/simulator/node-event")
async def simulate_node_event(body: Dict[str, Any]):
    """
    硬件节点测试台（无物理 ESP32-S3/C3 接入时，按真实 MQTT 主题载荷注入上行报文）
    """
    topic = body.get("topic")
    if not topic:
        dev_id = body.get("device_id", "C01")
        channel = body.get("channel", "state")
        topic = f"sh/{config.HOME_ID}/{dev_id}/{channel}"

    payload = body.get("payload", {})
    raw_payload = payload if isinstance(payload, str) else json.dumps(payload, ensure_ascii=False)
    res = await mqtt_bridge.process_message(topic, raw_payload)
    if not res.get("handled"):
        raise HTTPException(status_code=400, detail=res.get("reason", "Invalid MQTT simulation event"))
    return {"success": True, "topic": topic, **res}


# --- WebSocket 终端长连接信道 ---

@app.websocket("/ws/terminal")
async def websocket_terminal_endpoint(
    websocket: WebSocket,
    client_id: str = Query("terminal_client"),
    home_id: str = Query("h01")
):
    """
    全双工低延迟长连接信道：
    1. 自动穿透 NAT（客户端主动出站直连云端）；
    2. 支持瞬时增量上报与下发；
    3. 毫秒级双向感知。
    """
    await sync_manager.connect(websocket, client_id)
    try:
        while True:
            data_text = await websocket.receive_text()
            await sync_manager.handle_incoming(websocket, data_text)
    except WebSocketDisconnect:
        await sync_manager.disconnect(websocket)
    except Exception as e:
        logger.warning(f"WebSocket unexpected error: {e}")
        await sync_manager.disconnect(websocket)

@app.get("/", response_class=HTMLResponse)
def index_page():
    """云端可视化控制台主页"""
    dashboard_html = STATIC_DIR / "index.html"
    if dashboard_html.exists():
        return FileResponse(dashboard_html)
    return "<h1>SmartHome Cloud Hub Online</h1>"
