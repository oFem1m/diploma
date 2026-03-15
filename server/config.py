"""Server configuration and limits."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class Limits:
    max_generations: int = 10_000
    max_pop_size: int = 500
    max_dims: int = 100
    max_payload_bytes: int = 1_048_576  # 1 MB


@dataclass
class ServerConfig:
    host: str = "0.0.0.0"
    port: int = 8765
    max_queue_size: int = 50
    max_workers: int = 2
    default_timeout_ms: int = 600_000  # 10 min
    ping_interval_s: int = 30
    limits: Limits = field(default_factory=Limits)
