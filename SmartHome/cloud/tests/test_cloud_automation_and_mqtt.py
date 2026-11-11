"""
SmartHome Cloud Backend - Automation Engine (M5) & MQTT Bridge (M2) Automated Tests
使用独立临时 SQLite 数据库与 FastAPI TestClient 验证规则联动、冷却防抖与 MQTT 主题路由，
不污染本地持久化数据库。
"""

import gc
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import MagicMock

from fastapi.testclient import TestClient

CLOUD_ROOT = Path(__file__).resolve().parents[1]
if str(CLOUD_ROOT) not in sys.path:
    sys.path.insert(0, str(CLOUD_ROOT))

from app.config import config
from app.mqtt_bridge import (
    MqttBridge,
    normalize_incoming_payload,
    parse_mqtt_topic,
)
from app import main as cloud_main
from app import rules_engine


class CloudMqttAndRulesTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp_dir = tempfile.TemporaryDirectory(ignore_cleanup_errors=True)
        self._orig_db_path = config.DB_PATH
        self._orig_enable_mqtt = config.ENABLE_MQTT_BRIDGE
        config.DB_PATH = str(Path(self._tmp_dir.name) / "test_smarthome.db")
        config.ENABLE_MQTT_BRIDGE = False
        cloud_main.mqtt_bridge.rx_count = 0
        cloud_main.mqtt_bridge.tx_count = 0
        self.client_ctx = TestClient(cloud_main.app)
        self.client = self.client_ctx.__enter__()

    def tearDown(self) -> None:
        self.client_ctx.__exit__(None, None, None)
        config.DB_PATH = self._orig_db_path
        config.ENABLE_MQTT_BRIDGE = self._orig_enable_mqtt
        gc.collect()
        self._tmp_dir.cleanup()

    def test_mqtt_topic_and_payload_parsers(self) -> None:
        self.assertEqual(parse_mqtt_topic("sh/h01/C01/state"), ("h01", "C01", "state"))
        self.assertEqual(parse_mqtt_topic("sh/h01/S01/online"), ("h01", "S01", "online"))
        self.assertIsNone(parse_mqtt_topic("invalid/topic"))
        self.assertIsNone(parse_mqtt_topic("sh/h01/C01/unknown_ch"))

        self.assertEqual(normalize_incoming_payload("online", "1"), {"online": True})
        self.assertEqual(normalize_incoming_payload("online", "0"), {"online": False})
        self.assertEqual(
            normalize_incoming_payload("state", '{"v":1,"d":"C01","st":{"pos":65,"moving":0}}'),
            {"pos": 65, "moving": 0, "online": True},
        )
        self.assertIsNone(normalize_incoming_payload("state", "{bad-json"))

    def test_mqtt_outgoing_anti_loop_and_publish(self) -> None:
        bridge = MqttBridge()
        mock_client = MagicMock()
        mock_pub_res = MagicMock()
        mock_pub_res.rc = 0
        mock_client.publish.return_value = mock_pub_res
        bridge._client = mock_client
        bridge._connected = True

        # mqtt:* 源更新禁止回发，避免回环风暴
        self.assertFalse(bridge.publish_device_command("C01", {"pos": 80}, src="mqtt:state"))
        mock_client.publish.assert_not_called()

        # 来自云端/终端的变更正常发布到 sh/{HOME_ID}/{device_id}/cmd
        self.assertTrue(bridge.publish_device_command("C01", {"pos": 80}, src="cloud_web"))
        mock_client.publish.assert_called_once()
        topic, payload_str = mock_client.publish.call_args[0]
        self.assertEqual(topic, f"sh/{config.HOME_ID}/C01/cmd")
        self.assertIn('"pos": 80', payload_str)

    def test_simulator_curtain_event_triggers_automation_rule(self) -> None:
        # 初始状态 L01.on == True
        l01_before = self.client.get("/api/v1/devices/L01").json()
        self.assertTrue(l01_before["state"]["on"])

        # 通过硬件节点仿真注入 ESP32-S3 C01 开窗 100% 报文 -> 触发 rule_curtain_open_lights_off 关闭 L01
        sim_res = self.client.post(
            "/api/v1/simulator/node-event",
            json={"device_id": "C01", "channel": "state", "payload": {"v": 1, "d": "C01", "st": {"pos": 100, "moving": 0}}},
        )
        self.assertEqual(sim_res.status_code, 200)
        self.assertTrue(sim_res.json()["handled"])

        c01_after = self.client.get("/api/v1/devices/C01").json()
        self.assertEqual(c01_after["state"]["pos"], 100)

        l01_after = self.client.get("/api/v1/devices/L01").json()
        self.assertFalse(l01_after["state"]["on"])

        # 验证执行日志与规则计数更新
        logs = self.client.get("/api/v1/rules/logs?limit=5").json()
        self.assertGreaterEqual(len(logs), 1)
        self.assertEqual(logs[0]["rule_id"], "rule_curtain_open_lights_off")
        self.assertEqual(logs[0]["status"], "ok")

        # 验证冷却时间 (cooldown_s=30) 防抖生效：先手动重新开启 L01，立即再次上报 C01=95%，不应在冷却期误关 L01
        self.client.post(
            "/api/v1/devices/L01/state",
            json={"device_id": "L01", "state": {"on": True}, "src": "cloud_web"},
        )
        self.client.post(
            "/api/v1/simulator/node-event",
            json={"device_id": "C01", "channel": "state", "payload": {"v": 1, "d": "C01", "st": {"pos": 95, "moving": 0}}},
        )
        l01_cooldown = self.client.get("/api/v1/devices/L01").json()
        self.assertTrue(l01_cooldown["state"]["on"])

    def test_rules_crud_and_discovery(self) -> None:
        # 注册新的虚拟 ESP32-S3 节点 S09
        disc_res = self.client.post(
            "/api/v1/simulator/node-event",
            json={
                "device_id": "S09",
                "channel": "_discovery",
                "payload": {
                    "id": "S09",
                    "name": "厨房烟雾节点(S3)",
                    "room": "客厅",
                    "type": "sensor",
                    "subtype": "smoke",
                    "state": {"smoke": 0, "online": True},
                },
            },
        )
        self.assertEqual(disc_res.status_code, 200)
        s09 = self.client.get("/api/v1/devices/S09")
        self.assertEqual(s09.status_code, 200)

        # 新建一条以 S09.smoke >= 1 触发打开 C01=100 的自定义联动规则 (cooldown=0)
        create_res = self.client.post(
            "/api/v1/rules",
            json={
                "id": "rule_test_smoke_s3",
                "name": "烟雾告警自动开窗帘",
                "enabled": True,
                "trigger": {"dev": "S09", "attr": "smoke", "op": ">=", "val": 1},
                "conditions": [],
                "actions": [{"dev": "C01", "cmd": "set", "args": {"pos": 100}}],
                "cooldown_s": 0,
            },
        )
        self.assertEqual(create_res.status_code, 200)

        # 先关窗帘，再注入 S09 烟雾=2
        self.client.post(
            "/api/v1/devices/C01/state",
            json={"device_id": "C01", "state": {"pos": 0}, "src": "cloud_web"},
        )
        self.client.post(
            "/api/v1/simulator/node-event",
            json={"device_id": "S09", "channel": "state", "payload": {"st": {"smoke": 2}}},
        )
        self.assertEqual(self.client.get("/api/v1/devices/C01").json()["state"]["pos"], 100)

        # 验证停用规则后不触发 + 删除规则清理
        toggle_res = self.client.patch("/api/v1/rules/rule_test_smoke_s3/toggle?enabled=false")
        self.assertEqual(toggle_res.status_code, 200)
        self.assertFalse(toggle_res.json()["enabled"])

        del_res = self.client.delete("/api/v1/rules/rule_test_smoke_s3")
        self.assertEqual(del_res.status_code, 200)
        self.assertIsNone(rules_engine.get_rule("rule_test_smoke_s3"))

    def test_cloud_info_and_mqtt_status_endpoints(self) -> None:
        info = self.client.get("/api/v1/cloud/info").json()
        self.assertIn("mqtt_status", info)
        self.assertIn("rules_count", info)
        self.assertGreaterEqual(info["rules_count"], 3)

        mqtt_st = self.client.get("/api/v1/mqtt/status").json()
        self.assertFalse(mqtt_st["enabled"])
        self.assertFalse(mqtt_st["connected"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
