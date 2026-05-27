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
                      key: ValueKey('uniform_low_${problem.bounds.low}'),
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
                      key: ValueKey('uniform_high_${problem.bounds.high}'),
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
            if (problem.bounds.kind == 'per_dim')
              Column(
                children: List.generate(problem.dims, (i) {
                  final item = (problem.bounds.items != null &&
                      i < problem.bounds.items!.length)
                      ? problem.bounds.items![i]
                      : [problem.bounds.low, problem.bounds.high];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text('x${i + 1}',
                              style: Theme.of(context).textTheme.bodyLarge),
                        ),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('per_dim_low_${i}_${item[0]}'),
                            initialValue: item[0].toString(),
                            decoration: const InputDecoration(
                              labelText: 'Мин.',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            onChanged: (v) {
                              final val = double.tryParse(v);
                              if (val != null) {
                                cubit.setBoundsPerDim(i, val, item[1]);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey('per_dim_high_${i}_${item[1]}'),
                            initialValue: item[1].toString(),
                            decoration: const InputDecoration(
                              labelText: 'Макс.',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            onChanged: (v) {
                              final val = double.tryParse(v);
                              if (val != null) {
                                cubit.setBoundsPerDim(i, item[0], val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
          ],
        );
      },
    );
  }
}
