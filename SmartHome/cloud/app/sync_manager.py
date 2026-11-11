"""
SmartHome Cloud Backend - Real-time Sync & WebSocket Channel Manager
处理全双工长连接管理、增量状态广播、心跳守护与离线检测。
"""

import asyncio
import json
import logging
from typing import Set, Dict, Any, List
from fastapi import WebSocket
from .models import DeviceItem, WebSocketEnvelope
from . import database

logger = logging.getLogger("smarthome.cloud.sync")

class SyncManager:
    def __init__(self):
        self.active_connections: Set[WebSocket] = set()
        self._lock = asyncio.Lock()
        self.on_state_updated = None

    async def connect(self, websocket: WebSocket, client_id: str):
        await websocket.accept()
        async with self._lock:
            self.active_connections.add(websocket)
        logger.info(f"Client connected: {client_id} (Total: {len(self.active_connections)})")

        # 连接建立立即下发全量快照 (Snapshot Sync)
        devices = database.get_all_devices()
        rooms = database.get_rooms()
        snapshot = WebSocketEnvelope(
            type="SNAPSHOT_SYNC",
            payload={
                "server_time": asyncio.get_event_loop().time(),
                "devices": [d.model_dump() for d in devices],
                "rooms": rooms
            }
        )
        await websocket.send_text(snapshot.model_dump_json())

    async def disconnect(self, websocket: WebSocket):
        async with self._lock:
            self.active_connections.discard(websocket)
        logger.info(f"Client disconnected (Remaining: {len(self.active_connections)})")

    async def broadcast(self, message: WebSocketEnvelope, sender: WebSocket = None):
        """广播增量更新到所有已连接的终端与仪表盘"""
        payload_str = message.model_dump_json()
        disconnected = []
        async with self._lock:
            for conn in self.active_connections:
                if conn != sender:
                    try:
                        await conn.send_text(payload_str)
                    except Exception as e:
                        logger.warning(f"Error sending to client: {e}")
                        disconnected.append(conn)

            for dead in disconnected:
                self.active_connections.discard(dead)

    async def handle_incoming(self, websocket: WebSocket, raw_text: str):
        """解析并处理客户端发来的同步数据包"""
        try:
            data = json.loads(raw_text)
            msg_type = data.get("type")
            payload = data.get("payload", {})

            if msg_type == "PING":
                # 心跳响应
                pong = WebSocketEnvelope(type="PONG", payload={"ack": True})
                await websocket.send_text(pong.model_dump_json())

            elif msg_type == "STATE_UPDATE":
                # 终端上报设备状态变更
                dev_id = payload.get("device_id")
                new_state = payload.get("state", {})
                src = payload.get("src", "terminal")
                if dev_id:
                    updated_dev = database.update_device_state(dev_id, new_state, src=src)
                    if updated_dev:
                        # 广播增量变更给其余终端
                        broadcast_msg = WebSocketEnvelope(
                            type="STATE_UPDATE",
                            payload={
                                "device_id": dev_id,
                                "state": updated_dev.state,
                                "src": src,
                                "updated_at": updated_dev.updated_at
                            }
                        )
                        await self.broadcast(broadcast_msg, sender=websocket)
                        if self.on_state_updated:
                            await self.on_state_updated(updated_dev, new_state, src)

            elif msg_type == "SYNC_UPLOAD":
                # 终端全量上报（如终端首次启动或手动触发全量同步）
                devices_data = payload.get("devices", [])
                rooms_data = payload.get("rooms", [])
                if rooms_data:
                    database.save_rooms(rooms_data)
                
                device_items = [DeviceItem(**d) for d in devices_data]
                database.upsert_devices_batch(device_items)
                
                # 回送同步完成 ACK
                ack_msg = WebSocketEnvelope(
                    type="SYNC_ACK",
                    payload={"synced_count": len(device_items), "status": "ok"}
                )
                await websocket.send_text(ack_msg.model_dump_json())
                
                # 广播最新全量快照给其他可能在线的客户端
                broadcast_msg = WebSocketEnvelope(
                    type="SNAPSHOT_SYNC",
                    payload={
                        "devices": [d.model_dump() for d in database.get_all_devices()],
                        "rooms": database.get_rooms()
                    }
                )
                await self.broadcast(broadcast_msg, sender=websocket)

            elif msg_type == "COMMAND":
                # 下发控制指令
                dev_id = payload.get("device_id")
                cmd = payload.get("cmd")
                args = payload.get("args", {})
                logger.info(f"Executing Cloud Command on {dev_id}: {cmd} with {args}")
                # 广播给受控终端执行
                await self.broadcast(WebSocketEnvelope(type="COMMAND", payload=payload), sender=websocket)

        except Exception as e:
            logger.error(f"Failed to process message: {e}", exc_info=True)

sync_manager = SyncManager()
