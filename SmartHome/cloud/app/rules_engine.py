"""
SmartHome Cloud Backend - Automation Rules Engine (Phase M5)
支持三段式联动规则 (trigger + conditions -> actions)、冷却防抖 (cooldown_s) 与执行审计日志。
"""

from __future__ import annotations

import json
import logging
import time
import uuid
from contextlib import contextmanager
from typing import Any, Awaitable, Callable, Dict, Iterator, List, Literal, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field, model_validator

from . import database
from .models import DeviceItem

logger = logging.getLogger("smarthome.cloud.rules")

ComparisonOp = Literal["==", "!=", ">", ">=", "<", "<="]

ActionExecutor = Callable[[str, Dict[str, Any], str], Awaitable[Optional[DeviceItem]]]
RuleEventNotifier = Callable[[Dict[str, Any]], Awaitable[None]]


class RuleCondition(BaseModel):
    dev: str = Field(..., min_length=1, max_length=64)
    attr: str = Field(..., min_length=1, max_length=64)
    op: ComparisonOp
    val: Any


class RuleAction(BaseModel):
    dev: str = Field(..., min_length=1, max_length=64)
    state: Dict[str, Any] = Field(default_factory=dict)

    @model_validator(mode="before")
    @classmethod
    def accept_args_alias(cls, data: Any) -> Any:
        # 兼容 docs/06 中 {"dev": "C01", "cmd": "set", "args": {"pos": 100}} 写法
        if isinstance(data, dict) and not data.get("state") and isinstance(data.get("args"), dict):
            copied = dict(data)
            copied["state"] = copied.pop("args")
            return copied
        return data


class AutomationRuleCreate(BaseModel):
    id: Optional[str] = Field(None, max_length=64)
    name: str = Field(..., min_length=1, max_length=100)
    enabled: bool = True
    trigger: RuleCondition
    conditions: List[RuleCondition] = Field(default_factory=list)
    actions: List[RuleAction] = Field(..., min_length=1)
    cooldown_s: int = Field(60, ge=0, le=86400)


class AutomationRule(BaseModel):
    id: str
    name: str
    enabled: bool = True
    trigger: RuleCondition
    conditions: List[RuleCondition] = Field(default_factory=list)
    actions: List[RuleAction]
    cooldown_s: int = 60
    last_triggered_at: Optional[float] = None
    trigger_count: int = 0
    created_at: float = Field(default_factory=time.time)


class RuleExecutionLog(BaseModel):
    id: int
    rule_id: str
    rule_name: str
    trigger_dev: str
    trigger_attr: str
    trigger_val: str
    actions_count: int
    status: str
    detail: str
    triggered_at: float


def _coerce_numeric(value: Any) -> Optional[float]:
    if isinstance(value, bool):
        return 1.0 if value else 0.0
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        low = value.strip().lower()
        if low == "true":
            return 1.0
        if low == "false":
            return 0.0
        try:
            return float(low)
        except ValueError:
            return None
    return None


def compare_values(actual: Any, op: ComparisonOp, expected: Any) -> bool:
    """安全比较设备属性实际值与规则期望值，兼容布尔/数值混合表达。"""
    if actual is None:
        return False

    num_actual = _coerce_numeric(actual)
    num_expected = _coerce_numeric(expected)
    if num_actual is not None and num_expected is not None:
        if op == "==":
            return abs(num_actual - num_expected) < 1e-6
        if op == "!=":
            return abs(num_actual - num_expected) >= 1e-6
        if op == ">":
            return num_actual > num_expected
        if op == ">=":
            return num_actual >= num_expected
        if op == "<":
            return num_actual < num_expected
        if op == "<=":
            return num_actual <= num_expected
        return False

    str_actual = str(actual)
    str_expected = str(expected)
    if op == "==":
        return str_actual == str_expected
    if op == "!=":
        return str_actual != str_expected
    return False


@contextmanager
def _db_session() -> Iterator[Any]:
    conn = database.get_db_connection()
    try:
        with conn:
            yield conn
    finally:
        conn.close()


def init_rules_schema() -> None:
    """确保自动化规则表与执行审计表存在，并在首次启动时写入示范联动规则。"""
    with _db_session() as conn:
        cursor = conn.cursor()
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS automation_rules (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                enabled INTEGER NOT NULL DEFAULT 1,
                trigger_json TEXT NOT NULL,
                conditions_json TEXT NOT NULL DEFAULT '[]',
                actions_json TEXT NOT NULL,
                cooldown_s INTEGER NOT NULL DEFAULT 60,
                last_triggered_at REAL,
                trigger_count INTEGER NOT NULL DEFAULT 0,
                created_at REAL NOT NULL
            )
            """
        )
        cursor.execute(
            """
            CREATE TABLE IF NOT EXISTS rule_execution_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                rule_id TEXT NOT NULL,
                rule_name TEXT NOT NULL,
                trigger_dev TEXT NOT NULL,
                trigger_attr TEXT NOT NULL,
                trigger_val TEXT NOT NULL,
                actions_count INTEGER NOT NULL,
                status TEXT NOT NULL,
                detail TEXT NOT NULL,
                triggered_at REAL NOT NULL
            )
            """
        )
        cursor.execute("SELECT COUNT(*) AS cnt FROM automation_rules")
        row = cursor.fetchone()
        if row and row["cnt"] == 0:
            now = time.time()
            default_rules = [
                AutomationRule(
                    id="rule_curtain_open_lights_off",
                    name="窗帘全开联动关闭客厅主灯",
                    enabled=True,
                    trigger=RuleCondition(dev="C01", attr="pos", op=">=", val=90),
                    conditions=[],
                    actions=[RuleAction(dev="L01", state={"on": False})],
                    cooldown_s=30,
                    created_at=now,
                ),
                AutomationRule(
                    id="rule_study_power_off_light",
                    name="书房排插断电联动关书房灯",
                    enabled=True,
                    trigger=RuleCondition(dev="S01", attr="on", op="==", val=False),
                    conditions=[],
                    actions=[RuleAction(dev="L06", state={"on": False})],
                    cooldown_s=30,
                    created_at=now,
                ),
                AutomationRule(
                    id="rule_ac_on_close_curtain",
                    name="客厅空调开启自动拉上窗帘保温",
                    enabled=False,
                    trigger=RuleCondition(dev="AC01", attr="on", op="==", val=True),
                    conditions=[],
                    actions=[RuleAction(dev="C01", state={"pos": 0})],
                    cooldown_s=60,
                    created_at=now,
                ),
            ]
            for r in default_rules:
                _insert_or_replace_rule_tx(cursor, r)
        conn.commit()


def _insert_or_replace_rule_tx(cursor: Any, rule: AutomationRule) -> None:
    cursor.execute(
        """
        INSERT INTO automation_rules (
            id, name, enabled, trigger_json, conditions_json, actions_json,
            cooldown_s, last_triggered_at, trigger_count, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            name=excluded.name,
            enabled=excluded.enabled,
            trigger_json=excluded.trigger_json,
            conditions_json=excluded.conditions_json,
            actions_json=excluded.actions_json,
            cooldown_s=excluded.cooldown_s
        """,
        (
            rule.id,
            rule.name,
            1 if rule.enabled else 0,
            rule.trigger.model_dump_json(),
            json.dumps([c.model_dump() for c in rule.conditions], ensure_ascii=False),
            json.dumps([a.model_dump() for a in rule.actions], ensure_ascii=False),
            rule.cooldown_s,
            rule.last_triggered_at,
            rule.trigger_count,
            rule.created_at,
        ),
    )


def _row_to_rule(row: Any) -> AutomationRule:
    return AutomationRule(
        id=row["id"],
        name=row["name"],
        enabled=bool(row["enabled"]),
        trigger=RuleCondition(**json.loads(row["trigger_json"])),
        conditions=[RuleCondition(**c) for c in json.loads(row["conditions_json"])],
        actions=[RuleAction(**a) for a in json.loads(row["actions_json"])],
        cooldown_s=row["cooldown_s"],
        last_triggered_at=row["last_triggered_at"],
        trigger_count=row["trigger_count"],
        created_at=row["created_at"],
    )


def list_rules() -> List[AutomationRule]:
    with _db_session() as conn:
        rows = conn.execute(
            "SELECT * FROM automation_rules ORDER BY created_at ASC"
        ).fetchall()
    return [_row_to_rule(r) for r in rows]


def get_rule(rule_id: str) -> Optional[AutomationRule]:
    with _db_session() as conn:
        row = conn.execute(
            "SELECT * FROM automation_rules WHERE id = ?",
            (rule_id,),
        ).fetchone()
    return _row_to_rule(row) if row else None


def save_rule(payload: AutomationRuleCreate) -> AutomationRule:
    rule_id = (payload.id or f"rule_{uuid.uuid4().hex[:8]}").strip()
    existing = get_rule(rule_id)
    rule = AutomationRule(
        id=rule_id,
        name=payload.name.strip(),
        enabled=payload.enabled,
        trigger=payload.trigger,
        conditions=payload.conditions,
        actions=payload.actions,
        cooldown_s=payload.cooldown_s,
        last_triggered_at=existing.last_triggered_at if existing else None,
        trigger_count=existing.trigger_count if existing else 0,
        created_at=existing.created_at if existing else time.time(),
    )
    with _db_session() as conn:
        _insert_or_replace_rule_tx(conn.cursor(), rule)
    return rule


def set_rule_enabled(rule_id: str, enabled: bool) -> Optional[AutomationRule]:
    with _db_session() as conn:
        cur = conn.execute(
            "UPDATE automation_rules SET enabled = ? WHERE id = ?",
            (1 if enabled else 0, rule_id),
        )
        if cur.rowcount == 0:
            return None
    return get_rule(rule_id)


def delete_rule(rule_id: str) -> bool:
    with _db_session() as conn:
        cur = conn.execute("DELETE FROM automation_rules WHERE id = ?", (rule_id,))
    return cur.rowcount > 0


def list_rule_logs(limit: int = 30) -> List[RuleExecutionLog]:
    with _db_session() as conn:
        rows = conn.execute(
            "SELECT * FROM rule_execution_logs ORDER BY triggered_at DESC LIMIT ?",
            (limit,),
        ).fetchall()
    return [
        RuleExecutionLog(
            id=r["id"],
            rule_id=r["rule_id"],
            rule_name=r["rule_name"],
            trigger_dev=r["trigger_dev"],
            trigger_attr=r["trigger_attr"],
            trigger_val=r["trigger_val"],
            actions_count=r["actions_count"],
            status=r["status"],
            detail=r["detail"],
            triggered_at=r["triggered_at"],
        )
        for r in rows
    ]


class RulesEngine:
    """自动化联动评估与执行引擎。"""

    def __init__(self) -> None:
        self._action_executor: Optional[ActionExecutor] = None
        self._notifier: Optional[RuleEventNotifier] = None

    def configure(
        self,
        action_executor: ActionExecutor,
        notifier: Optional[RuleEventNotifier] = None,
    ) -> None:
        self._action_executor = action_executor
        self._notifier = notifier

    async def evaluate_for_device(
        self,
        device: DeviceItem,
        delta_state: Dict[str, Any],
        src: str,
        now: Optional[float] = None,
    ) -> List[Dict[str, Any]]:
        """当设备状态发生变化时评估关联规则并执行动作。"""
        if src.startswith("rule:"):
            return []

        ts = time.time() if now is None else now
        rules = [r for r in list_rules() if r.enabled and r.trigger.dev == device.id]
        if not rules:
            return []

        executed: List[Dict[str, Any]] = []
        device_cache: Dict[str, DeviceItem] = {device.id: device}

        for rule in rules:
            trig = rule.trigger
            # 仅当本次更新包含或影响触发属性时再评估，避免无关字段误触发
            if trig.attr not in delta_state:
                continue

            actual_val = device.state.get(trig.attr)
            if not compare_values(actual_val, trig.op, trig.val):
                continue

            if rule.last_triggered_at is not None and (ts - rule.last_triggered_at) < rule.cooldown_s:
                logger.debug(
                    "Rule %s skipped due to cooldown (%.1fs < %ss)",
                    rule.id,
                    ts - rule.last_triggered_at,
                    rule.cooldown_s,
                )
                continue

            if not self._check_conditions(rule.conditions, device_cache):
                continue

            result = await self._execute_rule(rule, trig.dev, trig.attr, actual_val, ts)
            executed.append(result)

        return executed

    def _check_conditions(
        self, conditions: List[RuleCondition], cache: Dict[str, DeviceItem]
    ) -> bool:
        for cond in conditions:
            if cond.dev not in cache:
                fetched = database.get_device(cond.dev)
                if fetched:
                    cache[cond.dev] = fetched
            target_dev = cache.get(cond.dev)
            if not target_dev:
                return False
            actual = target_dev.state.get(cond.attr)
            if not compare_values(actual, cond.op, cond.val):
                return False
        return True

    async def run_rule_manually(self, rule_id: str) -> Optional[Dict[str, Any]]:
        rule = get_rule(rule_id)
        if not rule:
            return None
        return await self._execute_rule(
            rule,
            trigger_dev=rule.trigger.dev,
            trigger_attr="manual_test",
            trigger_val="manual",
            ts=time.time(),
        )

    async def _execute_rule(
        self,
        rule: AutomationRule,
        trigger_dev: str,
        trigger_attr: str,
        trigger_val: Any,
        ts: float,
    ) -> Dict[str, Any]:
        applied_devs: List[str] = []
        failed_devs: List[str] = []

        for action in rule.actions:
            try:
                updated: Optional[DeviceItem] = None
                if self._action_executor:
                    updated = await self._action_executor(
                        action.dev, action.state, f"rule:{rule.id}"
                    )
                else:
                    updated = database.update_device_state(
                        action.dev, action.state, src=f"rule:{rule.id}"
                    )
                if updated:
                    applied_devs.append(action.dev)
                else:
                    failed_devs.append(action.dev)
            except Exception as exc:
                logger.error("Rule %s action on %s failed: %s", rule.id, action.dev, exc)
                failed_devs.append(action.dev)

        status = "ok" if not failed_devs else ("partial_fail" if applied_devs else "failed")
        detail = (
            f"已执行 {len(applied_devs)} 项动作 ({', '.join(applied_devs)})"
            if not failed_devs
            else f"成功 {', '.join(applied_devs) or '无'}; 失败 {', '.join(failed_devs)}"
        )

        with _db_session() as conn:
            conn.execute(
                """
                UPDATE automation_rules
                SET last_triggered_at = ?, trigger_count = trigger_count + 1
                WHERE id = ?
                """,
                (ts, rule.id),
            )
            conn.execute(
                """
                INSERT INTO rule_execution_logs (
                    rule_id, rule_name, trigger_dev, trigger_attr, trigger_val,
                    actions_count, status, detail, triggered_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    rule.id,
                    rule.name,
                    trigger_dev,
                    trigger_attr,
                    json.dumps(trigger_val, ensure_ascii=False),
                    len(rule.actions),
                    status,
                    detail,
                    ts,
                ),
            )

        event_payload = {
            "rule_id": rule.id,
            "rule_name": rule.name,
            "trigger_dev": trigger_dev,
            "trigger_attr": trigger_attr,
            "trigger_val": trigger_val,
            "applied_devs": applied_devs,
            "failed_devs": failed_devs,
            "status": status,
            "detail": detail,
            "triggered_at": ts,
        }
        logger.info("Rule triggered [%s]: %s -> %s", rule.id, rule.name, detail)
        if self._notifier:
            await self._notifier(event_payload)
        return event_payload


rules_engine = RulesEngine()
router = APIRouter(prefix="/api/v1/rules", tags=["automation"])


@router.get("", response_model=List[AutomationRule])
def api_list_rules():
    return list_rules()


@router.get("/logs", response_model=List[RuleExecutionLog])
def api_list_rule_logs(limit: int = 30):
    return list_rule_logs(limit=limit)


@router.post("", response_model=AutomationRule)
def api_create_or_update_rule(payload: AutomationRuleCreate):
    return save_rule(payload)


@router.patch("/{rule_id}/toggle", response_model=AutomationRule)
def api_toggle_rule(rule_id: str, enabled: bool):
    updated = set_rule_enabled(rule_id, enabled)
    if not updated:
        raise HTTPException(status_code=404, detail=f"Rule {rule_id} not found")
    return updated


@router.post("/{rule_id}/run")
async def api_run_rule(rule_id: str):
    result = await rules_engine.run_rule_manually(rule_id)
    if result is None:
        raise HTTPException(status_code=404, detail=f"Rule {rule_id} not found")
    return {"success": True, "execution": result}


@router.delete("/{rule_id}")
def api_delete_rule(rule_id: str):
    if not delete_rule(rule_id):
        raise HTTPException(status_code=404, detail=f"Rule {rule_id} not found")
    return {"success": True, "rule_id": rule_id}
