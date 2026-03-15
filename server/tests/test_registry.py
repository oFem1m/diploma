import numpy as np
import pytest
from optimizer.registry import METHODS, create_algorithm


class TestRegistry:
    def test_all_methods_registered(self):
        expected = {
            "bbo.classic", "bbo.classic.modified",
            "bbo.sinusoidal", "bbo.sinusoidal.modified",
            "bbo.mixed", "bbo.mixed.modified",
            "pso",
        }
        assert set(METHODS.keys()) == expected

    def test_unknown_method_raises(self):
        with pytest.raises(ValueError, match="unknown method"):
            create_algorithm("unknown", {}, 2, [(-5, 5)] * 2, lambda x: x)

    @pytest.mark.parametrize("method_name", list(METHODS.keys()))
    def test_create_algorithm_all_methods(self, method_name):
        dims = 2
        bounds = [(-5.0, 5.0)] * dims
        objective = lambda x: np.sum(np.atleast_2d(x) ** 2, axis=1)

        config = {"max_generations": 5, "random_seed": 42}
        if method_name == "pso":
            config["swarm_size"] = 10
        else:
            config["pop_size"] = 10

        if "modified" in method_name:
            config["mutation_start"] = 0.05
            config["mutation_end"] = 0.005

        if "mixed" in method_name:
            config["mix_alpha"] = 0.5

        algo = create_algorithm(method_name, config, dims, bounds, objective)
        assert algo is not None

    @pytest.mark.parametrize("method_name", list(METHODS.keys()))
    def test_optimize_runs_all_methods(self, method_name):
        dims = 2
        bounds = [(-5.0, 5.0)] * dims
        objective = lambda x: np.sum(np.atleast_2d(x) ** 2, axis=1)

        config = {"max_generations": 5, "random_seed": 42}
        if method_name == "pso":
            config["swarm_size"] = 10
        else:
            config["pop_size"] = 10

        if "modified" in method_name:
            config["mutation_start"] = 0.05
            config["mutation_end"] = 0.005

        if "mixed" in method_name:
            config["mix_alpha"] = 0.5

        algo = create_algorithm(method_name, config, dims, bounds, objective)
        result = algo.optimize()
        assert "best_x" in result
        assert "best_f" in result
        assert "history_best_f" in result
        assert isinstance(result["best_f"], float)
