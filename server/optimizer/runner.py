from __future__ import annotations

import threading
import time
from typing import Any, Callable, Dict, Optional

from optimizer.objectives import create_objective
from optimizer.registry import create_algorithm


class CancelledError(Exception):
    pass


def run_optimization(
    submit_payload: Dict[str, Any],
    on_progress: Optional[Callable[[Dict], None]] = None,
    cancel_event: Optional[threading.Event] = None,
) -> Dict[str, Any]:
    objective_cfg = submit_payload["objective"]
    if hasattr(objective_cfg, "model_dump"):
        objective_cfg = objective_cfg.model_dump()

    problem = submit_payload["problem"]
    if hasattr(problem, "model_dump"):
        problem = problem.model_dump()

    method = submit_payload["method"]
    if hasattr(method, "model_dump"):
        method = method.model_dump()

    dims = problem["dims"]
    bounds_raw = problem["bounds"]
    if bounds_raw.get("kind") == "uniform":
        bounds = [(bounds_raw["low"], bounds_raw["high"])] * dims
    else:
        bounds = [(b[0], b[1]) for b in bounds_raw["items"]]

    objective_fn = create_objective(objective_cfg, dims)

    start_time = time.monotonic()

    def progress_wrapper(data: Dict):
        if cancel_event and cancel_event.is_set():
            raise CancelledError("job cancelled")
        if on_progress:
            data["elapsed_ms"] = int((time.monotonic() - start_time) * 1000)
            on_progress(data)

    algo = create_algorithm(
        method_name=method["name"],
        config_dict=method.get("config", {}),
        dims=dims,
        bounds=bounds,
        objective=objective_fn,
        on_progress=progress_wrapper,
    )

    result = algo.optimize()

    wall_time_ms = int((time.monotonic() - start_time) * 1000)

    for key in ("best_x", "final_population", "final_fitness", "final_positions", "final_velocities"):
        if key in result:
            import numpy as np
            val = result[key]
            if isinstance(val, np.ndarray):
                result[key] = val.tolist()

    if isinstance(result.get("history_best_f"), list):
        result["history_best_f"] = [float(x) for x in result["history_best_f"]]

    result["wall_time_ms"] = wall_time_ms
    result["method"] = method["name"]
    result["seed"] = method.get("config", {}).get("random_seed")

    return result
