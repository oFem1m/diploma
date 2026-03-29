import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../core/protocol/models.dart';
import '../../core/ws/ws_client.dart';
import '../connection/connection_cubit.dart';
import '../progress/progress_screen.dart';
import '../progress/progress_cubit.dart';
import '../history/history_screen.dart';
import 'config_cubit.dart';
import 'sections/objective_section.dart';
import 'sections/problem_section.dart';
import 'sections/method_section.dart';
import 'sections/streaming_section.dart';
import 'sections/output_section.dart';

class ConfigScreen extends StatelessWidget {
  final ServerCapabilities capabilities;
  const ConfigScreen({super.key, required this.capabilities});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConfigCubit(),
      child: _ConfigScreenBody(capabilities: capabilities),
    );
  }
}

class _ConfigScreenBody extends StatelessWidget {
  final ServerCapabilities capabilities;
  const _ConfigScreenBody({required this.capabilities});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройка задачи'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RepositoryProvider.value(
                  value: context.read<WsClient>(),
                  child: BlocProvider.value(
                    value: context.read<ConnectionCubit>(),
                    child: HistoryScreen(capabilities: capabilities),
                  ),
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune),
            onSelected: (v) => context.read<ConfigCubit>().applyPreset(v),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'rastrigin_bbo',
                child: Text('Rastrigin 10D BBO Classic'),
              ),
              PopupMenuItem(
                value: 'sphere_pso',
                child: Text('Sphere 10D PSO'),
              ),
              PopupMenuItem(
                value: 'ackley_modified',
                child: Text('Ackley 10D BBO Modified'),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ObjectiveSection(),
            const Divider(height: 32),
            const ProblemSection(),
            const Divider(height: 32),
            MethodSection(availableMethods: capabilities.methods),
            const Divider(height: 32),
            const StreamingSection(),
            const Divider(height: 32),
            const OutputSection(),
            const SizedBox(height: 24),
            BlocBuilder<ConfigCubit, ConfigState>(
              builder: (context, state) {
                return FilledButton.icon(
                  onPressed: () => _submit(context),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Запустить оптимизацию'),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext context) {
    final cubit = context.read<ConfigCubit>();
    final error = cubit.validate();
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final config = cubit.state.config;
    final clientReqId = 'req-${const Uuid().v4().substring(0, 8)}';
    final ws = context.read<WsClient>();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RepositoryProvider.value(
          value: ws,
          child: BlocProvider.value(
            value: context.read<ConnectionCubit>(),
            child: BlocProvider(
              create: (_) => ProgressCubit(ws, config, clientReqId: clientReqId),
              child: ProgressScreen(capabilities: capabilities),
            ),
          ),
        ),
      ),
    );
  }
}
