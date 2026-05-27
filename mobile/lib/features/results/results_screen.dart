import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/formatters/number_formatters.dart';
import '../../core/models/job_config.dart';
import '../../core/models/method_configs.dart';
import '../../core/protocol/models.dart';
import '../../core/ws/ws_client.dart';
import '../../visualization/gif_generator.dart';
import '../connection/connection_cubit.dart';
import '../configuration/config_screen.dart';
import '../history/history_screen.dart';
import 'convergence_chart.dart';
import 'contour_map.dart';
import 'surface_3d_screen.dart';

class ResultsScreen extends StatefulWidget {
  final JobResult result;
  final JobConfig config;
  final ServerCapabilities capabilities;
  final List<List<double>> historyBestX;

  const ResultsScreen({
    super.key,
    required this.result,
    required this.config,
    required this.capabilities,
    this.historyBestX = const [],
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  int _projX = 0;
  int _projY = 1;
  Uint8List? _gifBytes;
  bool _gifGenerating = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.result.result;
    final m = widget.result.metrics;
    final dims = r.bestX.length;
    final functionName = widget.config.objective.name ?? '';
    final expression = widget.config.objective.kind == 'expression'
        ? widget.config.objective.expr
        : null;
    final population = r.finalPopulation ?? r.finalPositions;

    return Scaffold(
      appBar: AppBar(title: const Text('Результаты')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (expression != null && expression.trim().isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Функция',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      SelectableText(
                        expression,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Лучшее f(x)',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      formatBestF(r.bestF),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Лучшее x',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                      r.bestX.length,
                      (i) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                'x$i',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                r.bestX[i].toStringAsFixed(8),
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Метрики',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _MetricRow('Метод', methodNames[m.method] ?? m.method),
                    _MetricRow('Итерации', m.iterations.toString()),
                    _MetricRow('Вычисления', m.evals.toString()),
                    _MetricRow(
                      'Время',
                      '${(m.wallTimeMs / 1000).toStringAsFixed(2)}с',
                    ),
                    if (m.seed != null) _MetricRow('Seed', m.seed.toString()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Сходимость', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: ConvergenceChart(values: r.historyBestF),
            ),
            if (dims >= 2) ...[
              const SizedBox(height: 16),
              Text(
                '2D-визуализация',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (dims > 2) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _projX,
                        decoration: const InputDecoration(
                          labelText: 'Ось X',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: List.generate(
                          dims,
                          (i) => DropdownMenuItem(value: i, child: Text('x$i')),
                        ),
                        onChanged: (v) => setState(() => _projX = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _projY,
                        decoration: const InputDecoration(
                          labelText: 'Ось Y',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: List.generate(
                          dims,
                          (i) => DropdownMenuItem(value: i, child: Text('x$i')),
                        ),
                        onChanged: (v) => setState(() => _projY = v!),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              ContourMapWidget(
                functionName: functionName,
                expression: expression,
                dims: dims,
                xMin: _axisLow(_projX),
                xMax: _axisHigh(_projX),
                yMin: _axisLow(_projY),
                yMax: _axisHigh(_projY),
                population: population,
                bestPoint: r.bestX,
                dimX: _projX,
                dimY: _projY,
              ),
              const SizedBox(height: 12),
              if (_gifBytes != null) ...[
                Text(
                  'GIF-анимация оптимизации',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_gifBytes!),
                ),
                const SizedBox(height: 8),
              ],
              FilledButton.icon(
                onPressed: _gifGenerating
                    ? null
                    : () => _generateGif(functionName),
                icon: _gifGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.gif_box),
                label: Text(
                  _gifGenerating ? 'Генерация GIF...' : 'Сгенерировать GIF',
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _open3DView(functionName, dims),
                icon: const Icon(Icons.threed_rotation),
                label: const Text('3D-визуализация'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                ),
              ),
            ],
            if (population != null) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: const Text('Финальная популяция'),
                children: [
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: population.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        child: Text(
                          population[i]
                              .map((v) => v.toStringAsFixed(4))
                              .join(', '),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => RepositoryProvider.value(
                            value: context.read<WsClient>(),
                            child: BlocProvider.value(
                              value: context.read<ConnectionCubit>(),
                              child: ConfigScreen(
                                capabilities: widget.capabilities,
                              ),
                            ),
                          ),
                        ),
                        (route) => route.isFirst,
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Новая задача'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RepositoryProvider.value(
                            value: context.read<WsClient>(),
                            child: BlocProvider.value(
                              value: context.read<ConnectionCubit>(),
                              child: HistoryScreen(
                                capabilities: widget.capabilities,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Сравнить'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _open3DView(String functionName, int dims) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Surface3DScreen(
          functionName: functionName,
          expression: widget.config.objective.kind == 'expression'
              ? widget.config.objective.expr
              : null,
          xMin: _axisLow(_projX),
          xMax: _axisHigh(_projX),
          yMin: _axisLow(_projY),
          yMax: _axisHigh(_projY),
          historyBestX: widget.historyBestX,
          bestPoint: widget.result.result.bestX,
          dimX: _projX,
          dimY: _projY,
          dims: dims,
        ),
      ),
    );
  }

  Future<void> _generateGif(String functionName) async {
    setState(() => _gifGenerating = true);

    final r = widget.result.result;
    final historyBestF = r.historyBestF;
    final population = r.finalPopulation ?? r.finalPositions;
    final bestX = r.bestX;

    try {
      final bytes = await GifGenerator.generate(
        functionName: functionName,
        xMin: _axisLow(_projX),
        xMax: _axisHigh(_projX),
        yMin: _axisLow(_projY),
        yMax: _axisHigh(_projY),
        bestPoint: bestX,
        population: population,
        historyBestF: historyBestF,
        dimX: _projX,
        dimY: _projY,
        frameCount: 20,
        size: 200,
      );
      if (mounted) {
        setState(() {
          _gifBytes = bytes;
          _gifGenerating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _gifGenerating = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ошибка генерации GIF')));
      }
    }
  }

  double _axisLow(int axis) {
    final bounds = widget.config.problem.bounds;
    if (bounds.kind == 'per_dim' &&
        bounds.items != null &&
        axis < bounds.items!.length) {
      return bounds.items![axis][0];
    }
    return bounds.low;
  }

  double _axisHigh(int axis) {
    final bounds = widget.config.problem.bounds;
    if (bounds.kind == 'per_dim' &&
        bounds.items != null &&
        axis < bounds.items!.length) {
      return bounds.items![axis][1];
    }
    return bounds.high;
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  const _MetricRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
