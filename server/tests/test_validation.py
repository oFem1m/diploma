import pytest
from config import Limits
from protocol.types import JobSubmitPayload
from protocol.validation import validate_job_submit


def _make_payload(**overrides):
    base = {
        "objective": {"kind": "builtin", "name": "sphere", "minimize": True},
        "problem": {"dims": 2, "bounds": {"kind": "uniform", "low": -5, "high": 5}},
        "method": {"name": "bbo.classic", "config": {"pop_size": 20, "max_generations": 50}},
    }
    for key, val in overrides.items():
        parts = key.split(".")
        d = base
        for p in parts[:-1]:
            d = d[p]
        d[parts[-1]] = val
    return JobSubmitPayload.model_validate(base)


LIMITS = Limits()


class TestValidation:
    def test_valid_payload_passes(self):
        payload = _make_payload()
        assert validate_job_submit(payload, LIMITS) is None

    def test_dims_zero(self):
        payload = _make_payload(**{"problem.dims": 0})
        errors = validate_job_submit(payload, LIMITS)
        assert errors
        assert any("dims" in e for e in errors)

    def test_dims_exceeds_limit(self):
        payload = _make_payload(**{"problem.dims": 200})
        errors = validate_job_submit(payload, LIMITS)
        assert errors
        assert any("limit" in e for e in errors)

    def test_bounds_low_ge_high(self):
        payload = _make_payload(**{"problem.bounds": {"kind": "uniform", "low": 5, "high": 5}})
        errors = validate_job_submit(payload, LIMITS)
        assert errors
        assert any("low" in e for e in errors)

    def test_per_dim_bounds_wrong_length(self):
        payload = _make_payload(
            **{"problem.dims": 3, "problem.bounds": {"kind": "per_dim", "items": [[-1, 1], [-2, 2]]}}
        )
        errors = validate_job_submit(payload, LIMITS)
        assert errors
        assert any("length" in e for e in errors)

    def test_unsupported_method(self):
        payload = _make_payload(**{"method.name": "genetic_algorithm"})
        errors = validate_job_submit(payload, LIMITS)
        assert errors
        assert any("unsupported method" in e for e in errors)

    def test_pop_size_too_small(self):
        payload = _make_payload(**{"method.config": {"pop_size": 1, "max_generations": 10}})
        errors = validate_job_submit(payload, LIMITS)
        assert errors
        assert any("pop_size" in e for e in errors)

    def test_pop_size_exceeds_limit(self):
        payload = _make_payload(**{"method.config": {"pop_size": 600, "max_generations": 10}})
        errors = validate_job_submit(payload, LIMITS)
        assert errors
        assert any("limit" in e for e in errors)

    def test_max_generations_exceeds_limit(self):
        payload = _make_payload(**{"method.config": {"pop_size": 20, "max_generations": 20000}})
        errors = validate_job_submit(payload, LIMITS)
        assert errors

    def test_unknown_builtin_function(self):
        payload = _make_payload(**{"objective.name": "rosenbrock"})
        errors = validate_job_submit(payload, LIMITS)
        assert errors
        assert any("unsupported builtin" in e for e in errors)

    def test_bukin6_requires_2d(self):
        payload = _make_payload(**{"objective.name": "bukin6", "problem.dims": 5})
        errors = validate_job_submit(payload, LIMITS)
        assert errors
        assert any("bukin6" in e for e in errors)

    def test_bukin6_2d_passes(self):
        payload = _make_payload(**{"objective.name": "bukin6", "problem.dims": 2})
        assert validate_job_submit(payload, LIMITS) is None

    def test_expression_without_expr(self):
        payload = _make_payload(**{"objective.kind": "expression", "objective.name": None})
        errors = validate_job_submit(payload, LIMITS)
        assert errors
        assert any("expr" in e for e in errors)

    def test_pso_validation(self):
        payload = _make_payload(**{
            "method.name": "pso",
            "method.config": {"swarm_size": 1, "max_generations": 10},
        })
        errors = validate_job_submit(payload, LIMITS)
        assert errors
        assert any("swarm_size" in e for e in errors)
