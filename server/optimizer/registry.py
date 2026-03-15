from __future__ import annotations

import sys
import os
from typing import Any, Callable, Dict, Optional, Tuple, Type

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from BBO.BBO_classic.BBO_classic import ClassicBBO, BBOConfig as ClassicBBOConfig
from BBO.BBO_classic.BBO_classic_modified import ClassicBBO_Modified, BBOConfigModified
from BBO.BBO_sinusoidal.BBO_sinusoidal import BBO_Sinusoidal, BBOConfig as SinBBOConfig
from BBO.BBO_sinusoidal.BBO_sinusoidal_modified import BBO_Sinusoidal_Modified, BBOConfigSinModified
from BBO.BBO_mixed.BBO_mixed import BBO_Mixed, BBOConfig as MixedBBOConfig
from BBO.BBO_mixed.BBO_mixed_modified import BBO_Mixed_Modified, BBOConfigMixedModified
from BBO.PSO.PSO import PSO, PSOConfig

METHODS: Dict[str, Tuple[Type, Type]] = {
    "bbo.classic": (ClassicBBO, ClassicBBOConfig),
    "bbo.classic.modified": (ClassicBBO_Modified, BBOConfigModified),
    "bbo.sinusoidal": (BBO_Sinusoidal, SinBBOConfig),
    "bbo.sinusoidal.modified": (BBO_Sinusoidal_Modified, BBOConfigSinModified),
    "bbo.mixed": (BBO_Mixed, MixedBBOConfig),
    "bbo.mixed.modified": (BBO_Mixed_Modified, BBOConfigMixedModified),
    "pso": (PSO, PSOConfig),
}


def _build_config(config_cls: Type, config_dict: Dict[str, Any], dims: int, bounds: list) -> Any:
    params = dict(config_dict)
    params["dims"] = dims
    params["bounds"] = bounds
    return config_cls(**params)


def create_algorithm(
    method_name: str,
    config_dict: Dict[str, Any],
    dims: int,
    bounds: list,
    objective: Callable,
    on_progress: Optional[Callable] = None,
):
    if method_name not in METHODS:
        raise ValueError(f"unknown method: {method_name}")

    algo_cls, config_cls = METHODS[method_name]
    cfg = _build_config(config_cls, config_dict, dims, bounds)
    return algo_cls(cfg, objective, on_progress=on_progress)
