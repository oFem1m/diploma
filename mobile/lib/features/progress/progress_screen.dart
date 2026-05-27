import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/job_result.dart';
import '../../core/protocol/models.dart';
import '../../core/ws/ws_client.dart';
import '../../storage/database.dart';
import '../connection/connection_cubit.dart';
import '../results/results_screen.dart';
import 'convergence_live_chart.dart';
import 'progress_cubit.dart';

class ProgressScreen extends StatelessWidget {
  final ServerCapabilities capabilities;
  const ProgressScreen({super.key, required this.capabilities});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выполнение')),
      body: BlocConsumer<ProgressCubit, ProgressState>(
        listener: (context, state) {
          if (state.phase == JobPhase.succeeded && state.result != null) {
            _saveAndNavigate(context, state);
          }
          if (state.phase == JobPhase.failed ||
              state.phase == JobPhase.cancelled ||
              state.phase == JobPhase.timeout) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.errorMessage ?? 'Задача: ${state.phase.name}',
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.phase == JobPhase.submitting) ...[
                      const Icon(Icons.outbox, size: 48, color: Colors.indigo),
                      const SizedBox(height: 16),
                      Text(
                        state.isReconnecting
                            ? 'Ожидаем соединение с сервером'
                            : 'Отправка задачи на сервер',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ] else if (state.phase == JobPhase.queued) ...[
                      const Icon(Icons.queue, size: 48, color: Colors.orange),
                      const SizedBox(height: 16),
                      Text(
                        state.queuePosition != null
                            ? 'В очереди: позиция ${state.queuePosition}'
                            : 'Задача принята сервером',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (state.queueEtaMs != null)
                        Text(
                          'Ожидание: ${(state.queueEtaMs! / 1000).toStringAsFixed(0)}с',
                          textAlign: TextAlign.center,
                        ),
                      const SizedBox(height: 16),
                      const LinearProgressIndicator(),
                    ] else ...[
                      LinearProgressIndicator(value: state.progress),
                      const SizedBox(height: 8),
                      Text(
                        '${state.iteration} / ${state.maxIterations} '
                        '(${(state.progress * 100).toStringAsFixed(1)}%)',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      if (state.bestF != null)
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
                                  state.bestF!.toStringAsExponential(6),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.indigo,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        'Время: ${(state.elapsedMs / 1000).toStringAsFixed(1)}с',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Сходимость',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: ConvergenceLiveChart(
                                    values: state.historyBestF,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (state.bestX != null && state.bestX!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 60,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: state.bestX!.length,
                                itemBuilder: (_, i) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Chip(
                                    label: Text(
                                      'x$i=${state.bestX![i].toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                    const SizedBox(height: 8),
                    if (state.phase != JobPhase.succeeded &&
                        state.phase != JobPhase.failed &&
                        state.phase != JobPhase.cancelled &&
                        state.phase != JobPhase.timeout)
                      OutlinedButton.icon(
                        onPressed: () =>
                            context.read<ProgressCubit>().cancelJob(),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Отменить'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    if (state.phase == JobPhase.failed ||
                        state.phase == JobPhase.cancelled ||
                        state.phase == JobPhase.timeout)
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Назад'),
                      ),
                  ],
                ),
              ),
              if (state.isReconnecting)
                _ReconnectBanner(
                  remainingSeconds: state.reconnectRemainingSeconds,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAndNavigate(
    BuildContext context,
    ProgressState state,
  ) async {
    final result = state.result!;
    final cubit = context.read<ProgressCubit>();
    final config = cubit.config;
    final historyBestX = List<List<double>>.from(state.historyBestX);

    final saved = SavedJobResult(
      jobId: result.jobId,
      method: result.metrics.method,
      objectiveName: config.objective.name ?? config.objective.expr ?? '',
      objectiveKind: config.objective.kind,
      dims: config.problem.dims,
      bestF: result.result.bestF,
      status: 'succeeded',
      resultData: result.result,
      metrics: result.metrics,
      config: config.toSubmitPayload(),
      createdAt: DateTime.now(),
    );
    await AppDatabase.insertResult(saved);

    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: context.read<WsClient>(),
          child: BlocProvider.value(
            value: context.read<ConnectionCubit>(),
            child: ResultsScreen(
              result: result,
              config: config,
              capabilities: capabilities,
              historyBestX: historyBestX,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  final int remainingSeconds;

  const _ReconnectBanner({required this.remainingSeconds});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.inverseSurface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onInverseSurface,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Сервер не отвечает. Подключение через '
                      '$remainingSeconds с',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onInverseSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
