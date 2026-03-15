"""Pydantic models for WS JSON Protocol v1."""

from __future__ import annotations

from enum import Enum
from typing import Any, Dict, List, Optional, Union

from pydantic import BaseModel, Field


# ── Header sub-models ──────────────────────────────────────────────

class AuthScheme(str, Enum):
    none = "none"
    bearer = "bearer"
    api_key = "api_key"


class Auth(BaseModel):
    scheme: AuthScheme = AuthScheme.none
    token: Optional[str] = None


class Trace(BaseModel):
    client_req_id: Optional[str] = None
    job_id: Optional[str] = None
    span_id: Optional[str] = None


class StreamInfo(BaseModel):
    stream_id: Optional[str] = None
    seq: Optional[int] = None
    total: Optional[int] = None
    is_last: Optional[bool] = None


class Compression(BaseModel):
    algo: str = "none"
    original_bytes: Optional[int] = None


class Header(BaseModel):
    v: int = 1
    type: str
    msg_id: str
    ts: str
    session_id: Optional[str] = None
    reply_to: Optional[str] = None
    auth: Auth = Field(default_factory=Auth)
    trace: Trace = Field(default_factory=Trace)
    stream: StreamInfo = Field(default_factory=StreamInfo)
    compression: Compression = Field(default_factory=Compression)


class Envelope(BaseModel):
    header: Header
    payload: Dict[str, Any] = Field(default_factory=dict)


# ── Payload: hello ─────────────────────────────────────────────────

class ClientInfo(BaseModel):
    name: str = "unknown"
    version: str = "0.0.0"
    platform: str = "unknown"
    lang: str = "unknown"


class Wants(BaseModel):
    progress_stream: bool = True
    chunking: bool = False


class HelloClientPayload(BaseModel):
    client: ClientInfo = Field(default_factory=ClientInfo)
    wants: Wants = Field(default_factory=Wants)


class ServerInfo(BaseModel):
    name: str = "optimizer-server"
    version: str = "0.1.0"


class Capabilities(BaseModel):
    methods: List[str]
    objective_kinds: List[str]
    progress_modes: List[str] = ["per_generation", "every_k", "none"]
    max_payload_bytes: int = 1_048_576


class HelloServerPayload(BaseModel):
    server: ServerInfo = Field(default_factory=ServerInfo)
    capabilities: Capabilities


# ── Payload: job.submit ────────────────────────────────────────────

class Priority(str, Enum):
    low = "low"
    normal = "normal"
    high = "high"


class JobMeta(BaseModel):
    priority: Priority = Priority.normal
    timeout_ms: Optional[int] = None
    tags: List[str] = Field(default_factory=list)


class ObjectiveKind(str, Enum):
    builtin = "builtin"
    expression = "expression"
    code_python = "code_python"


class Objective(BaseModel):
    kind: ObjectiveKind
    name: Optional[str] = None          # for builtin
    expr: Optional[str] = None          # for expression
    code: Optional[str] = None          # for code_python
    entrypoint: Optional[str] = None    # for code_python
    expects: Optional[str] = None       # for code_python: "batch"|"single"
    minimize: bool = True


class BoundsUniform(BaseModel):
    kind: str = "uniform"
    low: float
    high: float


class BoundsPerDim(BaseModel):
    kind: str = "per_dim"
    items: List[List[float]]


class Problem(BaseModel):
    dims: int
    bounds: Union[BoundsUniform, BoundsPerDim] = Field(discriminator=None)

    def get_bounds_list(self) -> List[tuple]:
        """Convert bounds to list of (low, high) tuples."""
        if isinstance(self.bounds, BoundsUniform):
            return [(self.bounds.low, self.bounds.high)] * self.dims
        else:
            return [(b[0], b[1]) for b in self.bounds.items]


class MethodConfig(BaseModel):
    """Flexible config — passes through to algorithm config dataclass."""
    model_config = {"extra": "allow"}


class Method(BaseModel):
    name: str
    config: Dict[str, Any] = Field(default_factory=dict)


class StreamingInclude(BaseModel):
    best_x: bool = True
    best_f: bool = True
    population: bool = False
    fitness: bool = False
    velocities: bool = False


class StreamingMaxPoints(BaseModel):
    history_best_f: int = 5000


class StreamingConfig(BaseModel):
    mode: str = "per_generation"
    every_k: int = 1
    include: StreamingInclude = Field(default_factory=StreamingInclude)
    max_points: StreamingMaxPoints = Field(default_factory=StreamingMaxPoints)


class OutputConfig(BaseModel):
    return_final_population: bool = True
    return_final_fitness: bool = True
    return_final_velocities: bool = False


class JobSubmitPayload(BaseModel):
    job: JobMeta = Field(default_factory=JobMeta)
    objective: Objective
    problem: Problem
    method: Method
    streaming: StreamingConfig = Field(default_factory=StreamingConfig)
    output: OutputConfig = Field(default_factory=OutputConfig)


# ── Payload: server responses ──────────────────────────────────────

class QueueInfo(BaseModel):
    position: int
    eta_ms: Optional[int] = None


class JobAcceptedPayload(BaseModel):
    job_id: str
    state: str = "queued"
    queue: Optional[QueueInfo] = None


class JobQueuedPayload(BaseModel):
    job_id: str
    queue: QueueInfo


class WorkerInfo(BaseModel):
    id: str = "worker-1"
    host: str = "localhost"


class JobStartedPayload(BaseModel):
    job_id: str
    started_at: str
    worker: WorkerInfo = Field(default_factory=WorkerInfo)


class ProgressData(BaseModel):
    iteration: int
    max_iterations: int
    best_f: float
    best_x: Optional[List[float]] = None
    history_best_f_tail: Optional[List[float]] = None
    elapsed_ms: Optional[int] = None


class Snapshots(BaseModel):
    population: Optional[Any] = None
    fitness: Optional[Any] = None
    velocities: Optional[Any] = None


class JobProgressPayload(BaseModel):
    job_id: str
    progress: ProgressData
    snapshots: Optional[Snapshots] = None


class Metrics(BaseModel):
    method: str
    iterations: int
    evals: Optional[int] = None
    wall_time_ms: int
    seed: Optional[int] = None


class JobResultPayload(BaseModel):
    job_id: str
    result: Dict[str, Any]
    metrics: Metrics


class FinalState(str, Enum):
    succeeded = "succeeded"
    failed = "failed"
    cancelled = "cancelled"
    timeout = "timeout"


class JobFinishedPayload(BaseModel):
    job_id: str
    final_state: FinalState
    finished_at: str


# ── Payload: error ─────────────────────────────────────────────────

class ErrorCode(str, Enum):
    BAD_REQUEST = "BAD_REQUEST"
    VALIDATION_ERROR = "VALIDATION_ERROR"
    UNSUPPORTED_METHOD = "UNSUPPORTED_METHOD"
    UNSUPPORTED_OBJECTIVE_KIND = "UNSUPPORTED_OBJECTIVE_KIND"
    QUEUE_OVERFLOW = "QUEUE_OVERFLOW"
    JOB_NOT_FOUND = "JOB_NOT_FOUND"
    JOB_ALREADY_FINISHED = "JOB_ALREADY_FINISHED"
    EXECUTION_ERROR = "EXECUTION_ERROR"
    TIMEOUT = "TIMEOUT"
    AUTH_REQUIRED = "AUTH_REQUIRED"
    AUTH_INVALID = "AUTH_INVALID"


class ErrorPayload(BaseModel):
    code: str
    message: str
    details: Optional[Dict[str, Any]] = None
    retryable: bool = False


# ── Payload: cancel ────────────────────────────────────────────────

class CancelPayload(BaseModel):
    job_id: str
    reason: str = "user_cancel"


# ── Payload: job.status ────────────────────────────────────────────

class JobStatusGetPayload(BaseModel):
    job_id: str


class JobStatusPayload(BaseModel):
    job_id: str
    state: str
    queue: Optional[QueueInfo] = None
    progress: Optional[ProgressData] = None
