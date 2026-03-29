class ServerCapabilities {
  final List<String> methods;
  final List<String> objectiveKinds;
  final List<String> progressModes;
  final int maxPayloadBytes;

  ServerCapabilities({
    required this.methods,
    required this.objectiveKinds,
    required this.progressModes,
    required this.maxPayloadBytes,
  });

  factory ServerCapabilities.fromJson(Map<String, dynamic> json) {
    return ServerCapabilities(
      methods: List<String>.from(json['methods'] ?? []),
      objectiveKinds: List<String>.from(json['objective_kinds'] ?? []),
      progressModes: List<String>.from(json['progress_modes'] ?? []),
      maxPayloadBytes: json['max_payload_bytes'] ?? 1048576,
    );
  }
}

class ServerHello {
  final String name;
  final String version;
  final ServerCapabilities capabilities;

  ServerHello({
    required this.name,
    required this.version,
    required this.capabilities,
  });

  factory ServerHello.fromPayload(Map<String, dynamic> payload) {
    final server = payload['server'] as Map<String, dynamic>;
    final caps = payload['capabilities'] as Map<String, dynamic>;
    return ServerHello(
      name: server['name'] as String,
      version: server['version'] as String,
      capabilities: ServerCapabilities.fromJson(caps),
    );
  }
}

class QueueInfo {
  final int position;
  final int? etaMs;

  QueueInfo({required this.position, this.etaMs});

  factory QueueInfo.fromJson(Map<String, dynamic> json) {
    return QueueInfo(
      position: json['position'] as int,
      etaMs: json['eta_ms'] as int?,
    );
  }
}

class JobAccepted {
  final String jobId;
  final String state;
  final QueueInfo? queue;

  JobAccepted({required this.jobId, required this.state, this.queue});

  factory JobAccepted.fromPayload(Map<String, dynamic> payload) {
    return JobAccepted(
      jobId: payload['job_id'] as String,
      state: payload['state'] as String,
      queue: payload['queue'] != null
          ? QueueInfo.fromJson(payload['queue'] as Map<String, dynamic>)
          : null,
    );
  }
}

class JobQueued {
  final String jobId;
  final QueueInfo queue;

  JobQueued({required this.jobId, required this.queue});

  factory JobQueued.fromPayload(Map<String, dynamic> payload) {
    return JobQueued(
      jobId: payload['job_id'] as String,
      queue: QueueInfo.fromJson(payload['queue'] as Map<String, dynamic>),
    );
  }
}

class JobStarted {
  final String jobId;
  final String startedAt;

  JobStarted({required this.jobId, required this.startedAt});

  factory JobStarted.fromPayload(Map<String, dynamic> payload) {
    return JobStarted(
      jobId: payload['job_id'] as String,
      startedAt: payload['started_at'] as String,
    );
  }
}

class ProgressData {
  final int iteration;
  final int maxIterations;
  final double bestF;
  final List<double>? bestX;
  final List<double>? historyBestFTail;
  final int elapsedMs;

  ProgressData({
    required this.iteration,
    required this.maxIterations,
    required this.bestF,
    this.bestX,
    this.historyBestFTail,
    required this.elapsedMs,
  });

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    return ProgressData(
      iteration: json['iteration'] as int,
      maxIterations: json['max_iterations'] as int,
      bestF: (json['best_f'] as num).toDouble(),
      bestX: json['best_x'] != null
          ? List<double>.from(
              (json['best_x'] as List).map((e) => (e as num).toDouble()))
          : null,
      historyBestFTail: json['history_best_f_tail'] != null
          ? List<double>.from((json['history_best_f_tail'] as List)
              .map((e) => (e as num).toDouble()))
          : null,
      elapsedMs: json['elapsed_ms'] as int,
    );
  }
}

class JobProgress {
  final String jobId;
  final ProgressData progress;

  JobProgress({required this.jobId, required this.progress});

  factory JobProgress.fromPayload(Map<String, dynamic> payload) {
    return JobProgress(
      jobId: payload['job_id'] as String,
      progress:
          ProgressData.fromJson(payload['progress'] as Map<String, dynamic>),
    );
  }
}

class ResultMetrics {
  final String method;
  final int iterations;
  final int evals;
  final int wallTimeMs;
  final int? seed;

  ResultMetrics({
    required this.method,
    required this.iterations,
    required this.evals,
    required this.wallTimeMs,
    this.seed,
  });

  factory ResultMetrics.fromJson(Map<String, dynamic> json) {
    return ResultMetrics(
      method: json['method'] as String,
      iterations: json['iterations'] as int,
      evals: json['evals'] as int,
      wallTimeMs: json['wall_time_ms'] as int,
      seed: json['seed'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'method': method,
        'iterations': iterations,
        'evals': evals,
        'wall_time_ms': wallTimeMs,
        'seed': seed,
      };
}

class JobResultData {
  final List<double> bestX;
  final double bestF;
  final List<double> historyBestF;
  final List<List<double>>? finalPopulation;
  final List<double>? finalFitness;
  final List<List<double>>? finalPositions;
  final List<List<double>>? finalVelocities;

  JobResultData({
    required this.bestX,
    required this.bestF,
    required this.historyBestF,
    this.finalPopulation,
    this.finalFitness,
    this.finalPositions,
    this.finalVelocities,
  });

  factory JobResultData.fromJson(Map<String, dynamic> json) {
    return JobResultData(
      bestX: List<double>.from(
          (json['best_x'] as List).map((e) => (e as num).toDouble())),
      bestF: (json['best_f'] as num).toDouble(),
      historyBestF: List<double>.from(
          (json['history_best_f'] as List).map((e) => (e as num).toDouble())),
      finalPopulation: _parseMatrix(json['final_population']),
      finalFitness: json['final_fitness'] != null
          ? List<double>.from((json['final_fitness'] as List)
              .map((e) => (e as num).toDouble()))
          : null,
      finalPositions: _parseMatrix(json['final_positions']),
      finalVelocities: _parseMatrix(json['final_velocities']),
    );
  }

  Map<String, dynamic> toJson() => {
        'best_x': bestX,
        'best_f': bestF,
        'history_best_f': historyBestF,
        if (finalPopulation != null) 'final_population': finalPopulation,
        if (finalFitness != null) 'final_fitness': finalFitness,
        if (finalPositions != null) 'final_positions': finalPositions,
        if (finalVelocities != null) 'final_velocities': finalVelocities,
      };

  static List<List<double>>? _parseMatrix(dynamic data) {
    if (data == null) return null;
    return (data as List)
        .map((row) => List<double>.from(
            (row as List).map((e) => (e as num).toDouble())))
        .toList();
  }
}

class JobResult {
  final String jobId;
  final JobResultData result;
  final ResultMetrics metrics;

  JobResult({
    required this.jobId,
    required this.result,
    required this.metrics,
  });

  factory JobResult.fromPayload(Map<String, dynamic> payload) {
    return JobResult(
      jobId: payload['job_id'] as String,
      result:
          JobResultData.fromJson(payload['result'] as Map<String, dynamic>),
      metrics:
          ResultMetrics.fromJson(payload['metrics'] as Map<String, dynamic>),
    );
  }
}

class JobFinished {
  final String jobId;
  final String finalState;
  final String finishedAt;

  JobFinished({
    required this.jobId,
    required this.finalState,
    required this.finishedAt,
  });

  factory JobFinished.fromPayload(Map<String, dynamic> payload) {
    return JobFinished(
      jobId: payload['job_id'] as String,
      finalState: payload['final_state'] as String,
      finishedAt: payload['finished_at'] as String,
    );
  }
}

class ProtocolError {
  final String code;
  final String message;
  final Map<String, dynamic>? details;
  final bool retryable;

  ProtocolError({
    required this.code,
    required this.message,
    this.details,
    required this.retryable,
  });

  factory ProtocolError.fromPayload(Map<String, dynamic> payload) {
    return ProtocolError(
      code: payload['code'] as String,
      message: payload['message'] as String,
      details: payload['details'] as Map<String, dynamic>?,
      retryable: payload['retryable'] as bool? ?? false,
    );
  }
}
