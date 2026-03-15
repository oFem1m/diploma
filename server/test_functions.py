import numpy as np


def sphere(x: np.ndarray) -> np.ndarray:
    x = np.atleast_2d(x)
    return np.sum(x * x, axis=1)


def rastrigin(x: np.ndarray, A: float = 10.0) -> np.ndarray:
    x = np.atleast_2d(x)
    n = x.shape[1]
    return A * n + np.sum(x * x - A * np.cos(2 * np.pi * x), axis=1)


def ackley(x: np.ndarray, a=20, b=0.2, c=2 * np.pi) -> np.ndarray:
    x = np.atleast_2d(x)
    n = x.shape[1]
    s1 = np.sum(x * x, axis=1) / n
    s2 = np.sum(np.cos(c * x), axis=1) / n
    return -a * np.exp(-b * np.sqrt(s1)) - np.exp(s2) + a + np.e


def bukin6(x: np.ndarray) -> np.ndarray:
    x = np.atleast_2d(x)
    x1 = x[:, 0]
    x2 = x[:, 1]
    return 100.0 * np.sqrt(np.abs(x2 - 0.01 * x1 * x1)) + 0.01 * np.abs(x1 + 10.0)
