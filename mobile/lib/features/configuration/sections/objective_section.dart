import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../visualization/test_functions.dart';
import '../config_cubit.dart';

class ObjectiveSection extends StatelessWidget {
  const ObjectiveSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigCubit, ConfigState>(
      builder: (context, state) {
        final cubit = context.read<ConfigCubit>();
        final obj = state.config.objective;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Целевая функция',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('obj_kind_${obj.kind}'),
              initialValue: obj.kind,
              decoration: const InputDecoration(
                labelText: 'Тип',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'builtin', child: Text('Встроенная')),
                DropdownMenuItem(value: 'expression', child: Text('Выражение')),
              ],
              onChanged: (v) => cubit.setObjectiveKind(v!),
            ),
            const SizedBox(height: 12),
            if (obj.kind == 'builtin')
              DropdownButtonFormField<String>(
                key: ValueKey('obj_name_${obj.name}'),
                initialValue: obj.name,
                decoration: const InputDecoration(
                  labelText: 'Функция',
                  border: OutlineInputBorder(),
                ),
                items: builtinFunctions
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => cubit.setObjectiveName(v!),
              )
            else
              TextFormField(
                key: ValueKey('obj_expr_${obj.kind}'),
                initialValue: obj.expr ?? '',
                decoration: const InputDecoration(
                  labelText: 'Выражение (напр. x0*x0 + x1*x1)',
                  border: OutlineInputBorder(),
                ),
                onChanged: cubit.setExpression,
              ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Минимизация'),
              value: obj.minimize,
              onChanged: (v) => cubit.setMinimize(v),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        );
      },
    );
  }
}
