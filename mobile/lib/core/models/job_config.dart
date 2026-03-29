class ObjectiveConfig {
  String kind;
  String? name;
  String? expr;
  bool minimize;

  ObjectiveConfig({
    this.kind = 'builtin',
    this.name = 'sphere',
    this.expr,
    this.minimize = true,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'kind': kind,
      'minimize': minimize,
    };
    if (kind == 'builtin') {
      map['name'] = name;
    } else if (kind == 'expression') {
      map['expr'] = expr;
    }
    return map;
  }
}

class BoundsConfig {
  String kind;
  double low;
  double high;
  List<List<double>>? items;

  BoundsConfig({
    this.kind = 'uniform',
    this.low = -5.12,
    this.high = 5.12,
    this.items,
  });

  Map<String, dynamic> toJson() {
    if (kind == 'uniform') {
      return {'kind': 'uniform', 'low': low, 'high': high};
    }
    return {'kind': 'per_dim', 'items': items};
  }
}

class ProblemConfig {
  int dims;
  BoundsConfig bounds;

  ProblemConfig({this.dims = 10, BoundsConfig? bounds})
      : bounds = bounds ?? BoundsConfig();

  Map<String, dynamic> toJson() => {
        'dims': dims,
        'bounds': bounds.toJson(),
      };
}

class StreamingInclude {
  bool bestX;
  bool bestF;
  bool population;
  bool fitness;
  bool velocities;

  StreamingInclude({
    this.bestX = true,
    this.bestF = true,
    this.population = false,
    this.fitness = false,
    this.velocities = false,
  });

  Map<String, dynamic> toJson() => {
        'best_x': bestX,
        'best_f': bestF,
        'population': population,
        'fitness': fitness,
        'velocities': velocities,
      };
}

class StreamingConfig {
  String mode;
  int everyK;
  StreamingInclude include;

  StreamingConfig({
    this.mode = 'per_generation',
    this.everyK = 1,
    StreamingInclude? include,
  }) : include = include ?? StreamingInclude();

  Map<String, dynamic> toJson() => {
        'mode': mode,
        'every_k': everyK,
        'include': include.toJson(),
        'max_points': {'history_best_f': 5000},
      };
}

class OutputConfig {
  bool returnFinalPopulation;
  bool returnFinalFitness;
  bool returnFinalVelocities;

  OutputConfig({
    this.returnFinalPopulation = true,
    this.returnFinalFitness = true,
    this.returnFinalVelocities = false,
  });

  Map<String, dynamic> toJson() => {
        'return_final_population': returnFinalPopulation,
        'return_final_fitness': returnFinalFitness,
        'return_final_velocities': returnFinalVelocities,
      };
}

class JobConfig {
  ObjectiveConfig objective;
  ProblemConfig problem;
  String methodName;
  Map<String, dynamic> methodConfig;
  StreamingConfig streaming;
  OutputConfig output;
  String priority;
  int timeoutMs;

  JobConfig({
    ObjectiveConfig? objective,
    ProblemConfig? problem,
    this.methodName = 'bbo.classic',
    Map<String, dynamic>? methodConfig,
    StreamingConfig? streaming,
    OutputConfig? output,
    this.priority = 'normal',
    this.timeoutMs = 600000,
  })  : objective = objective ?? ObjectiveConfig(),
        problem = problem ?? ProblemConfig(),
        methodConfig = methodConfig ?? {},
        streaming = streaming ?? StreamingConfig(),
        output = output ?? OutputConfig();

  Map<String, dynamic> toSubmitPayload() => {
        'job': {
          'priority': priority,
          'timeout_ms': timeoutMs,
          'tags': ['mobile'],
        },
        'objective': objective.toJson(),
        'problem': problem.toJson(),
        'method': {
          'name': methodName,
          'config': methodConfig,
        },
        'streaming': streaming.toJson(),
        'output': output.toJson(),
      };
}
