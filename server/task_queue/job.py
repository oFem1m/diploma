from __future__ import annotations

import asyncio
import threading
import time
import uuid
from enum import Enum
from typing import Any, Dict, Optional


class JobState(str, Enum):
    QUEUED = "queued"
    STARTED = "started"
    RUNNING = "running"
    SUCCEEDED = "succeeded"
    FAILED = "failed"
    CANCELLED = "cancelled"
    TIMEOUT = "timeout"


class Job:
    def __init__(self, client_req_id: str, payload: Dict[str, Any], priority: int = 1):
        self.job_id: str = f"job-{uuid.uuid4().hex[:8]}"
        self.client_req_id: str = client_req_id
        self.state: JobState = JobState.QUEUED
        self.payload: Dict[str, Any] = payload
        self.priority: int = priority
        self.created_at: float = time.time()
        self.started_at: Optional[float] = None
        self.finished_at: Optional[float] = None
        self.progress_queue: asyncio.Queue = asyncio.Queue()
        self.cancel_event: threading.Event = threading.Event()
        self.result: Optional[Dict[str, Any]] = None
        self.error: Optional[str] = None
        self.ws = None
        self.last_progress: Optional[Dict[str, Any]] = None
        self.disconnect_task: Optional[asyncio.Task] = None

    def mark_started(self):
        self.state = JobState.RUNNING
        self.started_at = time.time()

    def mark_succeeded(self, result: Dict[str, Any]):
        self.state = JobState.SUCCEEDED
        self.result = result
        self.finished_at = time.time()

    def mark_failed(self, error: str):
        self.state = JobState.FAILED
        self.error = error
        self.finished_at = time.time()

    def mark_cancelled(self):
        self.state = JobState.CANCELLED
        self.cancel_event.set()
        self.finished_at = time.time()

    def mark_timeout(self):
        self.state = JobState.TIMEOUT
        self.cancel_event.set()
        self.finished_at = time.time()

    @property
    def is_terminal(self) -> bool:
        return self.state in (JobState.SUCCEEDED, JobState.FAILED, JobState.CANCELLED, JobState.TIMEOUT)
