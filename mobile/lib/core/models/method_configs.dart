class BboBaseConfig {
  int popSize;
  int maxGenerations;
  double mutationRate;
  int eliteCount;
  bool forbidSelfDonation;
  int? randomSeed;

  BboBaseConfig({
    this.popSize = 50,
    this.maxGenerations = 200,
    this.mutationRate = 0.01,
    this.eliteCount = 2,
    this.forbidSelfDonation = true,
    this.randomSeed,
  });

  Map<String, dynamic> toJson() => {
        'pop_size': popSize,
        'max_generations': maxGenerations,
        'mutation_rate': mutationRate,
        'elite_count': eliteCount,
        'forbid_self_donation': forbidSelfDonation,
        if (randomSeed != null) 'random_seed': randomSeed,
      };
}

class BboMixedConfig extends BboBaseConfig {
  double mixAlpha;

  BboMixedConfig({
    super.popSize,
    super.maxGenerations,
    super.mutationRate,
    super.eliteCount,
    super.forbidSelfDonation,
    super.randomSeed,
    this.mixAlpha = 0.5,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'mix_alpha': mixAlpha,
      };
}

class BboModifiedConfig {
  int popSize;
  int maxGenerations;
  double mutationStart;
  double mutationEnd;
  int eliteCount;
  bool forbidSelfDonation;
  int stagnationGenerations;
  double restartFraction;
  double mutationBoostFactor;
  bool enableLocalSearch;
  int localSearchInterval;
  int localSearchCount;
  int localSearchSteps;
  double localSearchStepStart;
  double localSearchStepEnd;
  int? randomSeed;

  BboModifiedConfig({
    this.popSize = 50,
    this.maxGenerations = 200,
    this.mutationStart = 0.05,
    this.mutationEnd = 0.005,
    this.eliteCount = 2,
    this.forbidSelfDonation = true,
    this.stagnationGenerations = 25,
    this.restartFraction = 0.3,
    this.mutationBoostFactor = 4.0,
    this.enableLocalSearch = false,
    this.localSearchInterval = 20,
    this.localSearchCount = 2,
    this.localSearchSteps = 20,
    this.localSearchStepStart = 0.25,
    this.localSearchStepEnd = 0.02,
    this.randomSeed,
  });

  Map<String, dynamic> toJson() => {
        'pop_size': popSize,
        'max_generations': maxGenerations,
        'mutation_start': mutationStart,
        'mutation_end': mutationEnd,
        'elite_count': eliteCount,
        'forbid_self_donation': forbidSelfDonation,
        'stagnation_generations': stagnationGenerations,
        'restart_fraction': restartFraction,
        'mutation_boost_factor': mutationBoostFactor,
        'enable_local_search': enableLocalSearch,
        'local_search_interval': localSearchInterval,
        'local_search_count': localSearchCount,
        'local_search_steps': localSearchSteps,
        'local_search_step_start': localSearchStepStart,
        'local_search_step_end': localSearchStepEnd,
        if (randomSeed != null) 'random_seed': randomSeed,
      };
}

class BboMixedModifiedConfig extends BboModifiedConfig {
  double mixAlpha;

  BboMixedModifiedConfig({
    super.popSize,
    super.maxGenerations,
    super.mutationStart,
    super.mutationEnd,
    super.eliteCount,
    super.forbidSelfDonation,
    super.stagnationGenerations,
    super.restartFraction,
    super.mutationBoostFactor,
    super.enableLocalSearch,
    super.localSearchInterval,
    super.localSearchCount,
    super.localSearchSteps,
    super.localSearchStepStart,
    super.localSearchStepEnd,
    super.randomSeed,
    this.mixAlpha = 0.5,
  });

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        'mix_alpha': mixAlpha,
      };
}

class PsoConfig {
  int swarmSize;
  int maxGenerations;
  double wStart;
  double wEnd;
  double c1;
  double c2;
  double vmaxFrac;
  int? randomSeed;

  PsoConfig({
    this.swarmSize = 50,
    this.maxGenerations = 200,
    this.wStart = 0.9,
    this.wEnd = 0.4,
    this.c1 = 2.0,
    this.c2 = 2.0,
    this.vmaxFrac = 0.2,
    this.randomSeed,
  });

  Map<String, dynamic> toJson() => {
        'swarm_size': swarmSize,
        'max_generations': maxGenerations,
        'w_start': wStart,
        'w_end': wEnd,
        'c1': c1,
        'c2': c2,
        'vmax_frac': vmaxFrac,
        if (randomSeed != null) 'random_seed': randomSeed,
      };
}

Map<String, dynamic> createDefaultConfig(String method) {
  return switch (method) {
    'bbo.classic' || 'bbo.sinusoidal' => BboBaseConfig().toJson(),
    'bbo.mixed' => BboMixedConfig().toJson(),
    'bbo.classic.modified' || 'bbo.sinusoidal.modified' =>
      BboModifiedConfig().toJson(),
    'bbo.mixed.modified' => BboMixedModifiedConfig().toJson(),
    'pso' => PsoConfig().toJson(),
    _ => BboBaseConfig().toJson(),
  };
}

bool isModifiedMethod(String method) =>
    method.endsWith('.modified');

bool isMixedMethod(String method) =>
    method.contains('mixed');

bool isPsoMethod(String method) => method == 'pso';

const methodNames = {
  'bbo.classic': 'BBO Classic',
  'bbo.classic.modified': 'BBO Classic Modified',
  'bbo.sinusoidal': 'BBO Sinusoidal',
  'bbo.sinusoidal.modified': 'BBO Sinusoidal Modified',
  'bbo.mixed': 'BBO Mixed',
  'bbo.mixed.modified': 'BBO Mixed Modified',
  'pso': 'PSO',
};

int getMaxIterations(Map<String, dynamic> config) {
  return (config['max_generations'] as num?)?.toInt() ?? 200;
}
