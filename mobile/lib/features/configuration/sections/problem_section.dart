import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config_cubit.dart';

class ProblemSection extends StatelessWidget {
  const ProblemSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigCubit, ConfigState>(
      builder: (context, state) {
        final cubit = context.read<ConfigCubit>();
        final problem = state.config.problem;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Пространство поиска',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Размерность: '),
                Expanded(
                  child: Slider(
                    value: problem.dims.toDouble(),
                    min: 1,
                    max: 100,
                    divisions: 99,
                    label: '${problem.dims}',
                    onChanged: (v) => cubit.setDims(v.round()),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text('${problem.dims}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('bounds_${problem.bounds.kind}'),
              initialValue: problem.bounds.kind,
              decoration: const InputDecoration(
                labelText: 'Тип границ',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'uniform', child: Text('Одинаковые')),
                DropdownMenuItem(
                    value: 'per_dim', child: Text('По измерениям')),
              ],
              onChanged: (v) => cubit.setBoundsKind(v!),
            ),
            const SizedBox(height: 12),
            if (problem.bounds.kind == 'uniform')
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: problem.bounds.low.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Мин.',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      onChanged: (v) {
                        final val = double.tryParse(v);
                        if (val != null) {
                          cubit.setBoundsUniform(val, problem.bounds.high);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: problem.bounds.high.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Макс.',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      onChanged: (v) {
                        final val = double.tryParse(v);
                        if (val != null) {
                          cubit.setBoundsUniform(problem.bounds.low, val);
                        }
                      },
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
