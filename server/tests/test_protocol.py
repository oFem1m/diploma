import json
import pytest
from protocol.envelope import build_envelope, parse_envelope
from protocol.types import (
    Envelope, Header, JobSubmitPayload, ErrorPayload,
    Objective, Problem, BoundsUniform, Method,
)


class TestEnvelope:
    def test_build_envelope_has_required_fields(self):
        msg = build_envelope("hello", {"server": {"name": "test"}})
        assert msg["header"]["v"] == 1
        assert msg["header"]["type"] == "hello"
        assert msg["header"]["msg_id"]
        assert msg["header"]["ts"]
        assert msg["payload"]["server"]["name"] == "test"

    def test_build_envelope_with_reply_to(self):
        msg = build_envelope("pong", {}, reply_to="msg-123")
        assert msg["header"]["reply_to"] == "msg-123"

    def test_build_envelope_with_trace(self):
        trace = {"client_req_id": "req-1", "job_id": "job-abc", "span_id": None}
        msg = build_envelope("job.accepted", {"job_id": "job-abc"}, trace=trace)
        assert msg["header"]["trace"]["job_id"] == "job-abc"

    def test_parse_envelope_valid(self):
        raw = json.dumps(build_envelope("ping", {}))
        env = parse_envelope(raw)
        assert isinstance(env, Envelope)
        assert env.header.type == "ping"
        assert env.header.v == 1

    def test_parse_envelope_invalid_json(self):
        with pytest.raises(Exception):
            parse_envelope("not json")

    def test_parse_envelope_missing_header(self):
        with pytest.raises(Exception):
            parse_envelope('{"payload": {}}')


class TestTypes:
    def test_job_submit_payload_builtin(self):
        data = {
            "objective": {"kind": "builtin", "name": "sphere", "minimize": True},
            "problem": {"dims": 2, "bounds": {"kind": "uniform", "low": -5, "high": 5}},
            "method": {"name": "bbo.classic", "config": {"pop_size": 20}},
        }
        payload = JobSubmitPayload.model_validate(data)
        assert payload.objective.kind.value == "builtin"
        assert payload.problem.dims == 2
        assert payload.method.name == "bbo.classic"

    def test_job_submit_payload_expression(self):
        data = {
            "objective": {"kind": "expression", "expr": "x0*x0 + x1*x1", "minimize": True},
            "problem": {"dims": 2, "bounds": {"kind": "uniform", "low": -5, "high": 5}},
            "method": {"name": "pso", "config": {"swarm_size": 30}},
        }
        payload = JobSubmitPayload.model_validate(data)
        assert payload.objective.expr == "x0*x0 + x1*x1"

    def test_problem_get_bounds_list_uniform(self):
        data = {
            "objective": {"kind": "builtin", "name": "sphere", "minimize": True},
            "problem": {"dims": 3, "bounds": {"kind": "uniform", "low": -1, "high": 1}},
            "method": {"name": "bbo.classic"},
        }
        payload = JobSubmitPayload.model_validate(data)
        bl = payload.problem.get_bounds_list()
        assert len(bl) == 3
        assert bl[0] == (-1, 1)

    def test_problem_get_bounds_list_per_dim(self):
        data = {
            "objective": {"kind": "builtin", "name": "sphere", "minimize": True},
            "problem": {"dims": 2, "bounds": {"kind": "per_dim", "items": [[-1, 1], [-2, 2]]}},
            "method": {"name": "bbo.classic"},
        }
        payload = JobSubmitPayload.model_validate(data)
        bl = payload.problem.get_bounds_list()
        assert bl == [(-1, 1), (-2, 2)]

    def test_error_payload(self):
        ep = ErrorPayload(code="VALIDATION_ERROR", message="bad dims")
        assert ep.retryable is False
