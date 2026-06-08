import json
from enum import Enum
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple

# Translate from Shadow events -> events; Events back to reasonable interpretation of trace

IGNORE_RUNNING_STATE = True


# not relevant for tokens, but interesting for analysis
@dataclass
class Timestamp:
    receiver_time: Optional[datetime]
    internal_time: Optional[datetime]


NA = "NA"  # For missing/irrelevant values in factor slots


class RejectReason(Enum):
    INVALID_TOPIC = "INVALID_TOPIC"
    INVALID_TOPIC_FOR_MODULE = "INVALID_TOPIC_FOR_MODULE"
    MISSING_PAYLOAD = "MISSING_PAYLOAD"
    INVALID_PAYLOAD = "INVALID_PAYLOAD"
    RUNNING_STATE_IGNORED = "RUNNING_STATE_IGNORED"
    INVALID_SERIAL = "INVALID_SERIAL"
    INVALID_DEVICE_TYPE = "INVALID_DEVICE_TYPE"
    DUPLICATE_STATE = "DUPLICATE_STATE"
    DUPLICATE_ACTION = "DUPLICATE_ACTION"
    BEFORE_FIRST_ORDER = "BEFORE_FIRST_ORDER"
    DPS_ORDER_NO_COLOR = "DPS_ORDER_NO_COLOR"


# Layout-derived mapping from serial number to stable device type.
# Extend this dict when layout devices are added/removed.
SERIAL_TO_DEVICE_TYPE = {
    "SVR4H73901": "HBW",
    "SVR3QL1089": "DRILL",
    "SVR4H88474": "MILL",
    "SVR4H92774": "DPS",
    "SVR4H77011": "AIQS",
    "ylK4": "AGV",
}


MODULES = SERIAL_TO_DEVICE_TYPE.values()

ORIGIN_ORDER = "order"
ORIGIN_STATE = "state"


@dataclass(frozen=True)
class ShadowEvent:
    module: str
    actor_id: str
    token: str
    origin: str  # "order" or "state" message
    timestamp: Timestamp
    order_id: Optional[str] = None
    state_id: Optional[str] = None  # used to deduplicate state messages
    action_id: Optional[str] = None  # used to deduplicate action (order) messages
    # raw payload for debugging/QA purposes, not used in modeling
    debug_raw: Dict[str, Any] = None

    def to_dict(self) -> Dict[str, Any]:
        return {
            "module": self.module,
            "actor_id": self.actor_id,
            "token": self.token,
            "action_id": self.action_id,
            "state_id": self.state_id,
            "origin": self.origin,
            "timestamp": {
                "receiver_time": (
                    self.timestamp.receiver_time.isoformat()
                    if self.timestamp.receiver_time
                    else None
                ),
                "internal_time": (
                    self.timestamp.internal_time.isoformat()
                    if self.timestamp.internal_time
                    else None
                ),
            },
            "order_id": self.order_id,
            "debug_raw": self.debug_raw,
        }


def parse_iso_timestamp(ts: Optional[str]) -> Optional[datetime]:
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None


# For each module type:
# 1. Mapping from trace format to shadow event type (factor event type) -> Token plus a lot of Meta Data


# Quality Assurance Module
## parts taken from the "/factsheet" topic
# AIQS_SPECSHEET = {
#     "headerId": 1,
#     "timestamp": "2026-03-10T08:25:11.552Z",
#     "version": "1.3.0",
#     "manufacturer": "Fischertechnik",
#     "serialNumber": "SVR4H77011",
#     "typeSpecification": {"seriesName": "MOD-FF22+AIQS+24V", "moduleClass": "AIQS"},
#     "physicalParameters": {},
#     "protocolLimits": {},
#     "protocolFeatures": {
#         "moduleActions": [
#             {
#                 "actionType": "PICK",
#                 "actionParameters": [
#                     {
#                         "parameterName": "type",
#                         "parameterType": "string",
#                         "parameterDescription": "Type of workpiece to pick up and process",
#                     }
#                 ],
#             },
#             {
#                 "actionType": "DROP",
#                 "actionParameters": [
#                     {
#                         "parameterName": "type",
#                         "parameterType": "string",
#                         "parameterDescription": "Type of workpiece that should be put on the FTS",
#                         "isOptional": true,
#                     }
#                 ],
#             },
#             {
#                 "actionType": "CHECK_QUALITY",
#                 "actionParameters": [
#                     {
#                         "parameterName": "type",
#                         "parameterType": "string",
#                         "parameterDescription": "Type of workpiece that should checked",
#                         "isOptional": true,
#                     }
#                 ],
#             },
#         ]
#     },
#     "localizationParameters": {},
#     "loadSpecification": {
#         "loadSets": [
#             {"setName": "WHITES", "loadType": "WHITE"},
#             {"setName": "REDS", "loadType": "RED"},
#             {"setName": "BLUES", "loadType": "BLUE"},
#         ]
#     },
# }
class AIQSEvent:
    module: str = "AIQS"
    commands: dict[str, dict[str]] = {
        "PICK": {"FINISHED": "Picked", "RUNNING": "Pick", "FAILED": "Pick Failed"},
        "DROP": {"FINISHED": "Dropped", "RUNNING": "Drop", "FAILED": "Drop Failed"},
        "CHECK_QUALITY": {
            "FINISHED": "Checked",
            "RUNNING": "Check",
            "FAILED": "Check Failed",
        },
    }
    results: set[str] = {"PASSED", "FAILED"}

    @staticmethod
    def from_trace_event(
        topic: str, external_ts: Optional[datetime], payload: Dict[str, Any]
    ) -> ShadowEvent | RejectReason:
        order_id = payload.get("orderId")
        internal_ts_str = payload.get("timestamp")
        internal_ts = parse_iso_timestamp(internal_ts_str)
        if internal_ts is None:
            return RejectReason.INVALID_PAYLOAD
        ts = Timestamp(receiver_time=external_ts, internal_time=internal_ts)

        actor_id = payload.get("serialNumber")
        if actor_id is None:
            return RejectReason.INVALID_PAYLOAD

        if topic.endswith("/order"):
            action = payload.get("action")
            if action is None:
                return RejectReason.INVALID_PAYLOAD

            action_id = action.get("id")

            command = action.get("command", "")
            if command not in AIQSEvent.commands.keys():
                return RejectReason.INVALID_PAYLOAD

            token = f"{AIQSEvent.module} {AIQSEvent.commands[command]["RUNNING"]}"

            return ShadowEvent(
                module=AIQSEvent.module,
                token=token,
                actor_id=actor_id,
                action_id=action_id,
                timestamp=ts,
                order_id=order_id,
                debug_raw=payload,
                origin=ORIGIN_ORDER,
            )
        elif topic.endswith("/state"):
            actionState = payload.get("actionState")
            if actionState is None:
                return RejectReason.INVALID_PAYLOAD

            active_command = actionState.get("command", "")
            if active_command not in AIQSEvent.commands.keys():
                return RejectReason.INVALID_PAYLOAD

            state = actionState.get("state", "")
            if state not in AIQSEvent.commands[active_command].keys():
                return RejectReason.INVALID_PAYLOAD

            stateId = actionState.get("id")

            if state == "RUNNING" and IGNORE_RUNNING_STATE:
                return RejectReason.RUNNING_STATE_IGNORED

            if state == "FINISHED" and active_command == "CHECK_QUALITY":
                result = actionState.get("result", "")
                if result not in AIQSEvent.results:
                    return RejectReason.INVALID_PAYLOAD
                if result == "FAILED":
                    state = "FAILED"

            token = f"{AIQSEvent.module} {AIQSEvent.commands[active_command][state]}"

            return ShadowEvent(
                module=AIQSEvent.module,
                token=token,
                actor_id=actor_id,
                timestamp=ts,
                order_id=order_id,
                state_id=stateId,
                debug_raw=payload,
                origin=ORIGIN_STATE,
            )
        else:
            return RejectReason.INVALID_TOPIC_FOR_MODULE


# Delivery and Pickup Station
class DPSEvent:
    module: str = "DPS"
    commands: dict[str, dict[str]] = {
        "PICK": {"FINISHED": "Picked", "RUNNING": "Pick", "FAILED": "Pick Failed"},
        "DROP": {"FINISHED": "Dropped", "RUNNING": "Drop", "FAILED": "Drop Failed"},
    }

    @staticmethod
    def from_trace_event(
        topic: str, external_ts: Optional[datetime], payload: Dict[str, Any]
    ) -> ShadowEvent | RejectReason:
        order_id = payload.get("orderId")
        internal_ts_str = payload.get("timestamp")
        internal_ts = parse_iso_timestamp(internal_ts_str)
        if internal_ts is None:
            return RejectReason.INVALID_PAYLOAD
        ts = Timestamp(receiver_time=external_ts, internal_time=internal_ts)

        actor_id = payload.get("serialNumber")
        if actor_id is None:
            return RejectReason.INVALID_PAYLOAD

        if topic.endswith("/order"):
            action = payload.get("action")
            if action is None:
                return RejectReason.INVALID_PAYLOAD

            action_id = action.get("id")

            command = action.get("command", "")
            if command not in DPSEvent.commands.keys():
                return RejectReason.INVALID_PAYLOAD

            # DPS also contains color from metadata
            color = action.get("metadata", {}).get("workpiece", {}).get("type", None)
            if color == None:
                return RejectReason.DPS_ORDER_NO_COLOR

            token = f"{DPSEvent.module} {color} {DPSEvent.commands[command]["RUNNING"]}"

            return ShadowEvent(
                module=DPSEvent.module,
                token=token,
                actor_id=actor_id,
                action_id=action_id,
                timestamp=ts,
                order_id=order_id,
                debug_raw=payload,
                origin=ORIGIN_ORDER,
            )
        elif topic.endswith("/state"):
            actionState = payload.get("actionState")
            if actionState is None:
                return RejectReason.INVALID_PAYLOAD

            active_command = actionState.get("command", "")
            if active_command not in DPSEvent.commands.keys():
                return RejectReason.INVALID_PAYLOAD

            state = actionState.get("state", "")
            if state not in DPSEvent.commands[active_command].keys():
                return RejectReason.INVALID_PAYLOAD

            stateId = actionState.get("id")

            if state == "RUNNING" and IGNORE_RUNNING_STATE:
                return RejectReason.RUNNING_STATE_IGNORED

            token = f"{DPSEvent.module} {DPSEvent.commands[active_command][state]}"

            return ShadowEvent(
                module=DPSEvent.module,
                token=token,
                actor_id=actor_id,
                timestamp=ts,
                order_id=order_id,
                state_id=stateId,
                debug_raw=payload,
                origin=ORIGIN_STATE,
            )
        else:
            return RejectReason.INVALID_TOPIC_FOR_MODULE


class DrillEvent:
    module: str = "DRILL"
    commands: dict[str, dict[str]] = {
        "PICK": {"FINISHED": "Picked", "RUNNING": "Pick", "FAILED": "Pick Failed"},
        "DROP": {"FINISHED": "Dropped", "RUNNING": "Drop", "FAILED": "Drop Failed"},
        "DRILL": {
            "FINISHED": "Drilled",
            "RUNNING": "Drill",
            "FAILED": "Drill Failed",
        },
    }

    @staticmethod
    def from_trace_event(
        topic: str, external_ts: Optional[datetime], payload: Dict[str, Any]
    ) -> ShadowEvent | RejectReason:
        order_id = payload.get("orderId")
        internal_ts_str = payload.get("timestamp")
        internal_ts = parse_iso_timestamp(internal_ts_str)
        if internal_ts is None:
            return RejectReason.INVALID_PAYLOAD
        ts = Timestamp(receiver_time=external_ts, internal_time=internal_ts)

        actor_id = payload.get("serialNumber")
        if actor_id is None:
            return RejectReason.INVALID_PAYLOAD

        if topic.endswith("/order"):
            action = payload.get("action")
            if action is None:
                return RejectReason.INVALID_PAYLOAD

            action_id = action.get("id")

            command = action.get("command", "")
            if command not in DrillEvent.commands.keys():
                return RejectReason.INVALID_PAYLOAD

            duration = action.get("metadata", {}).get("durationSeconds")
            if duration is None:
                duration = 5  # Default duration
            # duration_param = bucket_duration(duration)

            token = f"{DrillEvent.module} {DrillEvent.commands[command]["RUNNING"]}"

            return ShadowEvent(
                module=DrillEvent.module,
                token=token,
                actor_id=actor_id,
                action_id=action_id,
                timestamp=ts,
                order_id=order_id,
                debug_raw=payload,
                origin=ORIGIN_ORDER,
            )
        elif topic.endswith("/state"):
            actionState = payload.get("actionState")
            if actionState is None:
                return RejectReason.INVALID_PAYLOAD

            active_command = actionState.get("command", "")
            if active_command not in DrillEvent.commands.keys():
                return RejectReason.INVALID_PAYLOAD

            state = actionState.get("state", "")
            if state not in DrillEvent.commands[active_command].keys():
                return RejectReason.INVALID_PAYLOAD

            stateId = actionState.get("id")

            if state == "RUNNING" and IGNORE_RUNNING_STATE:
                return RejectReason.RUNNING_STATE_IGNORED

            token = f"{DrillEvent.module} {DrillEvent.commands[active_command][state]}"

            return ShadowEvent(
                module=DrillEvent.module,
                token=token,
                actor_id=actor_id,
                timestamp=ts,
                order_id=order_id,
                state_id=stateId,
                debug_raw=payload,
                origin=ORIGIN_STATE,
            )
        else:
            return RejectReason.INVALID_TOPIC_FOR_MODULE


class MillEvent:
    module: str = "MILL"
    commands: dict[str, dict[str]] = {
        "PICK": {"FINISHED": "Picked", "RUNNING": "Pick", "FAILED": "Pick Failed"},
        "DROP": {"FINISHED": "Dropped", "RUNNING": "Drop", "FAILED": "Drop Failed"},
        "MILL": {
            "FINISHED": "Milled",
            "RUNNING": "Mill",
            "FAILED": "Mill Failed",
        },
    }

    @staticmethod
    def from_trace_event(
        topic: str, external_ts: Optional[datetime], payload: Dict[str, Any]
    ) -> ShadowEvent | RejectReason:
        order_id = payload.get("orderId")
        internal_ts_str = payload.get("timestamp")  # message internal timestamp
        internal_ts = parse_iso_timestamp(internal_ts_str)
        if internal_ts is None:
            return RejectReason.INVALID_PAYLOAD
        ts = Timestamp(receiver_time=external_ts, internal_time=internal_ts)

        actor_id = payload.get("serialNumber")
        if actor_id is None:
            return RejectReason.INVALID_PAYLOAD

        if topic.endswith("/order"):
            action = payload.get("action")
            if action is None:
                return RejectReason.INVALID_PAYLOAD

            action_id = action.get("id")

            command = action.get("command", "")
            if command not in MillEvent.commands.keys():
                return RejectReason.INVALID_PAYLOAD

            duration = action.get("metadata", {}).get("durationSeconds")
            if duration is None:
                duration = 5  # Default duration
            # duration_param = bucket_duration(duration)

            token = f"{MillEvent.module} {MillEvent.commands[command]["RUNNING"]}"
            # slots["duration_param"] = duration_param

            return ShadowEvent(
                module=MillEvent.module,
                token=token,
                actor_id=actor_id,
                action_id=action_id,
                timestamp=ts,
                order_id=order_id,
                debug_raw=payload,
                origin=ORIGIN_ORDER,
            )
        elif topic.endswith("/state"):
            actionState = payload.get("actionState")
            if actionState is None:
                return RejectReason.INVALID_PAYLOAD

            active_command = actionState.get("command", "")
            if active_command not in MillEvent.commands.keys():
                return RejectReason.INVALID_PAYLOAD

            state = actionState.get("state", "")
            if state not in MillEvent.commands[active_command].keys():
                return RejectReason.INVALID_PAYLOAD

            stateId = actionState.get("id")

            if state == "RUNNING" and IGNORE_RUNNING_STATE:
                return RejectReason.RUNNING_STATE_IGNORED

            token = f"{MillEvent.module} {MillEvent.commands[active_command][state]}"

            return ShadowEvent(
                module=MillEvent.module,
                token=token,
                actor_id=actor_id,
                timestamp=ts,
                order_id=order_id,
                state_id=stateId,
                debug_raw=payload,
                origin=ORIGIN_STATE,
            )
        else:
            return RejectReason.INVALID_TOPIC_FOR_MODULE


# High Bay Warehouse -> Pick and drop inverted, like in DPS
# get/put parameters are defined per order -> thus not necessary as we only model one order execution
class HBWEvent:
    module: str = "HBW"
    commands: dict[str, dict[str]] = {
        "PICK": {"FINISHED": "Picked", "RUNNING": "Pick", "FAILED": "Pick Failed"},
        "DROP": {"FINISHED": "Dropped", "RUNNING": "Drop", "FAILED": "Drop Failed"},
    }

    @staticmethod
    def from_trace_event(
        topic: str, external_ts: Optional[datetime], payload: Dict[str, Any]
    ) -> ShadowEvent | RejectReason:
        order_id = payload.get("orderId")
        internal_ts_str = payload.get("timestamp")  # message internal timestamp
        internal_ts = parse_iso_timestamp(internal_ts_str)
        if internal_ts is None:
            return RejectReason.INVALID_PAYLOAD
        ts = Timestamp(receiver_time=external_ts, internal_time=internal_ts)

        actor_id = payload.get("serialNumber")
        if actor_id is None:
            return RejectReason.INVALID_PAYLOAD

        if topic.endswith("/order"):
            action = payload.get("action")
            if action is None:
                return RejectReason.INVALID_PAYLOAD

            action_id = action.get("id")

            command = action.get("command", "")
            if command not in HBWEvent.commands.keys():
                return RejectReason.INVALID_PAYLOAD

            token = f"{HBWEvent.module} {HBWEvent.commands[command]["RUNNING"]}"

            return ShadowEvent(
                module=HBWEvent.module,
                token=token,
                actor_id=actor_id,
                action_id=action_id,
                timestamp=ts,
                order_id=order_id,
                debug_raw=payload,
                origin=ORIGIN_ORDER,
            )
        elif topic.endswith("/state"):
            actionState = payload.get("actionState")
            if actionState is None:
                return RejectReason.INVALID_PAYLOAD

            active_command = actionState.get("command", "")
            if active_command not in HBWEvent.commands.keys():
                return RejectReason.INVALID_PAYLOAD

            state = actionState.get("state", "")
            if state not in HBWEvent.commands[active_command].keys():
                return RejectReason.INVALID_PAYLOAD

            stateId = actionState.get("id")

            if state == "RUNNING" and IGNORE_RUNNING_STATE:
                return RejectReason.RUNNING_STATE_IGNORED

            token = f"{HBWEvent.module} {HBWEvent.commands[active_command][state]}"

            return ShadowEvent(
                module=HBWEvent.module,
                token=token,
                actor_id=actor_id,
                timestamp=ts,
                order_id=order_id,
                state_id=stateId,
                debug_raw=payload,
                origin=ORIGIN_STATE,
            )
        else:
            return RejectReason.INVALID_TOPIC_FOR_MODULE


# AGV events
class AGVEvent:
    module: str = "AGV"
    # does not use AGV internal commands, as we only want to model going from A to B, not the full path
    commands: set[str] = {
        "MOVE_TO"
    }  # , "CLEAR_LOAD_HANDLER_PICKED", "CLEAR_LOAD_HANDLER_DROPPED"}
    states: set[str] = {"FINISHED", "DRIVING", "WAITING", "FAILED"}

    @staticmethod
    def from_trace_event(
        topic: str, external_ts: Optional[datetime], payload: Dict[str, Any]
    ) -> ShadowEvent | RejectReason:
        order_id = payload.get("orderId")
        internal_ts_str = payload.get("timestamp")  # message internal timestamp
        internal_ts = parse_iso_timestamp(internal_ts_str)
        if internal_ts is None:
            return RejectReason.INVALID_PAYLOAD
        ts = Timestamp(receiver_time=external_ts, internal_time=internal_ts)

        actor_id = payload.get("serialNumber")
        if actor_id is None:
            return RejectReason.INVALID_PAYLOAD

        if topic.endswith("/order"):
            nodes = payload.get("nodes", [])
            if not isinstance(nodes, list) or len(nodes) < 2:
                return RejectReason.INVALID_PAYLOAD

            # for simplicity, assume first node is src and last node is dst
            src = nodes[0].get("id")
            dst = nodes[-1].get("id")

            # map ids (serials) to names
            src = SERIAL_TO_DEVICE_TYPE.get(src)
            dst = SERIAL_TO_DEVICE_TYPE.get(dst)
            if src is None or dst is None:
                return RejectReason.INVALID_SERIAL

            token = f"{AGVEvent.module} move {src} to {dst}"

            return ShadowEvent(
                module=AGVEvent.module,
                token=token,
                actor_id=actor_id,
                timestamp=ts,
                order_id=order_id,
                debug_raw=payload,
                origin=ORIGIN_ORDER,
            )
        else:
            return RejectReason.INVALID_TOPIC_FOR_MODULE


MODULES = {
    "AIQS": AIQSEvent,
    "DPS": DPSEvent,
    "DRILL": DrillEvent,
    "MILL": MillEvent,
    "HBW": HBWEvent,
    "AGV": AGVEvent,
}


def extract_serial_from_topic(topic: str, payload: Dict[str, Any]) -> Optional[str]:
    parts = topic.split("/")
    if topic.startswith("fts/") and len(parts) >= 4:
        return parts[3]
    if topic.startswith("module/"):
        if "NodeRed" in parts:
            idx = parts.index("NodeRed")
            if idx + 1 < len(parts):
                return parts[idx + 1]
        if len(parts) >= 4:
            return parts[3]
    return payload.get("serialNumber")


def normalize_device_type(serial: Optional[str], topic: str) -> str | RejectReason:
    if serial and serial in SERIAL_TO_DEVICE_TYPE:
        return SERIAL_TO_DEVICE_TYPE[serial]
    return RejectReason.INVALID_SERIAL


def build_event(recv_ts, topic, payload) -> ShadowEvent | RejectReason:
    serial = extract_serial_from_topic(topic, payload)
    module_type = normalize_device_type(serial, topic)
    if isinstance(module_type, RejectReason):
        return module_type

    module = MODULES.get(module_type)
    if module is None:
        return RejectReason.INVALID_DEVICE_TYPE

    return module.from_trace_event(topic, recv_ts, payload)


def extract_traces_and_timings(file_path: str) -> List[Dict[str, Any]]:
    with open(file_path, "r") as f:
        data = json.load(f)

    processed_traces: List[Dict[str, Any]] = []

    for run in data:
        trace = run.get("trace", [])
        if not isinstance(trace, list):
            print("Warning: Skipping trace with invalid format (not a list):", trace)
            continue  # Skip if trace is not a list

        events: List[ShadowEvent] = []
        rejected_events: dict[RejectReason, dict] = defaultdict(lambda: [])

        seen_states = defaultdict(
            lambda: set()
        )  # To track seen state events for state_id
        seen_actions = defaultdict(
            lambda: set()
        )  # To track seen action events for action_id

        seen_order = False  # whether a "order" was in this trace yet -> ignore state messages until first order if set to False initially

        for raw_event in trace:
            if not isinstance(raw_event, dict):
                print("Warning: Skipping non-dict event in trace:", raw_event)
                continue  # Skip if event is not a dict

            topic = str(raw_event.get("topic", ""))
            payload = (
                raw_event.get("payload", {})
                if isinstance(raw_event.get("payload"), dict)
                else {}
            )
            recv_ts = parse_iso_timestamp(raw_event.get("timestamp"))
            if recv_ts is None:
                print("Warning: Skipping event with invalid timestamp:", raw_event)
                continue  # Skip if timestamp is invalid

            event = build_event(recv_ts, topic, payload)
            if isinstance(event, RejectReason):
                rejected_events[event].append(raw_event)
                continue  # Skip rejected events

            # before first order check
            if (not seen_order) and (not event.origin == ORIGIN_ORDER):
                rejected_events[RejectReason.BEFORE_FIRST_ORDER].append(raw_event)
                continue  # Skip events with duplicate state_id
            elif (not seen_order) and (event.origin == ORIGIN_ORDER):
                seen_order = True  # second condition implied

            if event.state_id is not None:
                if event.token in seen_states[event.state_id]:
                    # print("Warning: Duplicate state_id detected, skipping event:", event)
                    rejected_events[RejectReason.DUPLICATE_STATE].append(raw_event)
                    continue  # Skip events with duplicate state_id
                seen_states[event.state_id].add(event.token)

            if event.action_id is not None:
                if event.token in seen_actions[event.action_id]:
                    rejected_events[RejectReason.DUPLICATE_ACTION].append(raw_event)
                    continue
                seen_actions[event.action_id].add(event.token)

            events.append(event)

        if not events:
            print("Warning: No valid events extracted from trace, skipping:", trace)
            continue  # Skip traces with no valid events

        # Sort events by external timestamp to reconstruct the trace order
        events.sort(key=lambda e: e.timestamp.receiver_time or datetime.min)

        assert check_events_in_vocab(events, build_vocab()) == None

        # build up timings list based on receiver_time differences
        timings: List[float] = [0]
        for i in range(1, len(events)):
            timings.append(
                (
                    events[i].timestamp.receiver_time
                    - events[i - 1].timestamp.receiver_time
                )
                / timedelta(milliseconds=1)
            )

        processed_traces.append(
            {
                "events": events,
                "timings": timings,
                "rejected_events": dict(
                    rejected_events
                ),  # Include rejected events for QA purposes
            }
        )

    return processed_traces


# Copied over from Heraklit Step Generator Output
vocab_steps = [
    "AGV move HBW to DPS",
    "AGV move HBW to MILL",
    "AGV move HBW to DRILL",
    "AGV move HBW to AIQS",
    "AGV move DPS to HBW",
    "AGV move DPS to MILL",
    "AGV move DPS to DRILL",
    "AGV move DPS to AIQS",
    "AGV move MILL to HBW",
    "AGV move MILL to DPS",
    "AGV move MILL to DRILL",
    "AGV move MILL to AIQS",
    "AGV move DRILL to HBW",
    "AGV move DRILL to DPS",
    "AGV move DRILL to MILL",
    "AGV move DRILL to AIQS",
    "AGV move AIQS to HBW",
    "AGV move AIQS to DPS",
    "AGV move AIQS to MILL",
    "AGV move AIQS to DRILL",
    "HBW Pick",
    "HBW Picked",
    "HBW Pick Failed",
    "HBW Drop",
    "HBW Dropped",
    "HBW Drop Failed",
    "DPS RED Pick",
    "DPS RED Drop",
    "DPS WHITE Pick",
    "DPS WHITE Drop",
    "DPS BLUE Pick",
    "DPS BLUE Drop",
    "DPS Picked",
    "DPS Pick Failed",
    "DPS Dropped",
    "DPS Drop Failed",
    "DRILL Pick",
    "DRILL Picked",
    "DRILL Pick Failed",
    "DRILL Drop",
    "DRILL Dropped",
    "DRILL Drop Failed",
    "DRILL Drill",
    "DRILL Drilled",
    "DRILL Drill Failed",
    "MILL Pick",
    "MILL Picked",
    "MILL Pick Failed",
    "MILL Drop",
    "MILL Dropped",
    "MILL Drop Failed",
    "MILL Mill",
    "MILL Milled",
    "MILL Mill Failed",
    "AIQS Pick",
    "AIQS Picked",
    "AIQS Pick Failed",
    "AIQS Drop",
    "AIQS Dropped",
    "AIQS Drop Failed",
    "AIQS Check",
    "AIQS Checked",
    "AIQS Check Failed",
]


def build_vocab() -> Dict[str, int]:
    vocab = {
        "<PAD>": 0,
        "<BOS>": 1,
        "<EOS>": 2,
        NA: 3,
    }  # Start with NA and some generic tokens in vocab

    c = 4
    for step in vocab_steps:
        vocab[step] = c
        c += 1

    return vocab


def check_events_in_vocab(
    events: [ShadowEvent], vocab: Dict[str, int]
) -> Optional[RejectReason]:
    for event in events:
        if event.token not in vocab:
            print(f"Value not in Vocab: {event.token}")
            return RejectReason.INVALID_PAYLOAD
    return None
