import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config_cubit.dart';

class OutputSection extends StatelessWidget {
  const OutputSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigCubit, ConfigState>(
      builder: (context, state) {
        final cubit = context.read<ConfigCubit>();
        final output = state.config.output;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Выходные данные',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Вернуть финальную популяцию'),
              value: output.returnFinalPopulation,
              onChanged: (v) =>
                  cubit.setOutputFlag('return_final_population', v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Вернуть финальный fitness'),
              value: output.returnFinalFitness,
              onChanged: (v) =>
                  cubit.setOutputFlag('return_final_fitness', v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            CheckboxListTile(
              title: const Text('Вернуть финальные скорости'),
              value: output.returnFinalVelocities,
              onChanged: (v) =>
                  cubit.setOutputFlag('return_final_velocities', v!),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        );
      },
    );
  }
}
