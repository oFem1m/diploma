"""
Классический алгоритм биогеографической оптимизации (BBO) на основе частичной иммиграции

Миграция: частичная иммиграция, каждый признак может быть заменен независимо
Скорости: ранговые линейные, lambda_k пропорциональна рангу (эмиграция), mu_k = 1 - lambda_k (иммиграция)
Элитарность: E лучших особей переносится без изменений
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import Callable, Iterable, List, Sequence, Tuple, Optional, Dict, Any
import numpy as np
from test_functions import sphere, rastrigin, ackley


@dataclass
class BBOConfig:
    pop_size: int = 50
    dims: int = 10
    bounds: Optional[Sequence[Tuple[float, float]]] = None
    max_generations: int = 200
    mutation_rate: float = 0.01
    elite_count: int = 2
    random_seed: Optional[int] = None
    forbid_self_donation: bool = True

    def __post_init__(self):
        assert self.pop_size >= 2
        assert 0 <= self.mutation_rate <= 1
        assert 0 <= self.elite_count < self.pop_size
        if self.bounds is None:
            self.bounds = [(-5.0, 5.0)] * self.dims
        assert len(self.bounds) == self.dims


class ClassicBBO:
    def __init__(self, config: BBOConfig, objective: Callable[[np.ndarray], float],
                 on_progress: Optional[Callable] = None):
        self.cfg = config
        self.objective = objective
        self.on_progress = on_progress
        self.rng = np.random.default_rng(config.random_seed)
        self.low = np.array([a for a, _ in self.cfg.bounds], dtype=float)
        self.high = np.array([b for _, b in self.cfg.bounds], dtype=float)
        self.span = self.high - self.low

    def optimize(self) -> Dict[str, Any]:
        X = self._init_population()
        fitness = self._evaluate_population(X)
        hist_best = []

        for gen in range(self.cfg.max_generations):
            order = np.argsort(fitness)
            X = X[order]
            fitness = fitness[order]

            best_f = float(fitness[0])
            best_x = X[0].copy()
            hist_best.append(best_f)

            lambdas, mus = self._rank_based_migration_rates(self.cfg.pop_size)

            lambdas_sorted = lambdas[::-1]
            mus_sorted = mus[::-1]

            donor_probs = lambdas_sorted / lambdas_sorted.sum()
            donor_cdf = np.cumsum(donor_probs)

            Z = X.copy()

            for k in range(self.cfg.elite_count, self.cfg.pop_size):
                imm_flags = self.rng.random(self.cfg.dims) < mus_sorted[k]
                if imm_flags.any():
                    for s in np.where(imm_flags)[0]:
                        j = self._roulette_select(donor_cdf)
                        if self.cfg.forbid_self_donation and j == k:
                            j = self._roulette_select(donor_cdf)
                        Z[k, s] = X[j, s]

                mut_flags = self.rng.random(self.cfg.dims) < self.cfg.mutation_rate
                if mut_flags.any():
                    Z[k, mut_flags] = self.low[mut_flags] + self.rng.random(mut_flags.sum()) * self.span[mut_flags]

            Z = self._clip(Z)
            fit_Z = self._evaluate_population(Z)

            if self.cfg.elite_count > 0:
                elites_X = X[: self.cfg.elite_count]
                elites_f = fitness[: self.cfg.elite_count]
                worst_idx = np.argsort(fit_Z)[-self.cfg.elite_count:]
                Z[worst_idx] = elites_X
                fit_Z[worst_idx] = elites_f

            X, fitness = Z, fit_Z

            if self.on_progress:
                self.on_progress({
                    "iteration": gen,
                    "max_iterations": self.cfg.max_generations,
                    "best_f": best_f,
                    "best_x": best_x.tolist(),
                    "history_best_f_tail": hist_best[-10:],
                    "population": X.copy(),
                    "fitness": fitness.copy(),
                })

        order = np.argsort(fitness)
        X, fitness = X[order], fitness[order]
        return {
            "best_x": X[0].copy(),
            "best_f": float(fitness[0]),
            "history_best_f": hist_best,
            "final_population": X.copy(),
            "final_fitness": fitness.copy(),
        }

    def _init_population(self) -> np.ndarray:
        N, n = self.cfg.pop_size, self.cfg.dims
        X = self.low + self.rng.random((N, n)) * self.span
        return X

    def _clip(self, X: np.ndarray) -> np.ndarray:
        return np.clip(X, self.low, self.high)

    def _evaluate_population(self, X: np.ndarray) -> np.ndarray:
        try:
            vals = self.objective(X)
            vals = np.asarray(vals, dtype=float)
            if vals.shape == (X.shape[0],):
                return vals
        except Exception:
            pass
        return np.array([self.objective(ind) for ind in X], dtype=float)

    @staticmethod
    def _rank_based_migration_rates(N: int) -> Tuple[np.ndarray, np.ndarray]:
        # Линейная ранговая модель r = 1..N (худшие..лучшие).
        r = np.arange(1, N + 1, dtype=float)
        lambdas = r / (N + 1.0)
        mus = 1.0 - lambdas
        return lambdas, mus

    def _roulette_select(self, cdf: np.ndarray) -> int:
        u = self.rng.random()
        return int(np.searchsorted(cdf, u, side="left"))


if __name__ == "__main__":
    n = 20
    cfg = BBOConfig(
        pop_size=50,
        dims=n,
        bounds=[(-5.12, 5.12)] * n,
        max_generations=100,
        mutation_rate=0.01,
        elite_count=2,
        random_seed=42,
    )

    algo = ClassicBBO(cfg, objective=rastrigin)
    res = algo.optimize()
    print("Best f:", res["best_f"])
    print("Best x (first 5 dims):", res["best_x"][:5])
