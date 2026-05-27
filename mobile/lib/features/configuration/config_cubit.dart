import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/job_config.dart';
import '../../core/models/method_configs.dart';
import '../../visualization/test_functions.dart';

class ConfigState extends Equatable {
  final JobConfig config;
  final String? validationError;
  final int _version;

  const ConfigState({
    required this.config,
    this.validationError,
    int version = 0,
  }) : _version = version;

  ConfigState copyWith({
    JobConfig? config,
    String? validationError,
    int? version,
  }) {
    return ConfigState(
      config: config ?? this.config,
      validationError: validationError,
      version: version ?? _version,
    );
  }

  int get version => _version;

  @override
  List<Object?> get props => [_version, validationError];
}

class ConfigCubit extends Cubit<ConfigState> {
  ConfigCubit() : super(ConfigState(config: _defaultConfig()));

  static JobConfig _defaultConfig() {
    final config = JobConfig();
    config.methodConfig = createDefaultConfig(config.methodName);
    return config;
  }

  void setObjectiveKind(String kind) {
    state.config.objective.kind = kind;
    _emitUpdated();
  }

  void setObjectiveName(String name) {
    state.config.objective.name = name;
    final pd = defaultBoundsPerDim[name];
    if (pd != null) {
      state.config.problem.dims = pd.length;
      state.config.problem.bounds.kind = 'per_dim';
      state.config.problem.bounds.items = pd.map((p) => [p[0], p[1]]).toList();
    } else {
      final b = defaultBoundsUniform[name];
      if (b != null) {
        state.config.problem.bounds.kind = 'uniform';
        state.config.problem.bounds.low = b[0];
        state.config.problem.bounds.high = b[1];
        state.config.problem.bounds.items = null;
      }
    }
    _emitUpdated();
  }

  void setExpression(String expr) {
    state.config.objective.expr = expr;
    _emitUpdated();
  }

  void setMinimize(bool minimize) {
    state.config.objective.minimize = minimize;
    _emitUpdated();
  }

  void setDims(int dims) {
    state.config.problem.dims = dims;
    final b = state.config.problem.bounds;
    if (b.kind == 'per_dim') {
      final old = b.items ?? [];
      b.items = List.generate(
        dims,
        (i) => i < old.length ? old[i] : [b.low, b.high],
      );
    }
    _emitUpdated();
  }

  void setBoundsKind(String kind) {
    state.config.problem.bounds.kind = kind;
    if (kind == 'per_dim' && state.config.problem.bounds.items == null) {
      state.config.problem.bounds.items = List.generate(
        state.config.problem.dims,
        (_) => [
          state.config.problem.bounds.low,
          state.config.problem.bounds.high,
        ],
      );
    }
    _emitUpdated();
  }

  void setBoundsUniform(double low, double high) {
    state.config.problem.bounds.low = low;
    state.config.problem.bounds.high = high;
    _emitUpdated();
  }

  void setBoundsPerDim(int index, double low, double high) {
    state.config.problem.bounds.items?[index] = [low, high];
    _emitUpdated();
  }

  void setMethod(String method) {
    state.config.methodName = method;
    state.config.methodConfig = createDefaultConfig(method);
    if (!isPsoMethod(method)) {
      state.config.streaming.include.velocities = false;
      state.config.output.returnFinalVelocities = false;
    }
    _emitUpdated();
  }

  void setMethodConfigValue(String key, dynamic value) {
    state.config.methodConfig[key] = value;
    _emitUpdated();
  }

  void setStreamingMode(String mode) {
    state.config.streaming.mode = mode;
    _emitUpdated();
  }

  void setEveryK(int k) {
    state.config.streaming.everyK = k;
    _emitUpdated();
  }

  void setStreamingInclude(String field, bool value) {
    final inc = state.config.streaming.include;
    switch (field) {
      case 'best_x':
        inc.bestX = value;
      case 'best_f':
        inc.bestF = value;
      case 'population':
        inc.population = value;
      case 'fitness':
        inc.fitness = value;
      case 'velocities':
        inc.velocities = value;
    }
    _emitUpdated();
  }

  void setOutputFlag(String field, bool value) {
    final out = state.config.output;
    switch (field) {
      case 'return_final_population':
        out.returnFinalPopulation = value;
      case 'return_final_fitness':
        out.returnFinalFitness = value;
      case 'return_final_velocities':
        out.returnFinalVelocities = value;
    }
    _emitUpdated();
  }

  void setPriority(String priority) {
    state.config.priority = priority;
    _emitUpdated();
  }

  void applyPreset(String preset) {
    final config = state.config;
    switch (preset) {
      case 'rastrigin_bbo':
        config.objective.kind = 'builtin';
        config.objective.name = 'rastrigin';
        config.objective.minimize = true;
        config.problem.dims = 10;
        config.problem.bounds = BoundsConfig(low: -5.12, high: 5.12);
        config.methodName = 'bbo.classic';
        config.methodConfig = createDefaultConfig('bbo.classic');
      case 'sphere_pso':
        config.objective.kind = 'builtin';
        config.objective.name = 'sphere';
        config.objective.minimize = true;
        config.problem.dims = 10;
        config.problem.bounds = BoundsConfig(low: -5.12, high: 5.12);
        config.methodName = 'pso';
        config.methodConfig = createDefaultConfig('pso');
      case 'ackley_modified':
        config.objective.kind = 'builtin';
        config.objective.name = 'ackley';
        config.objective.minimize = true;
        config.problem.dims = 10;
        config.problem.bounds = BoundsConfig(low: -5.0, high: 5.0);
        config.methodName = 'bbo.classic.modified';
        config.methodConfig = createDefaultConfig('bbo.classic.modified');
    }
    _emitUpdated();
  }

  String? validate() {
    final c = state.config;
    if (c.objective.kind == 'expression' &&
        (c.objective.expr == null || c.objective.expr!.isEmpty)) {
      return 'Необходимо ввести выражение';
    }
    if (c.problem.dims < 1 || c.problem.dims > 100) {
      return 'Размерность должна быть от 1 до 100';
    }
    if (c.objective.name == 'bukin6' && c.problem.dims != 2) {
      return 'Bukin N.6 требует 2 измерения';
    }
    if (c.problem.bounds.kind == 'uniform' &&
        c.problem.bounds.low >= c.problem.bounds.high) {
      return 'Нижняя граница должна быть меньше верхней';
    }
    final mc = c.methodConfig;
    final maxGen = mc['max_generations'] as int? ?? 200;
    if (maxGen < 1 || maxGen > 10000) {
      return 'Макс. поколений должно быть от 1 до 10 000';
    }
    if (isPsoMethod(c.methodName)) {
      if ((mc['swarm_size'] as num?) != null && (mc['swarm_size'] as num) < 2) {
        return 'Размер роя должен быть >= 2';
      }
    } else {
      if ((mc['pop_size'] as num?) != null && (mc['pop_size'] as num) < 2) {
        return 'Размер популяции должен быть >= 2';
      }
    }
    return null;
  }

  void _emitUpdated() {
    emit(ConfigState(config: state.config, version: state.version + 1));
  }
}
