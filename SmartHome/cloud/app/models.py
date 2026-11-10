"""
SmartHome Cloud Backend - Domain Models & Data Transfer Objects (DTO)
严格数据校验与契约约束，生产级标准设计。
"""

from typing import Dict, Any, List, Optional
from pydantic import BaseModel, Field
import time

class DeviceState(BaseModel):
    on: Optional[bool] = None
    pos: Optional[int] = Field(None, ge=0, le=100)
    targetTemp: Optional[float] = None
    mode: Optional[str] = None
    powerWatts: Optional[float] = None
    heating: Optional[bool] = None
    remainingMinutes: Optional[int] = None
    temperature: Optional[float] = None
    humidity: Optional[float] = None
    online: bool = True
    extra: Dict[str, Any] = Field(default_factory=dict)

class DeviceItem(BaseModel):
    id: str
    name: str
    room: str
    type: str  # 'switch', 'climate', 'cover', 'heater', 'sensor'
    subtype: Optional[str] = None  # 'light', 'fan', 'socket' 等
    state: Dict[str, Any] = Field(default_factory=dict)
    updated_at: float = Field(default_factory=time.time)

class StateUpdatePayload(BaseModel):
    device_id: str
    state: Dict[str, Any]
    src: str = "terminal"
    timestamp: float = Field(default_factory=time.time)

class SyncBatchRequest(BaseModel):
    client_id: str
    home_id: str = "h01"
    timestamp: float = Field(default_factory=time.time)
    devices: List[DeviceItem]
    rooms: Optional[List[str]] = None

class SyncBatchResponse(BaseModel):
    success: bool
    server_time: float
    synced_count: int
    devices: List[DeviceItem]
    rooms: List[str]

class WebSocketEnvelope(BaseModel):
    type: str  # 'CONNECT', 'PING', 'PONG', 'SNAPSHOT_SYNC', 'STATE_UPDATE', 'COMMAND', 'ERROR'
    payload: Dict[str, Any] = Field(default_factory=dict)
    timestamp: float = Field(default_factory=time.time)
