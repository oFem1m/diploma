from __future__ import annotations

import asyncio
import json
import logging
from datetime import datetime, timezone

from fastapi import WebSocket, WebSocketDisconnect

from config import ServerConfig
from protocol.envelope import build_envelope, parse_envelope
from protocol.types import (
    HelloClientPayload,
    JobSubmitPayload,
    CancelPayload,
    JobStatusGetPayload,
)
from protocol.validation import validate_job_submit, SUPPORTED_METHODS, SUPPORTED_BUILTINS
from task_queue.job_queue import JobQueue, QueueOverflowError

logger = logging.getLogger(__name__)


class ConnectionHandler:
    def __init__(self, ws: WebSocket, job_queue: JobQueue, config: ServerConfig):
        self.ws = ws
        self.job_queue = job_queue
        self.config = config
        self._active_jobs: set[str] = set()
        self._ping_task = None

    async def handle(self):
        await self.ws.accept()
        logger.info("client connected")

        try:
            await self._wait_hello()
            self._ping_task = asyncio.ensure_future(self._ping_loop())
            await self._message_loop()
        except WebSocketDisconnect:
            logger.info("client disconnected")
        except Exception:
            logger.exception("connection error")
        finally:
            if self._ping_task:
                self._ping_task.cancel()
            for job_id in self._active_jobs:
                self.job_queue.detach_ws_later(
                    job_id,
                    self.ws,
                    self.config.reconnect_grace_s,
                )

    async def _wait_hello(self):
        raw = await self.ws.receive_text()
        envelope = parse_envelope(raw)

        if envelope.header.type != "hello":
            await self._send_error(
                "BAD_REQUEST",
                "first message must be hello",
                reply_to=envelope.header.msg_id,
            )
            return

        capabilities = {
            "methods": list(SUPPORTED_METHODS),
            "objective_kinds": ["builtin", "expression"],
            "progress_modes": ["per_generation", "every_k", "none"],
            "max_payload_bytes": self.config.limits.max_payload_bytes,
        }

        await self._send("hello", {
            "server": {"name": "optimizer-server", "version": "0.1.0"},
            "capabilities": capabilities,
        }, reply_to=envelope.header.msg_id)

    async def _message_loop(self):
        while True:
            raw = await self.ws.receive_text()
            try:
                envelope = parse_envelope(raw)
            except Exception as e:
                await self._send_error("BAD_REQUEST", f"invalid message: {e}")
                continue

            msg_type = envelope.header.type
            handlers = {
                "job.submit": self._handle_submit,
                "cancel": self._handle_cancel,
                "job.status.get": self._handle_status_get,
                "ping": self._handle_ping,
                "pong": self._handle_pong,
            }

            handler = handlers.get(msg_type)
            if handler:
                await handler(envelope)
            else:
                await self._send_error(
                    "BAD_REQUEST",
                    f"unknown message type: {msg_type}",
                    reply_to=envelope.header.msg_id,
                )

    async def _handle_submit(self, envelope):
        try:
            payload = JobSubmitPayload.model_validate(envelope.payload)
        except Exception as e:
            await self._send_error(
                "VALIDATION_ERROR",
                f"invalid payload: {e}",
                reply_to=envelope.header.msg_id,
            )
            return

        errors = validate_job_submit(payload, self.config.limits)
        if errors:
            await self._send_error(
                "VALIDATION_ERROR",
                "; ".join(errors),
                reply_to=envelope.header.msg_id,
            )
            return

        client_req_id = envelope.header.trace.client_req_id or envelope.header.msg_id
        priority = payload.job.priority.value if hasattr(payload.job.priority, "value") else payload.job.priority

        try:
            job, is_new = await self.job_queue.submit(
                payload=payload.model_dump(),
                client_req_id=client_req_id,
                priority=priority,
                ws=self.ws,
            )
        except QueueOverflowError:
            await self._send_error(
                "QUEUE_OVERFLOW",
                "job queue is full, try again later",
                reply_to=envelope.header.msg_id,
                retryable=True,
            )
            return

        self._active_jobs.add(job.job_id)

        position, eta_ms = self.job_queue.get_queue_position(job.job_id)
        trace = {
            "client_req_id": client_req_id,
            "job_id": job.job_id,
            "span_id": None,
        }
        await self._send("job.accepted", {
            "job_id": job.job_id,
            "state": "queued",
            "queue": {"position": position, "eta_ms": eta_ms},
        }, reply_to=envelope.header.msg_id, trace=trace)

    async def _handle_cancel(self, envelope):
        try:
            payload = CancelPayload.model_validate(envelope.payload)
        except Exception as e:
            await self._send_error("BAD_REQUEST", str(e), reply_to=envelope.header.msg_id)
            return

        job = self.job_queue.get_job(payload.job_id)
        if not job:
            await self._send_error("JOB_NOT_FOUND", f"job {payload.job_id} not found",
                                   reply_to=envelope.header.msg_id)
            return

        was_queued = job.state.value == "queued"
        success = self.job_queue.cancel(payload.job_id)
        if not success:
            await self._send_error("JOB_ALREADY_FINISHED",
                                   f"job {payload.job_id} already in state {job.state.value}",
                                   reply_to=envelope.header.msg_id)
            return

        if was_queued:
            trace = {
                "client_req_id": job.client_req_id,
                "job_id": job.job_id,
                "span_id": None,
            }
            await self._send("job.finished", {
                "job_id": job.job_id,
                "final_state": "cancelled",
                "finished_at": datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
            }, reply_to=envelope.header.msg_id, trace=trace)

    async def _handle_status_get(self, envelope):
        try:
            payload = JobStatusGetPayload.model_validate(envelope.payload)
        except Exception as e:
            await self._send_error("BAD_REQUEST", str(e), reply_to=envelope.header.msg_id)
            return

        job = self.job_queue.get_job(payload.job_id)
        if not job:
            await self._send_error("JOB_NOT_FOUND", f"job {payload.job_id} not found",
                                   reply_to=envelope.header.msg_id)
            return

        client_req_id = envelope.header.trace.client_req_id
        if client_req_id and client_req_id != job.client_req_id:
            await self._send_error("JOB_NOT_FOUND", f"job {payload.job_id} not found",
                                   reply_to=envelope.header.msg_id)
            return

        if not job.is_terminal:
            self.job_queue.attach_ws(job.job_id, self.ws)
            self._active_jobs.add(job.job_id)

        status_payload = {
            "job_id": job.job_id,
            "state": job.state.value,
            "queue": None,
            "progress": job.last_progress,
        }

        if job.state.value == "queued":
            pos, eta = self.job_queue.get_queue_position(job.job_id)
            status_payload["queue"] = {"position": pos, "eta_ms": eta}

        trace = {
            "client_req_id": job.client_req_id,
            "job_id": job.job_id,
            "span_id": None,
        }
        await self._send("job.status", status_payload,
                         reply_to=envelope.header.msg_id, trace=trace)
        if job.is_terminal:
            await self._send_terminal_snapshot(job, reply_to=envelope.header.msg_id, trace=trace)

    async def _handle_ping(self, envelope):
        await self._send("pong", {}, reply_to=envelope.header.msg_id)

    async def _handle_pong(self, envelope):
        return

    async def _send_terminal_snapshot(self, job, *, reply_to: str = None, trace: dict = None):
        if job.state.value == "succeeded" and job.result:
            history = job.result.get("history_best_f", [])
            await self._send("job.result", {
                "job_id": job.job_id,
                "result": {
                    "best_x": job.result["best_x"],
                    "best_f": job.result["best_f"],
                    "history_best_f": history,
                    "final_population": job.result.get("final_population"),
                    "final_fitness": job.result.get("final_fitness"),
                    "final_positions": job.result.get("final_positions"),
                    "final_velocities": job.result.get("final_velocities"),
                },
                "metrics": {
                    "method": job.result.get("method", "unknown"),
                    "iterations": len(history),
                    "evals": len(history),
                    "wall_time_ms": job.result.get("wall_time_ms", 0),
                    "seed": job.result.get("seed"),
                },
            }, reply_to=reply_to, trace=trace)
        await self._send("job.finished", {
            "job_id": job.job_id,
            "final_state": job.state.value,
            "finished_at": datetime.now(timezone.utc).isoformat(timespec="milliseconds"),
        }, reply_to=reply_to, trace=trace)

    async def _ping_loop(self):
        try:
            while True:
                await asyncio.sleep(self.config.ping_interval_s)
                await self._send("ping", {})
        except asyncio.CancelledError:
            pass

    async def _send(self, msg_type: str, payload: dict, *,
                    reply_to: str = None, trace: dict = None):
        msg = build_envelope(msg_type, payload, reply_to=reply_to, trace=trace)
        await self.ws.send_text(json.dumps(msg, default=str))

    async def _send_error(self, code: str, message: str, *,
                          reply_to: str = None, retryable: bool = False):
        await self._send("error", {
            "code": code,
            "message": message,
            "details": None,
            "retryable": retryable,
        }, reply_to=reply_to)
