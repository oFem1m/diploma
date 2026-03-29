import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../core/models/job_config.dart';
import '../../core/models/method_configs.dart';
import '../../core/protocol/models.dart';
import '../../core/ws/ws_client.dart';
import '../connection/connection_cubit.dart';
import '../comparison/comparison_screen.dart';
import '../results/results_screen.dart';
import 'history_cubit.dart';

class HistoryScreen extends StatelessWidget {
  final ServerCapabilities capabilities;
  const HistoryScreen({super.key, required this.capabilities});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HistoryCubit(),
      child: _HistoryBody(capabilities: capabilities),
    );
  }
}

class _HistoryBody extends StatelessWidget {
  final ServerCapabilities capabilities;
  const _HistoryBody({required this.capabilities});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История'),
        actions: [
          BlocBuilder<HistoryCubit, HistoryState>(
            builder: (context, state) {
              if (state.selectedIds.length >= 2) {
                return TextButton.icon(
                  onPressed: () => _compare(context),
                  icon: const Icon(Icons.compare_arrows),
                  label: Text('Сравнить (${state.selectedIds.length})'),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              final cubit = context.read<HistoryCubit>();
              if (v == 'clear') {
                cubit.clearFilters();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'clear',
                child: Text('Сбросить фильтры'),
              ),
            ],
          ),
        ],
      ),
      body: BlocBuilder<HistoryCubit, HistoryState>(
        builder: (context, state) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.results.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Пока нет результатов'),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: state.filterMethod,
                        decoration: const InputDecoration(
                          labelText: 'Метод',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Все')),
                          ...methodNames.entries.map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                overflow: TextOverflow.ellipsis,
                              ))),
                        ],
                        onChanged: (v) =>
                            context.read<HistoryCubit>().setFilterMethod(v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: state.filterObjective,
                        decoration: const InputDecoration(
                          labelText: 'Функция',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Все')),
                          DropdownMenuItem(
                              value: 'sphere', child: Text('sphere')),
                          DropdownMenuItem(
                              value: 'rastrigin', child: Text('rastrigin')),
                          DropdownMenuItem(
                              value: 'ackley', child: Text('ackley')),
                          DropdownMenuItem(
                              value: 'bukin6', child: Text('bukin6')),
                        ],
                        onChanged: (v) => context
                            .read<HistoryCubit>()
                            .setFilterObjective(v),
                      ),
                    ),
                  ],
                ),
              ),
              if (state.selectedIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Выбрано: ${state.selectedIds.length}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            context.read<HistoryCubit>().clearSelection(),
                        child: const Text('Сбросить'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: state.results.length,
                  itemBuilder: (context, index) {
                    final r = state.results[index];
                    final isSelected =
                        r.id != null && state.selectedIds.contains(r.id);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      color: isSelected
                          ? Theme.of(context)
                              .colorScheme
                              .primaryContainer
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(r.status),
                          child: Icon(
                            _statusIcon(r.status),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          methodNames[r.method] ?? r.method,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${r.objectiveName} | ${r.dims}D | '
                          'f=${r.bestF.toStringAsExponential(4)}\n'
                          '${DateFormat.yMd().add_Hms().format(r.createdAt)}',
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) =>
                              _onAction(context, v, r),
                          itemBuilder: (_) => [
                            if (r.resultData != null)
                              const PopupMenuItem(
                                value: 'view',
                                child: Text('Просмотр'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Удалить'),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (r.id != null) {
                            context
                                .read<HistoryCubit>()
                                .toggleSelection(r.id!);
                          }
                        },
                        onLongPress: () {
                          if (r.resultData != null) {
                            _viewResult(context, r);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onAction(BuildContext context, String action,
      dynamic r) {
    switch (action) {
      case 'view':
        _viewResult(context, r);
      case 'delete':
        if (r.id != null) {
          context.read<HistoryCubit>().deleteResult(r.id!);
        }
    }
  }

  void _viewResult(BuildContext context, dynamic r) {
    if (r.resultData == null || r.metrics == null) return;

    final jobResult = JobResult(
      jobId: r.jobId,
      result: r.resultData!,
      metrics: r.metrics!,
    );

    final config = JobConfig(
      methodName: r.method,
      objective: ObjectiveConfig(
        kind: r.objectiveKind,
        name: r.objectiveName,
      ),
      problem: ProblemConfig(dims: r.dims),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: context.read<WsClient>(),
          child: BlocProvider.value(
            value: context.read<ConnectionCubit>(),
            child: ResultsScreen(
              result: jobResult,
              config: config,
              capabilities: capabilities,
            ),
          ),
        ),
      ),
    );
  }

  void _compare(BuildContext context) {
    final cubit = context.read<HistoryCubit>();
    final selected = cubit.selectedResults;
    if (selected.length < 2) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComparisonScreen(results: selected),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'succeeded' => Colors.green,
      'failed' => Colors.red,
      'cancelled' => Colors.orange,
      'timeout' => Colors.amber,
      _ => Colors.grey,
    };
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'succeeded' => Icons.check,
      'failed' => Icons.close,
      'cancelled' => Icons.cancel,
      'timeout' => Icons.timer_off,
      _ => Icons.help,
    };
  }
}
