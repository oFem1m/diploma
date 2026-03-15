import asyncio
import json
import threading
import time

import pytest
import uvicorn
import websockets

import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from main import app
from fastapi.testclient import TestClient


TEST_PORT = 18765


def _hello_msg():
    return json.dumps({
        "header": {
            "v": 1, "type": "hello", "msg_id": "test-hello", "ts": "2026-01-01T00:00:00Z",
            "session_id": None, "reply_to": None,
            "auth": {"scheme": "none", "token": None},
            "trace": {"client_req_id": "hello-1", "job_id": None, "span_id": None},
            "stream": {"stream_id": None, "seq": None, "total": None, "is_last": None},
            "compression": {"algo": "none", "original_bytes": None},
        },
        "payload": {
            "client": {"name": "test", "version": "0.1.0", "platform": "test", "lang": "python"},
            "wants": {"progress_stream": True, "chunking": False},
        },
    })


def _submit_msg(req_id="req-001", method="bbo.classic", generations=5, dims=2):
    return json.dumps({
        "header": {
            "v": 1, "type": "job.submit", "msg_id": f"test-submit-{req_id}", "ts": "2026-01-01T00:00:01Z",
            "session_id": None, "reply_to": None,
            "auth": {"scheme": "none", "token": None},
            "trace": {"client_req_id": req_id, "job_id": None, "span_id": None},
            "stream": {"stream_id": None, "seq": None, "total": None, "is_last": None},
            "compression": {"algo": "none", "original_bytes": None},
        },
        "payload": {
            "objective": {"kind": "builtin", "name": "sphere", "minimize": True},
            "problem": {"dims": dims, "bounds": {"kind": "uniform", "low": -5.0, "high": 5.0}},
            "method": {"name": method, "config": {"pop_size": 10, "max_generations": generations, "random_seed": 42}},
            "streaming": {"mode": "every_k", "every_k": 5,
                          "include": {"best_x": True, "best_f": True}},
            "output": {"return_final_population": True, "return_final_fitness": True},
        },
    })


def _ping_msg():
    return json.dumps({
        "header": {
            "v": 1, "type": "ping", "msg_id": "test-ping", "ts": "2026-01-01T00:00:00Z",
            "session_id": None, "reply_to": None,
            "auth": {"scheme": "none", "token": None},
            "trace": {"client_req_id": None, "job_id": None, "span_id": None},
            "stream": {"stream_id": None, "seq": None, "total": None, "is_last": None},
            "compression": {"algo": "none", "original_bytes": None},
        },
        "payload": {},
    })


@pytest.fixture(scope="module")
def server():
    config = uvicorn.Config(app, host="127.0.0.1", port=TEST_PORT, log_level="warning")
    srv = uvicorn.Server(config)
    thread = threading.Thread(target=srv.run, daemon=True)
    thread.start()
    time.sleep(1)
    yield f"ws://127.0.0.1:{TEST_PORT}/ws/optimize"
    srv.should_exit = True
    thread.join(timeout=3)


class TestWebSocketUnit:
    def test_health_endpoint(self):
        client = TestClient(app)
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"


class TestWebSocketIntegration:
    @pytest.mark.asyncio
    async def test_hello_handshake(self, server):
        async with websockets.connect(server) as ws:
            await ws.send(_hello_msg())
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            assert resp["header"]["type"] == "hello"
            caps = resp["payload"]["capabilities"]
            assert "bbo.classic" in caps["methods"]
            assert "pso" in caps["methods"]
            assert len(caps["methods"]) == 7

    @pytest.mark.asyncio
    async def test_ping_pong(self, server):
        async with websockets.connect(server) as ws:
            await ws.send(_hello_msg())
            await asyncio.wait_for(ws.recv(), timeout=5)

            await ws.send(_ping_msg())
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            assert resp["header"]["type"] == "pong"

    @pytest.mark.asyncio
    async def test_full_job_lifecycle(self, server):
        async with websockets.connect(server) as ws:
            await ws.send(_hello_msg())
            await asyncio.wait_for(ws.recv(), timeout=5)

            await ws.send(_submit_msg(req_id="lifecycle-1", generations=10))

            messages = []
            for _ in range(50):
                raw = await asyncio.wait_for(ws.recv(), timeout=10)
                resp = json.loads(raw)
                mtype = resp["header"]["type"]
                if mtype == "ping":
                    continue
                messages.append(mtype)
                if mtype == "job.finished":
                    break

            assert messages[0] == "job.accepted"
            assert "job.started" in messages
            assert "job.result" in messages
            assert messages[-1] == "job.finished"

    @pytest.mark.asyncio
    async def test_job_result_content(self, server):
        async with websockets.connect(server) as ws:
            await ws.send(_hello_msg())
            await asyncio.wait_for(ws.recv(), timeout=5)

            await ws.send(_submit_msg(req_id="result-1", generations=5))

            result_payload = None
            finished = False
            for _ in range(50):
                raw = await asyncio.wait_for(ws.recv(), timeout=10)
                resp = json.loads(raw)
                mtype = resp["header"]["type"]
                if mtype == "job.result":
                    result_payload = resp["payload"]
                if mtype == "job.finished":
                    finished = True
                    break

            assert finished
            assert result_payload is not None
            assert "best_x" in result_payload["result"]
            assert "best_f" in result_payload["result"]
            assert "history_best_f" in result_payload["result"]
            assert result_payload["metrics"]["method"] == "bbo.classic"
            assert result_payload["metrics"]["wall_time_ms"] >= 0
            assert len(result_payload["result"]["best_x"]) == 2

    @pytest.mark.asyncio
    async def test_validation_error(self, server):
        async with websockets.connect(server) as ws:
            await ws.send(_hello_msg())
            await asyncio.wait_for(ws.recv(), timeout=5)

            bad_submit = json.dumps({
                "header": {
                    "v": 1, "type": "job.submit", "msg_id": "bad", "ts": "2026-01-01T00:00:00Z",
                    "session_id": None, "reply_to": None,
                    "auth": {"scheme": "none", "token": None},
                    "trace": {"client_req_id": "bad-req", "job_id": None, "span_id": None},
                    "stream": {"stream_id": None, "seq": None, "total": None, "is_last": None},
                    "compression": {"algo": "none", "original_bytes": None},
                },
                "payload": {
                    "objective": {"kind": "builtin", "name": "sphere", "minimize": True},
                    "problem": {"dims": 0, "bounds": {"kind": "uniform", "low": -5, "high": 5}},
                    "method": {"name": "bbo.classic", "config": {}},
                },
            })
            await ws.send(bad_submit)
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            assert resp["header"]["type"] == "error"
            assert resp["payload"]["code"] == "VALIDATION_ERROR"

    @pytest.mark.asyncio
    async def test_unknown_message_type(self, server):
        async with websockets.connect(server) as ws:
            await ws.send(_hello_msg())
            await asyncio.wait_for(ws.recv(), timeout=5)

            unknown = json.dumps({
                "header": {
                    "v": 1, "type": "unknown_type", "msg_id": "unk", "ts": "2026-01-01T00:00:00Z",
                    "session_id": None, "reply_to": None,
                    "auth": {"scheme": "none", "token": None},
                    "trace": {"client_req_id": None, "job_id": None, "span_id": None},
                    "stream": {"stream_id": None, "seq": None, "total": None, "is_last": None},
                    "compression": {"algo": "none", "original_bytes": None},
                },
                "payload": {},
            })
            await ws.send(unknown)
            resp = json.loads(await asyncio.wait_for(ws.recv(), timeout=5))
            assert resp["header"]["type"] == "error"
            assert "unknown" in resp["payload"]["message"]

    @pytest.mark.asyncio
    async def test_pso_method(self, server):
        async with websockets.connect(server) as ws:
            await ws.send(_hello_msg())
            await asyncio.wait_for(ws.recv(), timeout=5)

            submit = json.dumps({
                "header": {
                    "v": 1, "type": "job.submit", "msg_id": "pso-test", "ts": "2026-01-01T00:00:00Z",
                    "session_id": None, "reply_to": None,
                    "auth": {"scheme": "none", "token": None},
                    "trace": {"client_req_id": "pso-req", "job_id": None, "span_id": None},
                    "stream": {"stream_id": None, "seq": None, "total": None, "is_last": None},
                    "compression": {"algo": "none", "original_bytes": None},
                },
                "payload": {
                    "objective": {"kind": "builtin", "name": "rastrigin", "minimize": True},
                    "problem": {"dims": 3, "bounds": {"kind": "uniform", "low": -5.12, "high": 5.12}},
                    "method": {"name": "pso", "config": {"swarm_size": 15, "max_generations": 10, "random_seed": 7}},
                    "streaming": {"mode": "none"},
                    "output": {"return_final_population": False},
                },
            })
            await ws.send(submit)

            result_payload = None
            for _ in range(20):
                raw = await asyncio.wait_for(ws.recv(), timeout=10)
                resp = json.loads(raw)
                if resp["header"]["type"] == "job.result":
                    result_payload = resp["payload"]
                if resp["header"]["type"] == "job.finished":
                    break

            assert result_payload is not None
            assert result_payload["metrics"]["method"] == "pso"
            assert result_payload["result"]["best_f"] >= 0
