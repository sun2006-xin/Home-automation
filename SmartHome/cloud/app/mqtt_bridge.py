"""
SmartHome Cloud Backend - MQTT Hardware Bus Bridge (Phase M2)
对接 ESP32-S3 / ESP32-C3 硬件节点的 `sh/{home_id}/{device_id}/{online|state|cmd|_discovery}` 协议。
支持作为后台桥接客户端连接至外部 Mosquitto/EMQX，并在未启用外部 Broker 时提供纯解析/调试能力。
"""

from __future__ import annotations

import asyncio
import json
import logging
from typing import Any, Awaitable, Callable, Dict, Optional, Tuple

import paho.mqtt.client as mqtt

from .config import config

logger = logging.getLogger("smarthome.cloud.mqtt")

ALLOWED_CHANNELS = frozenset({"online", "state", "cmd", "_discovery"})

StateCallback = Callable[[str, Dict[str, Any], str], Awaitable[Any]]
DiscoveryCallback = Callable[[Dict[str, Any]], Awaitable[Any]]


def parse_mqtt_topic(topic: str) -> Optional[Tuple[str, str, str]]:
    """解析节点主题 `sh/{home_id}/{device_id}/{channel}`，非法格式返回 None。"""
    if not topic or not isinstance(topic, str):
        return None
    parts = topic.strip().split("/")
    if len(parts) != 4 or parts[0] != "sh":
        return None
    _, home_id, device_id, channel = parts
    if not home_id or not device_id or channel not in ALLOWED_CHANNELS:
        return None
    return home_id, device_id, channel


def normalize_incoming_payload(channel: str, raw_payload: str) -> Optional[Dict[str, Any]]:
    """
    将节点上行 MQTT 负载标准化为 Cloud 设备 state 增量字典。
    - `online`: `"1"` / `"true"` -> `{"online": True}`, `"0"` / `"false"` -> `{"online": False}`
    - `state`: 支持包壳格式 `{"v":1,"d":"C01","st":{"pos":50}}` 与扁平 JSON 格式
    """
    text = (raw_payload or "").strip()
    if channel == "online":
        low = text.lower()
        if low in ("1", "true", "online"):
            return {"online": True}
        if low in ("0", "false", "offline"):
            return {"online": False}
        logger.warning("Ignoring malformed MQTT online payload: %r", text)
        return None

    if channel == "state":
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError as exc:
            logger.warning("Ignoring invalid JSON on MQTT state topic: %s (%r)", exc, text)
            return None
        if not isinstance(parsed, dict):
            return None
        if isinstance(parsed.get("st"), dict):
            state_delta = dict(parsed["st"])
        else:
            state_delta = {k: v for k, v in parsed.items() if k not in ("v", "d", "ts")}
        state_delta.setdefault("online", True)
        return state_delta

    if channel == "_discovery":
        try:
            parsed = json.loads(text)
        except json.JSONDecodeError as exc:
            logger.warning("Ignoring invalid JSON on MQTT _discovery topic: %s (%r)", exc, text)
            return None
        return parsed if isinstance(parsed, dict) else None

    return None


class MqttBridge:
    """管理 Cloud 与本地/远程 MQTT Broker 的双向桥接。"""

    def __init__(self) -> None:
        self._client: Optional[mqtt.Client] = None
        self._loop: Optional[asyncio.AbstractEventLoop] = None
        self._on_state: Optional[StateCallback] = None
        self._on_discovery: Optional[DiscoveryCallback] = None
        self._connected: bool = False
        self._last_error: Optional[str] = None
        self.rx_count: int = 0
        self.tx_count: int = 0

    def configure_callbacks(
        self,
        loop: Optional[asyncio.AbstractEventLoop],
        on_state: StateCallback,
        on_discovery: Optional[DiscoveryCallback] = None,
    ) -> None:
        self._loop = loop
        self._on_state = on_state
        self._on_discovery = on_discovery

    def _create_paho_client(self) -> mqtt.Client:
        client_id = f"smarthome_cloud_{config.HOME_ID}"
        if hasattr(mqtt, "CallbackAPIVersion"):
            client = mqtt.Client(
                callback_api_version=mqtt.CallbackAPIVersion.VERSION2,
                client_id=client_id,
            )
            client.on_connect = self._handle_connect_v2
            client.on_disconnect = self._handle_disconnect_v2
        else:
            client = mqtt.Client(client_id=client_id)
            client.on_connect = self._handle_connect_v1
            client.on_disconnect = self._handle_disconnect_v1
        client.on_message = self._handle_message
        return client

    def _subscribe_topics(self, client: mqtt.Client) -> None:
        prefix = f"sh/{config.HOME_ID}/+"
        for ch in ("online", "state", "_discovery"):
            client.subscribe(f"{prefix}/{ch}", qos=1)
        logger.info("MQTT Bridge subscribed to %s/{online,state,_discovery}", prefix)

    def _handle_connect_v1(self, client: mqtt.Client, userdata: Any, flags: Any, rc: int) -> None:
        if rc == 0:
            self._connected = True
            self._last_error = None
            self._subscribe_topics(client)
        else:
            self._connected = False
            self._last_error = f"MQTT connect refused rc={rc}"
            logger.error(self._last_error)

    def _handle_connect_v2(
        self, client: mqtt.Client, userdata: Any, flags: Any, reason_code: Any, properties: Any = None
    ) -> None:
        if not getattr(reason_code, "is_failure", False):
            self._connected = True
            self._last_error = None
            self._subscribe_topics(client)
        else:
            self._connected = False
            self._last_error = f"MQTT connect refused: {reason_code}"
            logger.error(self._last_error)

    def _handle_disconnect_v1(self, client: mqtt.Client, userdata: Any, rc: int) -> None:
        self._connected = False
        if rc != 0:
            self._last_error = f"Unexpected disconnect rc={rc}"
            logger.warning("MQTT Bridge disconnected unexpectedly (rc=%s)", rc)

    def _handle_disconnect_v2(
        self, client: mqtt.Client, userdata: Any, disconnect_flags: Any, reason_code: Any, properties: Any = None
    ) -> None:
        self._connected = False
        if getattr(reason_code, "is_failure", False):
            self._last_error = f"Unexpected disconnect: {reason_code}"
            logger.warning("MQTT Bridge disconnected (%s)", reason_code)

    def _handle_message(self, client: mqtt.Client, userdata: Any, msg: mqtt.MQTTMessage) -> None:
        payload_text = msg.payload.decode("utf-8", errors="replace")
        if self._loop and not self._loop.is_closed():
            asyncio.run_coroutine_threadsafe(
                self.process_message(msg.topic, payload_text),
                self._loop,
            )

    async def process_message(self, topic: str, raw_payload: str) -> Dict[str, Any]:
        """解析并分发单条 MQTT 上行消息（可被 Broker 回调与本地模拟器/单测复用）。"""
        parsed_topic = parse_mqtt_topic(topic)
        if not parsed_topic:
            return {"handled": False, "reason": "invalid_topic"}

        home_id, device_id, channel = parsed_topic
        if home_id != config.HOME_ID:
            return {"handled": False, "reason": "home_mismatch"}

        if channel == "cmd":
            return {"handled": False, "reason": "ignored_cmd_echo"}

        normalized = normalize_incoming_payload(channel, raw_payload)
        if normalized is None:
            return {"handled": False, "reason": "invalid_payload"}

        self.rx_count += 1

        if channel == "_discovery":
            if self._on_discovery:
                discovery_doc = dict(normalized)
                discovery_doc.setdefault("id", device_id)
                await self._on_discovery(discovery_doc)
                return {"handled": True, "channel": channel, "device_id": device_id}
            return {"handled": False, "reason": "no_discovery_handler"}

        if self._on_state:
            await self._on_state(device_id, normalized, f"mqtt:{channel}")
            return {
                "handled": True,
                "channel": channel,
                "device_id": device_id,
                "state_delta": normalized,
            }
        return {"handled": False, "reason": "no_state_handler"}

    def publish_device_command(
        self, device_id: str, state_delta: Dict[str, Any], src: str = "cloud"
    ) -> bool:
        """向下行硬件节点下发 `sh/{home_id}/{device_id}/cmd` 指令，防止 MQTT 回环。"""
        if src.startswith("mqtt:") or not self._client or not self._connected:
            return False

        clean_args = {k: v for k, v in state_delta.items() if k != "online"}
        if not clean_args:
            return False

        topic = f"sh/{config.HOME_ID}/{device_id}/cmd"
        body = json.dumps({"v": 1, "cmd": "set", "args": clean_args}, ensure_ascii=False)
        info = self._client.publish(topic, body, qos=1)
        if info.rc == mqtt.MQTT_ERR_SUCCESS:
            self.tx_count += 1
            return True
        self._last_error = f"Publish failed rc={info.rc}"
        logger.warning("MQTT publish failed on %s: rc=%s", topic, info.rc)
        return False

    def start(self) -> None:
        if not config.ENABLE_MQTT_BRIDGE:
            logger.info("MQTT Bridge is disabled (ENABLE_MQTT_BRIDGE=false)")
            return

        client = self._create_paho_client()
        if config.MQTT_USERNAME:
            client.username_pw_set(config.MQTT_USERNAME, config.MQTT_PASSWORD)
        client.reconnect_delay_set(min_delay=2, max_delay=30)
        self._client = client
        try:
            client.connect_async(config.MQTT_BROKER_HOST, config.MQTT_BROKER_PORT, keepalive=30)
            client.loop_start()
            logger.info(
                "MQTT Bridge connecting to %s:%s (home=%s)",
                config.MQTT_BROKER_HOST,
                config.MQTT_BROKER_PORT,
                config.HOME_ID,
            )
        except Exception as exc:
            self._last_error = str(exc)
            logger.error("Failed to start MQTT Bridge: %s", exc)

    def stop(self) -> None:
        if self._client:
            try:
                self._client.loop_stop()
                self._client.disconnect()
            except Exception as exc:
                logger.warning("Error while stopping MQTT Bridge: %s", exc)
            finally:
                self._client = None
                self._connected = False

    def status(self) -> Dict[str, Any]:
        return {
            "enabled": config.ENABLE_MQTT_BRIDGE,
            "connected": self._connected,
            "broker": f"{config.MQTT_BROKER_HOST}:{config.MQTT_BROKER_PORT}",
            "home_id": config.HOME_ID,
            "rx_count": self.rx_count,
            "tx_count": self.tx_count,
            "last_error": self._last_error,
        }


mqtt_bridge = MqttBridge()
