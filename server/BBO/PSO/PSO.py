"""
Метод роя частиц PSO для задач минимизации

Особенности реализации:
- инерция w линейно уменьшается от w_start до w_end
- когнитивная c1 и социальная c2 составляющие
- ограничение скорости по модулю v_max = vmax_frac * диапазон
- обработка границ позиций через обрезку clip
- элитарность не используется, хранятся личные и глобальные лучшие
"""
from __future__ import annotations
from dataclasses import dataclass
from typing import Callable, Optional, Sequence, Tuple, Dict, Any
import numpy as np


@dataclass
class PSOConfig:
    swarm_size: int = 50
    dims: int = 10
    bounds: Optional[Sequence[Tuple[float, float]]] = None
    max_generations: int = 200
    w_start: float = 0.9
    w_end: float = 0.4
    c1: float = 2.0
    c2: float = 2.0
    vmax_frac: float = 0.2
    random_seed: Optional[int] = None

    def __post_init__(self):
        assert self.swarm_size >= 2
        if self.bounds is None:
            self.bounds = [(-5.0, 5.0)] * self.dims
        assert len(self.bounds) == self.dims
        assert self.max_generations >= 1
        assert self.vmax_frac > 0


class PSO:
    def __init__(self, config: PSOConfig, objective: Callable[[np.ndarray], float],
                 on_progress: Optional[Callable] = None):
        self.cfg = config
        self.objective = objective
        self.on_progress = on_progress
        self.rng = np.random.default_rng(config.random_seed)
        self.low = np.array([a for a, _ in self.cfg.bounds], dtype=float)
        self.high = np.array([b for _, b in self.cfg.bounds], dtype=float)
        self.span = self.high - self.low
        self.vmax = self.cfg.vmax_frac * self.span

    def optimize(self) -> Dict[str, Any]:
        N, n = self.cfg.swarm_size, self.cfg.dims
        X = self.low + self.rng.random((N, n)) * self.span
        V = -self.vmax + self.rng.random((N, n)) * (2.0 * self.vmax)

        fit = self._evaluate(X)
        pbest_pos = X.copy()
        pbest_fit = fit.copy()

        g_idx = int(np.argmin(pbest_fit))
        gbest_pos = pbest_pos[g_idx].copy()
        gbest_fit = float(pbest_fit[g_idx])

        history_best = [gbest_fit]

        for t in range(self.cfg.max_generations):
            w = self._inertia_weight(t)

            r1 = self.rng.random((N, n))
            r2 = self.rng.random((N, n))

            cognitive = self.cfg.c1 * r1 * (pbest_pos - X)
            social = self.cfg.c2 * r2 * (gbest_pos - X)
            V = w * V + cognitive + social

            V = np.clip(V, -self.vmax, self.vmax)

            X = X + V

            X = np.clip(X, self.low, self.high)

            fit = self._evaluate(X)
            improved = fit < pbest_fit
            if np.any(improved):
                pbest_pos[improved] = X[improved]
                pbest_fit[improved] = fit[improved]

            g_idx = int(np.argmin(pbest_fit))
            if pbest_fit[g_idx] < gbest_fit:
                gbest_fit = float(pbest_fit[g_idx])
                gbest_pos = pbest_pos[g_idx].copy()

            history_best.append(gbest_fit)

            if self.on_progress:
                self.on_progress({
                    "iteration": t,
                    "max_iterations": self.cfg.max_generations,
                    "best_f": gbest_fit,
                    "best_x": gbest_pos.tolist(),
                    "history_best_f_tail": history_best[-10:],
                })

        return {
            "best_x": gbest_pos.copy(),
            "best_f": float(gbest_fit),
            "history_best_f": history_best,
            "final_positions": X.copy(),
            "final_velocities": V.copy(),
        }

    def _evaluate(self, X: np.ndarray) -> np.ndarray:

        try:
            vals = self.objective(X)
            vals = np.asarray(vals, dtype=float)
            if vals.shape == (X.shape[0],):
                return vals
        except Exception:
            pass

        return np.array([self.objective(ind) for ind in X], dtype=float)

    def _inertia_weight(self, t: int) -> float:

        T = max(1, self.cfg.max_generations - 1)
        alpha = min(1.0, max(0.0, t / T))
        return self.cfg.w_start + alpha * (self.cfg.w_end - self.cfg.w_start)


if __name__ == "__main__":
    from test_functions import sphere, rastrigin, ackley

    n = 20
    cfg = PSOConfig(
        swarm_size=50,
        dims=n,
        bounds=[(-5.12, 5.12)] * n,
        max_generations=200,
        w_start=0.9,
        w_end=0.4,
        c1=2.0,
        c2=2.0,
        vmax_frac=0.2,
        random_seed=42,
    )

    algo = PSO(cfg, objective=rastrigin)
    res = algo.optimize()
    print("Best f:", res["best_f"])
    print("Best x first 5 dims:", res["best_x"][:5])
