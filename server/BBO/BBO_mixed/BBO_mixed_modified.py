from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Optional, Sequence, Tuple, Dict, Any, List

import numpy as np


@dataclass
class BBOConfigMixedModified:
    pop_size: int = 50
    dims: int = 10
    bounds: Optional[Sequence[Tuple[float, float]]] = None
    max_generations: int = 200

    mutation_start: float = 0.05
    mutation_end: float = 0.005

    elite_count: int = 2
    forbid_self_donation: bool = True

    stagnation_generations: int = 25
    restart_fraction: float = 0.3
    mutation_boost_factor: float = 4.0

    mix_alpha: float = 0.5

    enable_local_search: bool = False
    local_search_interval: int = 20
    local_search_count: int = 2
    local_search_steps: int = 20
    local_search_step_start: float = 0.25
    local_search_step_end: float = 0.02

    random_seed: Optional[int] = None

    def __post_init__(self):
        assert self.pop_size >= 2
        assert self.dims >= 1
        if self.bounds is None:
            self.bounds = [(-5.0, 5.0)] * self.dims
        assert len(self.bounds) == self.dims
        assert self.max_generations >= 1
        assert 0.0 < self.mutation_end <= self.mutation_start <= 1.0
        assert 0 <= self.elite_count < self.pop_size
        assert self.stagnation_generations >= 1
        assert 0.0 < self.restart_fraction < 1.0
        assert self.mutation_boost_factor >= 1.0
        assert 0.0 <= self.mix_alpha <= 1.0
        if self.enable_local_search:
            assert self.local_search_interval >= 1
            assert self.local_search_count >= 1
            assert self.local_search_steps >= 1
            assert 0.0 < self.local_search_step_end <= self.local_search_step_start


class BBO_Mixed_Modified:
    def __init__(self, config: BBOConfigMixedModified, objective: Callable[[np.ndarray], float],
                 on_progress: Optional[Callable] = None):
        self.cfg = config
        self.objective = objective
        self.on_progress = on_progress
        self.rng = np.random.default_rng(config.random_seed)

        self.low = np.array([a for a, _ in self.cfg.bounds], dtype=float)
        self.high = np.array([b for _, b in self.cfg.bounds], dtype=float)
        self.span = self.high - self.low

    def optimize(self) -> Dict[str, Any]:
        N, d = self.cfg.pop_size, self.cfg.dims

        X = self._init_population(N, d)
        fit = self._evaluate(X)

        best_idx = int(np.argmin(fit))
        best_x = X[best_idx].copy()
        best_f = float(fit[best_idx])

        history_best: List[float] = [best_f]
        stagnation = 0

        for gen in range(self.cfg.max_generations):
            mutation_rate = self._current_mutation_rate(gen)
            if stagnation >= self.cfg.stagnation_generations:
                X, fit = self._restart_partially(X, fit)
                mutation_rate = min(
                    self.cfg.mutation_start,
                    mutation_rate * self.cfg.mutation_boost_factor,
                )
                stagnation = 0

            X_new = self._migration_step_mixed(X, fit)
            X_new = self._mutation_step(X_new, mutation_rate)
            fit_new = self._evaluate(X_new)

            X, fit = self._apply_elitism(X, fit, X_new, fit_new)

            if self.cfg.enable_local_search and (gen + 1) % self.cfg.local_search_interval == 0:
                X, fit = self._local_search(X, fit, gen)

            cur_idx = int(np.argmin(fit))
            cur_best_f = float(fit[cur_idx])

            if cur_best_f < best_f:
                best_f = cur_best_f
                best_x = X[cur_idx].copy()
                stagnation = 0
            else:
                stagnation += 1

            history_best.append(best_f)

            if self.on_progress:
                self.on_progress({
                    "iteration": gen,
                    "max_iterations": self.cfg.max_generations,
                    "best_f": best_f,
                    "best_x": best_x.tolist(),
                    "history_best_f_tail": history_best[-10:],
                })

        return {
            "best_x": best_x,
            "best_f": best_f,
            "history_best_f": history_best,
            "final_population": X,
            "final_fitness": fit,
        }

    def _init_population(self, N: int, d: int) -> np.ndarray:
        return self.low + self.rng.random((N, d)) * self.span

    def _evaluate(self, X: np.ndarray) -> np.ndarray:
        try:
            vals = self.objective(X)
            vals = np.asarray(vals, dtype=float)
            if vals.shape == (X.shape[0],):
                return vals
        except Exception:
            pass
        return np.array([self.objective(ind) for ind in X], dtype=float)

    def _current_mutation_rate(self, gen: int) -> float:
        T = max(1, self.cfg.max_generations - 1)
        alpha = min(1.0, max(0.0, gen / T))
        return self.cfg.mutation_start + alpha * (self.cfg.mutation_end - self.cfg.mutation_start)

    def _current_local_step(self, gen: int) -> float:
        T = max(1, self.cfg.max_generations - 1)
        alpha = min(1.0, max(0.0, gen / T))
        return self.cfg.local_search_step_start + alpha * (
            self.cfg.local_search_step_end - self.cfg.local_search_step_start
        )

    def _migration_step_mixed(self, X: np.ndarray, fit: np.ndarray) -> np.ndarray:
        N, d = X.shape
        idx = np.argsort(fit)
        ranks = np.empty_like(idx)
        ranks[idx] = np.arange(N)

        if N > 1:
            r = ranks.astype(float) / float(N - 1)
        else:
            r = np.zeros_like(ranks, dtype=float)

        imm_lin = r
        imm_sin = 0.5 * (1.0 - np.cos(np.pi * r))
        alpha = self.cfg.mix_alpha
        imm_prob = alpha * imm_lin + (1.0 - alpha) * imm_sin

        emig_weight = (1.0 - r.copy())
        emig_weight = np.maximum(emig_weight, 0.0)
        s = emig_weight.sum()
        if s <= 0:
            emig_weight[:] = 1.0 / N
        else:
            emig_weight /= s

        X_new = X.copy()

        for i in range(N):
            p_i = imm_prob[i]
            if p_i <= 0.0:
                continue
            for k in range(d):
                if self.rng.random() < p_i:
                    donor = i
                    if self.cfg.forbid_self_donation:
                        for _ in range(5):
                            donor = self.rng.choice(N, p=emig_weight)
                            if donor != i:
                                break
                        if donor == i:
                            continue
                    else:
                        donor = self.rng.choice(N, p=emig_weight)
                    X_new[i, k] = X[donor, k]

        return X_new

    def _mutation_step(self, X: np.ndarray, mutation_rate: float) -> np.ndarray:
        N, d = X.shape
        mask = self.rng.random((N, d)) < mutation_rate
        if not np.any(mask):
            return X
        noise = self.low + self.rng.random((N, d)) * self.span
        X_mut = X.copy()
        X_mut[mask] = noise[mask]
        return X_mut

    def _apply_elitism(
        self,
        X_old: np.ndarray,
        fit_old: np.ndarray,
        X_new: np.ndarray,
        fit_new: np.ndarray,
    ) -> Tuple[np.ndarray, np.ndarray]:
        if self.cfg.elite_count <= 0:
            return X_new, fit_new

        N = X_old.shape[0]
        elite_count = min(self.cfg.elite_count, N)

        elite_idx = np.argsort(fit_old)[:elite_count]
        worst_idx_new = np.argsort(fit_new)[-elite_count:]

        X_res = X_new.copy()
        fit_res = fit_new.copy()

        X_res[worst_idx_new] = X_old[elite_idx]
        fit_res[worst_idx_new] = fit_old[elite_idx]

        return X_res, fit_res

    def _restart_partially(self, X: np.ndarray, fit: np.ndarray) -> Tuple[np.ndarray, np.ndarray]:
        N, d = X.shape
        n_restart = int(max(1, round(self.cfg.restart_fraction * N)))
        max_replace = max(1, N - self.cfg.elite_count)
        n_restart = min(n_restart, max_replace)

        worst_idx = np.argsort(fit)[-n_restart:]

        X_new = X.copy()
        X_new[worst_idx] = self._init_population(n_restart, d)
        fit_new = self._evaluate(X_new)
        return X_new, fit_new

    def _local_search(self, X: np.ndarray, fit: np.ndarray, gen: int) -> Tuple[np.ndarray, np.ndarray]:
        N, d = X.shape
        k = min(self.cfg.local_search_count, N)
        if (not self.cfg.enable_local_search) or k <= 0 or self.cfg.local_search_steps <= 0:
            return X, fit

        step_frac = self._current_local_step(gen)

        idx_sorted = np.argsort(fit)
        target_idx = idx_sorted[:k]

        X_loc = X.copy()
        fit_loc = fit.copy()

        for idx_i in target_idx:
            x = X_loc[idx_i].copy()
            f = float(fit_loc[idx_i])

            for _ in range(self.cfg.local_search_steps):
                noise = self.rng.normal(loc=0.0, scale=1.0, size=d) * (step_frac * self.span)
                cand = x + noise
                cand = np.clip(cand, self.low, self.high)

                f_cand = float(self._evaluate(cand.reshape(1, -1))[0])
                if f_cand < f:
                    x = cand
                    f = f_cand

            X_loc[idx_i] = x
            fit_loc[idx_i] = f

        return X_loc, fit_loc


if __name__ == "__main__":
    from test_functions import rastrigin

    n = 10
    cfg = BBOConfigMixedModified(
        pop_size=60,
        dims=n,
        bounds=[(-5.12, 5.12)] * n,
        max_generations=100,
        mutation_start=0.05,
        mutation_end=0.005,
        elite_count=2,
        stagnation_generations=25,
        restart_fraction=0.3,
        mutation_boost_factor=4.0,
        mix_alpha=0.5,
        enable_local_search=True,
        local_search_interval=10,
        local_search_count=3,
        local_search_steps=25,
        local_search_step_start=0.3,
        local_search_step_end=0.05,
        random_seed=42,
    )

    algo = BBO_Mixed_Modified(cfg, objective=rastrigin)
    res = algo.optimize()
    print("Best f:", res["best_f"])