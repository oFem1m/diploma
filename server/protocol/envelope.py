from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Optional

from protocol.types import Envelope, Header


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def _uuid() -> str:
    return str(uuid.uuid4())


def build_envelope(
    msg_type: str,
    payload: Dict[str, Any],
    *,
    reply_to: Optional[str] = None,
    trace: Optional[Dict[str, Any]] = None,
    stream: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    header = {
        "v": 1,
        "type": msg_type,
        "msg_id": _uuid(),
        "ts": _now_iso(),
        "session_id": None,
        "reply_to": reply_to,
        "auth": {"scheme": "none", "token": None},
        "trace": trace or {"client_req_id": None, "job_id": None, "span_id": None},
        "stream": stream or {"stream_id": None, "seq": None, "total": None, "is_last": None},
        "compression": {"algo": "none", "original_bytes": None},
    }
    return {"header": header, "payload": payload}


def parse_envelope(raw: str) -> Envelope:
    data = json.loads(raw)
    return Envelope.model_validate(data)
