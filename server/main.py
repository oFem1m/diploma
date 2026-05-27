from __future__ import annotations

import asyncio
import logging
import sys
import os
from contextlib import asynccontextmanager

sys.path.insert(0, os.path.dirname(__file__))

import uvicorn
from fastapi import FastAPI, WebSocket

from config import ServerConfig
from task_queue.job_queue import JobQueue
from task_queue.worker import Worker
from ws_handler import ConnectionHandler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

config = ServerConfig()
job_queue = JobQueue(max_size=config.max_queue_size)
workers: list[Worker] = []


@asynccontextmanager
async def lifespan(application: FastAPI):
    worker_tasks = []
    for i in range(config.max_workers):
        w = Worker(worker_id=f"worker-{i+1}", job_queue=job_queue, config=config)
        workers.append(w)
        worker_tasks.append(asyncio.create_task(w.start()))
    logger.info("started %d workers", len(workers))
    yield
    for w in workers:
        w.stop()
    for t in worker_tasks:
        t.cancel()
    logger.info("workers stopped")


app = FastAPI(title="Optimization Server", version="0.1.0", lifespan=lifespan)


@app.websocket("/ws/optimize")
async def websocket_endpoint(ws: WebSocket):
    handler = ConnectionHandler(ws, job_queue, config)
    await handler.handle()


@app.get("/health")
async def health():
    return {
        "status": "ok",
        "workers": len(workers),
        "queue_size": len(job_queue.get_queued_jobs()),
    }


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host=config.host,
        port=config.port,
        log_level="info",
        ws_ping_interval=None,
    )
