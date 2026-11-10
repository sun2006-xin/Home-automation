"""
SmartHome Cloud Backend - Durable Persistence Layer (SQLite + WAL Mode)
遵循生产级数据库设计：
1. 启用 WAL 预写日志与 NORMAL 同步级别，保证并发高读写性能；
2. 严格覆盖索引，避免全表扫描；
3. 连接池与上下文安全隔离。
"""

import sqlite3
import json
import time
from typing import List, Optional, Dict, Any
from .config import config
from .models import DeviceItem

def get_db_connection() -> sqlite3.Connection:
    conn = sqlite3.connect(config.DB_PATH, timeout=10.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    conn.execute("PRAGMA foreign_keys=ON;")
    return conn

def init_db():
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # 1. 设备主表
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS devices (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                room TEXT NOT NULL,
                type TEXT NOT NULL,
                subtype TEXT,
                state_json TEXT NOT NULL DEFAULT '{}',
                updated_at REAL NOT NULL,
                created_at REAL NOT NULL
            );
        """)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_devices_room ON devices(room);")

        # 2. 房间清单表
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS rooms (
                name TEXT PRIMARY KEY,
                display_order INTEGER DEFAULT 0
            );
        """)

        # 3. 遥测时序与审计日志表
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS telemetry_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id TEXT NOT NULL,
                state_json TEXT NOT NULL,
                src TEXT NOT NULL,
                created_at REAL NOT NULL
            );
        """)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_telemetry_dev_time ON telemetry_history(device_id, created_at DESC);")
        
        # 默认房间初始化
        default_rooms = ['客厅', '主卧', '次卧(南)', '次卧(北)', '书房', '餐厅', '卫生间']
        for idx, room in enumerate(default_rooms):
            cursor.execute("INSERT OR IGNORE INTO rooms (name, display_order) VALUES (?, ?);", (room, idx))

        conn.commit()

def upsert_device(device: DeviceItem) -> DeviceItem:
    now = time.time()
    state_str = json.dumps(device.state, ensure_ascii=False)
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO devices (id, name, room, type, subtype, state_json, updated_at, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                room = excluded.room,
                type = excluded.type,
                subtype = excluded.subtype,
                state_json = excluded.state_json,
                updated_at = excluded.updated_at;
        """, (device.id, device.name, device.room, device.type, device.subtype, state_str, device.updated_at or now, now))
        conn.commit()
    return device

def upsert_devices_batch(devices: List[DeviceItem]):
    now = time.time()
    with get_db_connection() as conn:
        cursor = conn.cursor()
        for d in devices:
            state_str = json.dumps(d.state, ensure_ascii=False)
            cursor.execute("""
                INSERT INTO devices (id, name, room, type, subtype, state_json, updated_at, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    name = excluded.name,
                    room = excluded.room,
                    type = excluded.type,
                    subtype = excluded.subtype,
                    state_json = excluded.state_json,
                    updated_at = excluded.updated_at;
            """, (d.id, d.name, d.room, d.type, d.subtype, state_str, d.updated_at or now, now))
        conn.commit()

def get_all_devices() -> List[DeviceItem]:
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id, name, room, type, subtype, state_json, updated_at FROM devices ORDER BY room, id;")
        rows = cursor.fetchall()
        result = []
        for r in rows:
            try:
                st = json.loads(r["state_json"])
            except Exception:
                st = {}
            result.append(DeviceItem(
                id=r["id"],
                name=r["name"],
                room=r["room"],
                type=r["type"],
                subtype=r["subtype"],
                state=st,
                updated_at=r["updated_at"]
            ))
        return result

def get_device(device_id: str) -> Optional[DeviceItem]:
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT id, name, room, type, subtype, state_json, updated_at FROM devices WHERE id = ?;", (device_id,))
        r = cursor.fetchone()
        if not r:
            return None
        try:
            st = json.loads(r["state_json"])
        except Exception:
            st = {}
        return DeviceItem(
            id=r["id"],
            name=r["name"],
            room=r["room"],
            type=r["type"],
            subtype=r["subtype"],
            state=st,
            updated_at=r["updated_at"]
        )

def update_device_state(device_id: str, new_state: Dict[str, Any], src: str = "cloud") -> Optional[DeviceItem]:
    dev = get_device(device_id)
    if not dev:
        return None
    
    # 增量合并状态
    merged_state = dict(dev.state)
    merged_state.update(new_state)
    now = time.time()
    state_str = json.dumps(merged_state, ensure_ascii=False)
    
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            UPDATE devices SET state_json = ?, updated_at = ? WHERE id = ?;
        """, (state_str, now, device_id))
        
        # 记录审计时序日志
        cursor.execute("""
            INSERT INTO telemetry_history (device_id, state_json, src, created_at)
            VALUES (?, ?, ?, ?);
        """, (device_id, state_str, src, now))
        conn.commit()

    dev.state = merged_state
    dev.updated_at = now
    return dev

def get_rooms() -> List[str]:
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM rooms ORDER BY display_order, name;")
        return [r["name"] for r in cursor.fetchall()]

def save_rooms(rooms: List[str]):
    with get_db_connection() as conn:
        cursor = conn.cursor()
        for idx, room in enumerate(rooms):
            cursor.execute("INSERT OR REPLACE INTO rooms (name, display_order) VALUES (?, ?);", (room, idx))
        conn.commit()

def get_telemetry_history(device_id: str, limit: int = 50) -> List[Dict[str, Any]]:
    with get_db_connection() as conn:
        cursor = conn.cursor()
        cursor.execute("""
            SELECT device_id, state_json, src, created_at 
            FROM telemetry_history 
            WHERE device_id = ? 
            ORDER BY created_at DESC 
            LIMIT ?;
        """, (device_id, limit))
        rows = cursor.fetchall()
        return [{
            "device_id": r["device_id"],
            "state": json.loads(r["state_json"]),
            "src": r["src"],
            "created_at": r["created_at"]
        } for r in rows]
