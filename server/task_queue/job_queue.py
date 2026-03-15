from __future__ import annotations

import asyncio
import time
from typing import Any, Dict, List, Optional, Tuple

from task_queue.job import Job, JobState
from protocol.types import Priority


PRIORITY_MAP = {
    Priority.high: 0,
    Priority.normal: 1,
    Priority.low: 2,
    "high": 0,
    "normal": 1,
    "low": 2,
}


class JobQueue:
    def __init__(self, max_size: int = 50):
        self._queue: asyncio.PriorityQueue = asyncio.PriorityQueue(maxsize=max_size)
        self._registry: Dict[str, Job] = {}
        self._idempotency: Dict[str, str] = {}
        self._order_counter: int = 0

    async def submit(self, payload: Dict[str, Any], client_req_id: str, priority: str = "normal", ws=None) -> Tuple[Job, bool]:
        if client_req_id in self._idempotency:
            existing_job_id = self._idempotency[client_req_id]
            if existing_job_id in self._registry:
                return self._registry[existing_job_id], False

        priority_int = PRIORITY_MAP.get(priority, 1)
        job = Job(client_req_id=client_req_id, payload=payload, priority=priority_int)
        job.ws = ws

        if self._queue.full():
            raise QueueOverflowError(f"queue full (max {self._queue.maxsize})")

        self._order_counter += 1
        await self._queue.put((priority_int, self._order_counter, job.job_id))
        self._registry[job.job_id] = job
        self._idempotency[client_req_id] = job.job_id

        return job, True

    async def get_next(self) -> Job:
        while True:
            _, _, job_id = await self._queue.get()
            job = self._registry.get(job_id)
            if job and job.state == JobState.QUEUED:
                return job

    def cancel(self, job_id: str) -> bool:
        job = self._registry.get(job_id)
        if not job:
            return False
        if job.is_terminal:
            return False
        job.mark_cancelled()
        return True

    def get_job(self, job_id: str) -> Optional[Job]:
        return self._registry.get(job_id)

    def get_queue_position(self, job_id: str) -> Tuple[int, Optional[int]]:
        position = 0
        for item in self._queue._queue:
            item_job_id = item[2]
            item_job = self._registry.get(item_job_id)
            if item_job and item_job.state == JobState.QUEUED:
                position += 1
                if item_job_id == job_id:
                    return position, position * 5000
        return 0, None

    def get_queued_jobs(self) -> List[Job]:
        return [j for j in self._registry.values() if j.state == JobState.QUEUED]


class QueueOverflowError(Exception):
    pass
