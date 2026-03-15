from __future__ import annotations

import ast
import math
import sys
import os
from typing import Callable

import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
from test_functions import sphere, rastrigin, ackley, bukin6

BUILTIN_FUNCTIONS = {
    "sphere": sphere,
    "rastrigin": rastrigin,
    "ackley": ackley,
    "bukin6": bukin6,
}

_SAFE_MATH = {
    "abs": abs,
    "min": min,
    "max": max,
    "sqrt": math.sqrt,
    "exp": math.exp,
    "log": math.log,
    "log10": math.log10,
    "sin": math.sin,
    "cos": math.cos,
    "tan": math.tan,
    "pi": math.pi,
    "e": math.e,
    "pow": pow,
}


def _compile_expression(expr: str, dims: int) -> Callable[[np.ndarray], np.ndarray]:
    tree = ast.parse(expr, mode="eval")
    for node in ast.walk(tree):
        if isinstance(node, (ast.Import, ast.ImportFrom, ast.Call)):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
                if node.func.id in _SAFE_MATH:
                    continue
            if isinstance(node, ast.Call):
                raise ValueError(f"unsafe call in expression: {ast.dump(node)}")
        if isinstance(node, ast.Attribute):
            raise ValueError(f"attribute access not allowed: {ast.dump(node)}")

    code = compile(tree, "<expression>", "eval")
    var_names = [f"x{i}" for i in range(dims)]

    def objective(X: np.ndarray) -> np.ndarray:
        X = np.atleast_2d(X)
        results = np.empty(X.shape[0])
        for row_idx in range(X.shape[0]):
            ns = dict(_SAFE_MATH)
            for i, name in enumerate(var_names):
                ns[name] = float(X[row_idx, i])
            results[row_idx] = eval(code, {"__builtins__": {}}, ns)
        return results

    return objective


def create_objective(objective_cfg: dict, dims: int) -> Callable[[np.ndarray], np.ndarray]:
    kind = objective_cfg.get("kind", "builtin")

    if kind == "builtin":
        name = objective_cfg["name"]
        if name not in BUILTIN_FUNCTIONS:
            raise ValueError(f"unknown builtin: {name}")
        fn = BUILTIN_FUNCTIONS[name]
        if objective_cfg.get("minimize", True):
            return fn
        return lambda X: -fn(X)

    elif kind == "expression":
        expr = objective_cfg["expr"]
        fn = _compile_expression(expr, dims)
        if objective_cfg.get("minimize", True):
            return fn
        return lambda X: -fn(X)

    else:
        raise ValueError(f"unsupported objective kind: {kind}")
