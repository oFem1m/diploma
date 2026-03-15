import threading
import pytest
from optimizer.runner import run_optimization, CancelledError


def _make_submit(method="bbo.classic", generations=10, dims=2):
    return {
        "objective": {"kind": "builtin", "name": "sphere", "minimize": True},
        "problem": {"dims": dims, "bounds": {"kind": "uniform", "low": -5.0, "high": 5.0}},
        "method": {"name": method, "config": {"pop_size": 10, "max_generations": generations, "random_seed": 42}},
        "streaming": {"mode": "per_generation", "every_k": 1, "include": {"best_x": True, "best_f": True}},
        "output": {"return_final_population": True, "return_final_fitness": True},
    }


class TestRunner:
    def test_basic_run(self):
        result = run_optimization(_make_submit())
        assert result["best_f"] >= 0
        assert len(result["best_x"]) == 2
        assert len(result["history_best_f"]) > 0
        assert result["wall_time_ms"] >= 0
        assert result["method"] == "bbo.classic"

    def test_progress_callback(self):
        progress_data = []
        result = run_optimization(
            _make_submit(generations=20),
            on_progress=lambda d: progress_data.append(d),
        )
        assert len(progress_data) == 20
        assert progress_data[0]["iteration"] == 0
        assert progress_data[-1]["iteration"] == 19
        assert all("best_f" in d for d in progress_data)
        assert all("elapsed_ms" in d for d in progress_data)

    def test_cancel(self):
        cancel = threading.Event()
        progress_count = [0]

        def on_progress(d):
            progress_count[0] += 1
            if progress_count[0] >= 3:
                cancel.set()

        with pytest.raises(CancelledError):
            run_optimization(
                _make_submit(generations=1000),
                on_progress=on_progress,
                cancel_event=cancel,
            )
        assert progress_count[0] >= 3
        assert progress_count[0] < 1000

    def test_pso_run(self):
        submit = {
            "objective": {"kind": "builtin", "name": "rastrigin", "minimize": True},
            "problem": {"dims": 3, "bounds": {"kind": "uniform", "low": -5.12, "high": 5.12}},
            "method": {"name": "pso", "config": {"swarm_size": 15, "max_generations": 10, "random_seed": 7}},
            "streaming": {"mode": "none"},
            "output": {},
        }
        result = run_optimization(submit)
        assert "final_positions" in result
        assert "final_velocities" in result
        assert result["best_f"] >= 0

    def test_expression_objective(self):
        submit = {
            "objective": {"kind": "expression", "expr": "x0*x0 + x1*x1", "minimize": True},
            "problem": {"dims": 2, "bounds": {"kind": "uniform", "low": -5.0, "high": 5.0}},
            "method": {"name": "bbo.classic", "config": {"pop_size": 10, "max_generations": 10, "random_seed": 42}},
            "streaming": {"mode": "none"},
            "output": {},
        }
        result = run_optimization(submit)
        assert result["best_f"] >= 0

    def test_per_dim_bounds(self):
        submit = {
            "objective": {"kind": "builtin", "name": "sphere", "minimize": True},
            "problem": {"dims": 2, "bounds": {"kind": "per_dim", "items": [[-1, 1], [-2, 2]]}},
            "method": {"name": "bbo.classic", "config": {"pop_size": 10, "max_generations": 5, "random_seed": 42}},
            "streaming": {"mode": "none"},
            "output": {},
        }
        result = run_optimization(submit)
        assert len(result["best_x"]) == 2

    def test_result_serialization(self):
        result = run_optimization(_make_submit())
        assert isinstance(result["best_x"], list)
        assert isinstance(result["best_f"], float)
        assert isinstance(result["history_best_f"], list)
        if result.get("final_population"):
            assert isinstance(result["final_population"], list)
