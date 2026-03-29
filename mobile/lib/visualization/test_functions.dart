import 'dart:math' as math;

double sphere(List<double> x) {
  double sum = 0;
  for (final v in x) {
    sum += v * v;
  }
  return sum;
}

double rastrigin(List<double> x, {double a = 10.0}) {
  double sum = a * x.length;
  for (final v in x) {
    sum += v * v - a * math.cos(2 * math.pi * v);
  }
  return sum;
}

double ackley(List<double> x,
    {double a = 20.0, double b = 0.2, double c = 2 * math.pi}) {
  final n = x.length;
  double sumSq = 0;
  double sumCos = 0;
  for (final v in x) {
    sumSq += v * v;
    sumCos += math.cos(c * v);
  }
  return -a * math.exp(-b * math.sqrt(sumSq / n)) -
      math.exp(sumCos / n) +
      a +
      math.e;
}

double bukin6(List<double> x) {
  final x1 = x[0];
  final x2 = x[1];
  return 100 * math.sqrt((x2 - 0.01 * x1 * x1).abs()) +
      0.01 * (x1 + 10).abs();
}

typedef TestFunction = double Function(List<double> x);

TestFunction? getTestFunction(String name) {
  return switch (name) {
    'sphere' => sphere,
    'rastrigin' => rastrigin,
    'ackley' => ackley,
    'bukin6' => bukin6,
    _ => null,
  };
}

const builtinFunctions = ['sphere', 'rastrigin', 'ackley', 'bukin6'];

Map<String, List<double>> defaultBounds = {
  'sphere': [-5.12, 5.12],
  'rastrigin': [-5.12, 5.12],
  'ackley': [-5.0, 5.0],
  'bukin6': [-15.0, -5.0],
};
