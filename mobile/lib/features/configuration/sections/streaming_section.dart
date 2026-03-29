import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config_cubit.dart';

class StreamingSection extends StatelessWidget {
  const StreamingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigCubit, ConfigState>(
      builder: (context, state) {
        final cubit = context.read<ConfigCubit>();
        final streaming = state.config.streaming;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Потоковая передача',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('stream_${streaming.mode}'),
              initialValue: streaming.mode,
              decoration: const InputDecoration(
                labelText: 'Режим',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'per_generation', child: Text('Каждое поколение')),
                DropdownMenuItem(value: 'every_k', child: Text('Каждые K')),
                DropdownMenuItem(value: 'none', child: Text('Отключено')),
              ],
              onChanged: (v) => cubit.setStreamingMode(v!),
            ),
            if (streaming.mode == 'every_k') ...[
              const SizedBox(height: 12),
              TextFormField(
                initialValue: streaming.everyK.toString(),
                decoration: const InputDecoration(
                  labelText: 'Каждые K',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final parsed = int.tryParse(v);
                  if (parsed != null) cubit.setEveryK(parsed);
                },
              ),
            ],
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Включить best_x'),
              value: streaming.include.bestX,
              onChanged: (v) => cubit.setStreamingInclude('best_x', v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Включить best_f'),
              value: streaming.include.bestF,
              onChanged: (v) => cubit.setStreamingInclude('best_f', v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Включить популяцию'),
              value: streaming.include.population,
              onChanged: (v) => cubit.setStreamingInclude('population', v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Включить fitness'),
              value: streaming.include.fitness,
              onChanged: (v) => cubit.setStreamingInclude('fitness', v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Включить скорости'),
              value: streaming.include.velocities,
              onChanged: (v) => cubit.setStreamingInclude('velocities', v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        );
      },
    );
  }
}
