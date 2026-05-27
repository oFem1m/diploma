from __future__ import annotations

import asyncio
import logging
import traceback
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from typing import Any, Dict

from config import ServerConfig
from optimizer.runner import run_optimization, CancelledError
from protocol.envelope import build_envelope
from task_queue.job import Job, JobState
from task_queue.job_queue import JobQueue

logger = logging.getLogger(__name__)


class Worker:
    def __init__(self, worker_id: str, job_queue: JobQueue, config: ServerConfig):
        self.worker_id = worker_id
        self.job_queue = job_queue
        self.config = config
        self._executor = ThreadPoolExecutor(max_workers=1, thread_name_prefix=f"opt-{worker_id}")
        self._running = False

    async def start(self):
        self._running = True
        logger.info("worker %s started", self.worker_id)
        while self._running:
            try:
                job = await self.job_queue.get_next()
                if job.is_terminal:
                    continue
                await self._run_job(job)
            except asyncio.CancelledError:
                break
            except Exception:
                logger.exception("worker %s unexpected error", self.worker_id)
                await asyncio.sleep(1)

    def stop(self):
        self._running = False
        self._executor.shutdown(wait=False)

    async def _run_job(self, job: Job):
        job.mark_started()
        await self._send(job, "job.started", {
            "job_id": job.job_id,
            "started_at": datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
            "worker": {"id": self.worker_id, "host": "localhost"},
        })

        loop = asyncio.get_event_loop()

        def on_progress(data: Dict):
            try:
                loop.call_soon_threadsafe(job.progress_queue.put_nowait, data)
            except Exception:
                pass

        progress_task = asyncio.ensure_future(self._stream_progress(job))

        timeout_ms = job.payload.get("job", {})
        if hasattr(timeout_ms, "timeout_ms"):
            timeout_ms = timeout_ms.timeout_ms
        elif isinstance(timeout_ms, dict):
            timeout_ms = timeout_ms.get("timeout_ms")
        timeout_s = (timeout_ms or self.config.default_timeout_ms) / 1000.0

        try:
            result = await asyncio.wait_for(
                loop.run_in_executor(
                    self._executor,
                    run_optimization,
                    self._serialize_payload(job.payload),
                    on_progress,
                    job.cancel_event,
                ),
                timeout=timeout_s,
            )

            job.progress_queue.put_nowait(None)
            await progress_task

            if job.state == JobState.CANCELLED:
                await self._send_finished(job, "cancelled")
                return

            job.mark_succeeded(result)

            max_gen = result.get("history_best_f", [])
            iterations = len(max_gen)

            await self._send(job, "job.result", {
                "job_id": job.job_id,
                "result": {
                    "best_x": result["best_x"],
                    "best_f": result["best_f"],
                    "history_best_f": result.get("history_best_f", []),
                    "final_population": result.get("final_population"),
                    "final_fitness": result.get("final_fitness"),
                    "final_positions": result.get("final_positions"),
                    "final_velocities": result.get("final_velocities"),
                },
                "metrics": {
                    "method": result.get("method", "unknown"),
                    "iterations": iterations,
                    "evals": iterations,
                    "wall_time_ms": result.get("wall_time_ms", 0),
                    "seed": result.get("seed"),
                },
            })

            await self._send_finished(job, "succeeded")

        except asyncio.TimeoutError:
            job.mark_timeout()
            job.progress_queue.put_nowait(None)
            await progress_task
            await self._send_error(job, "TIMEOUT", "job exceeded timeout")
            await self._send_finished(job, "timeout")

        except CancelledError:
            job.mark_cancelled()
            job.progress_queue.put_nowait(None)
            await progress_task
            await self._send_finished(job, "cancelled")

        except Exception as e:
            job.mark_failed(str(e))
            job.progress_queue.put_nowait(None)
            await progress_task
            logger.exception("job %s failed", job.job_id)
            await self._send_error(job, "EXECUTION_ERROR", str(e))
            await self._send_finished(job, "failed")

    async def _stream_progress(self, job: Job):
        streaming = job.payload.get("streaming", {})
        if hasattr(streaming, "model_dump"):
            streaming = streaming.model_dump()

        mode = streaming.get("mode", "per_generation")
        every_k = streaming.get("every_k", 1)
        include = streaming.get("include", {})

        if mode == "none":
            while True:
                data = await job.progress_queue.get()
                if data is None:
                    break
            return

        last_sent = -1
        while True:
            data = await job.progress_queue.get()
            if data is None:
                break

            iteration = data.get("iteration", 0)
            if mode == "every_k" and (iteration - last_sent) < every_k:
                continue

            last_sent = iteration
            progress_payload = {
                "job_id": job.job_id,
                "progress": {
                    "iteration": data["iteration"],
                    "max_iterations": data["max_iterations"],
                    "best_f": data["best_f"],
                    "elapsed_ms": data.get("elapsed_ms", 0),
                },
                "snapshots": None,
            }

            if include.get("best_x", True):
                progress_payload["progress"]["best_x"] = data.get("best_x")
            if include.get("best_f", True):
                pass
            if data.get("history_best_f_tail"):
                progress_payload["progress"]["history_best_f_tail"] = data["history_best_f_tail"]

            job.last_progress = progress_payload["progress"]
            await self._send(job, "job.progress", progress_payload)

    async def _send_finished(self, job: Job, final_state: str):
        await self._send(job, "job.finished", {
            "job_id": job.job_id,
            "final_state": final_state,
            "finished_at": datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
        })

    async def _send_error(self, job: Job, code: str, message: str):
        await self._send(job, "error", {
            "code": code,
            "message": message,
            "details": None,
            "retryable": False,
        })

    async def _send(self, job: Job, msg_type: str, payload: Dict[str, Any]):
        if not job.ws:
            return
        try:
            trace = {
                "client_req_id": job.client_req_id,
                "job_id": job.job_id,
                "span_id": None,
            }
            msg = build_envelope(msg_type, payload, trace=trace)
            import json
            await job.ws.send_text(json.dumps(msg, default=str))
        except Exception:
            logger.debug("failed to send %s to job %s", msg_type, job.job_id)

    def _serialize_payload(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        result = {}
        for key, val in payload.items():
            if hasattr(val, "model_dump"):
                result[key] = val.model_dump()
            else:
                result[key] = val
        return result
