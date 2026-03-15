import numpy as np
import pytest
from optimizer.objectives import create_objective, BUILTIN_FUNCTIONS, _compile_expression


class TestBuiltinFunctions:
    def test_sphere_minimum(self):
        x = np.zeros((1, 3))
        assert float(BUILTIN_FUNCTIONS["sphere"](x)[0]) == 0.0

    def test_sphere_nonzero(self):
        x = np.array([[1.0, 1.0, 1.0]])
        assert float(BUILTIN_FUNCTIONS["sphere"](x)[0]) == 3.0

    def test_rastrigin_minimum(self):
        x = np.zeros((1, 3))
        assert float(BUILTIN_FUNCTIONS["rastrigin"](x)[0]) == 0.0

    def test_ackley_minimum(self):
        x = np.zeros((1, 3))
        assert abs(float(BUILTIN_FUNCTIONS["ackley"](x)[0])) < 1e-10

    def test_bukin6_2d(self):
        x = np.array([[-10.0, 1.0]])
        result = float(BUILTIN_FUNCTIONS["bukin6"](x)[0])
        assert result == pytest.approx(0.0, abs=1e-10)

    def test_batch_evaluation(self):
        x = np.array([[0, 0], [1, 1], [2, 2]], dtype=float)
        result = BUILTIN_FUNCTIONS["sphere"](x)
        assert result.shape == (3,)
        np.testing.assert_array_almost_equal(result, [0, 2, 8])


class TestCreateObjective:
    def test_builtin_sphere(self):
        fn = create_objective({"kind": "builtin", "name": "sphere", "minimize": True}, 3)
        x = np.zeros((1, 3))
        assert float(fn(x)[0]) == 0.0

    def test_builtin_maximize(self):
        fn = create_objective({"kind": "builtin", "name": "sphere", "minimize": False}, 3)
        x = np.array([[1.0, 1.0, 1.0]])
        assert float(fn(x)[0]) == -3.0

    def test_unknown_builtin(self):
        with pytest.raises(ValueError, match="unknown builtin"):
            create_objective({"kind": "builtin", "name": "nonexistent"}, 2)

    def test_unsupported_kind(self):
        with pytest.raises(ValueError, match="unsupported"):
            create_objective({"kind": "code_python"}, 2)


class TestExpressionObjective:
    def test_simple_expression(self):
        fn = create_objective({"kind": "expression", "expr": "x0*x0 + x1*x1", "minimize": True}, 2)
        x = np.array([[3.0, 4.0]])
        assert float(fn(x)[0]) == pytest.approx(25.0)

    def test_expression_with_math(self):
        fn = create_objective({"kind": "expression", "expr": "sqrt(x0*x0 + x1*x1)", "minimize": True}, 2)
        x = np.array([[3.0, 4.0]])
        assert float(fn(x)[0]) == pytest.approx(5.0)

    def test_expression_batch(self):
        fn = create_objective({"kind": "expression", "expr": "x0 + x1", "minimize": True}, 2)
        x = np.array([[1.0, 2.0], [3.0, 4.0]])
        result = fn(x)
        assert result.shape == (2,)
        np.testing.assert_array_almost_equal(result, [3.0, 7.0])

    def test_expression_maximize(self):
        fn = create_objective({"kind": "expression", "expr": "x0 + x1", "minimize": False}, 2)
        x = np.array([[1.0, 2.0]])
        assert float(fn(x)[0]) == pytest.approx(-3.0)

    def test_expression_attribute_access_blocked(self):
        with pytest.raises(ValueError, match="attribute"):
            _compile_expression("x0.__class__", 1)
