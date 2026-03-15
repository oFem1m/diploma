from __future__ import annotations

from typing import List, Optional

from config import Limits
from protocol.types import JobSubmitPayload

SUPPORTED_METHODS = {
    "bbo.classic",
    "bbo.classic.modified",
    "bbo.sinusoidal",
    "bbo.sinusoidal.modified",
    "bbo.mixed",
    "bbo.mixed.modified",
    "pso",
}

SUPPORTED_BUILTINS = {"sphere", "rastrigin", "ackley", "bukin6"}


def validate_job_submit(payload: JobSubmitPayload, limits: Limits) -> Optional[List[str]]:
    errors: List[str] = []

    if payload.problem.dims < 1:
        errors.append("problem.dims must be >= 1")
    if payload.problem.dims > limits.max_dims:
        errors.append(f"problem.dims exceeds limit {limits.max_dims}")

    bounds = payload.problem.bounds
    if bounds.kind == "uniform":
        if bounds.low >= bounds.high:
            errors.append("bounds: low must be < high")
    elif bounds.kind == "per_dim":
        if len(bounds.items) != payload.problem.dims:
            errors.append(f"bounds.items length ({len(bounds.items)}) must equal dims ({payload.problem.dims})")
        for i, pair in enumerate(bounds.items):
            if len(pair) != 2 or pair[0] >= pair[1]:
                errors.append(f"bounds.items[{i}]: must be [low, high] with low < high")

    method_name = payload.method.name
    if method_name not in SUPPORTED_METHODS:
        errors.append(f"unsupported method: {method_name}")

    cfg = payload.method.config
    if method_name.startswith("pso"):
        swarm_size = cfg.get("swarm_size", 50)
        if swarm_size < 2:
            errors.append("swarm_size must be >= 2")
        if swarm_size > limits.max_pop_size:
            errors.append(f"swarm_size exceeds limit {limits.max_pop_size}")
        max_gen = cfg.get("max_generations", 200)
        if max_gen < 1:
            errors.append("max_generations must be >= 1")
        if max_gen > limits.max_generations:
            errors.append(f"max_generations exceeds limit {limits.max_generations}")
        if cfg.get("vmax_frac", 0.2) <= 0:
            errors.append("vmax_frac must be > 0")
    else:
        pop_size = cfg.get("pop_size", 50)
        if pop_size < 2:
            errors.append("pop_size must be >= 2")
        if pop_size > limits.max_pop_size:
            errors.append(f"pop_size exceeds limit {limits.max_pop_size}")
        max_gen = cfg.get("max_generations", 200)
        if max_gen < 1:
            errors.append("max_generations must be >= 1")
        if max_gen > limits.max_generations:
            errors.append(f"max_generations exceeds limit {limits.max_generations}")
        mr = cfg.get("mutation_rate", cfg.get("mutation_start", 0.01))
        if not (0 <= mr <= 1):
            errors.append("mutation_rate must be in [0, 1]")
        ec = cfg.get("elite_count", 2)
        if ec < 0 or ec >= pop_size:
            errors.append("elite_count must be in [0, pop_size)")

    obj = payload.objective
    if obj.kind.value == "builtin":
        if obj.name not in SUPPORTED_BUILTINS:
            errors.append(f"unsupported builtin function: {obj.name}")
        if obj.name == "bukin6" and payload.problem.dims != 2:
            errors.append("bukin6 requires exactly 2 dimensions")
    elif obj.kind.value == "expression":
        if not obj.expr:
            errors.append("expression objective requires 'expr' field")

    return errors if errors else None
