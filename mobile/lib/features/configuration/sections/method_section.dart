import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/method_configs.dart';
import '../config_cubit.dart';

class MethodSection extends StatelessWidget {
  final List<String> availableMethods;
  const MethodSection({super.key, required this.availableMethods});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConfigCubit, ConfigState>(
      builder: (context, state) {
        final cubit = context.read<ConfigCubit>();
        final method = state.config.methodName;
        final mc = state.config.methodConfig;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Метод оптимизации',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey('method_$method'),
              initialValue: method,
              decoration: const InputDecoration(
                labelText: 'Метод',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: availableMethods
                  .map((m) => DropdownMenuItem(
                      value: m, child: Text(methodNames[m] ?? m)))
                  .toList(),
              onChanged: (v) => cubit.setMethod(v!),
            ),
            const SizedBox(height: 16),
            if (isPsoMethod(method)) ..._psoFields(cubit, mc),
            if (!isPsoMethod(method) && !isModifiedMethod(method))
              ..._bboBaseFields(cubit, mc),
            if (!isPsoMethod(method) && isModifiedMethod(method))
              ..._bboModifiedFields(cubit, mc),
            if (isMixedMethod(method)) _mixAlphaField(cubit, mc),
          ],
        );
      },
    );
  }

  List<Widget> _bboBaseFields(ConfigCubit cubit, Map<String, dynamic> mc) {
    return [
      _IntField(
        label: 'Размер популяции',
        value: mc['pop_size'] as int? ?? 50,
        onChanged: (v) => cubit.setMethodConfigValue('pop_size', v),
      ),
      _IntField(
        label: 'Макс. поколений',
        value: mc['max_generations'] as int? ?? 200,
        onChanged: (v) => cubit.setMethodConfigValue('max_generations', v),
      ),
      _DoubleField(
        label: 'Частота мутации',
        value: mc['mutation_rate'] as double? ?? 0.01,
        onChanged: (v) => cubit.setMethodConfigValue('mutation_rate', v),
      ),
      _IntField(
        label: 'Элитных особей',
        value: mc['elite_count'] as int? ?? 2,
        onChanged: (v) => cubit.setMethodConfigValue('elite_count', v),
      ),
      _SwitchField(
        label: 'Запрет самомиграции',
        value: mc['forbid_self_donation'] as bool? ?? true,
        onChanged: (v) => cubit.setMethodConfigValue('forbid_self_donation', v),
      ),
      _NullableIntField(
        label: 'Seed',
        value: mc['random_seed'] as int?,
        onChanged: (v) => cubit.setMethodConfigValue('random_seed', v),
      ),
    ];
  }

  List<Widget> _bboModifiedFields(
      ConfigCubit cubit, Map<String, dynamic> mc) {
    return [
      _IntField(
        label: 'Размер популяции',
        value: mc['pop_size'] as int? ?? 50,
        onChanged: (v) => cubit.setMethodConfigValue('pop_size', v),
      ),
      _IntField(
        label: 'Макс. поколений',
        value: mc['max_generations'] as int? ?? 200,
        onChanged: (v) => cubit.setMethodConfigValue('max_generations', v),
      ),
      _DoubleField(
        label: 'Мутация (начало)',
        value: mc['mutation_start'] as double? ?? 0.05,
        onChanged: (v) => cubit.setMethodConfigValue('mutation_start', v),
      ),
      _DoubleField(
        label: 'Мутация (конец)',
        value: mc['mutation_end'] as double? ?? 0.005,
        onChanged: (v) => cubit.setMethodConfigValue('mutation_end', v),
      ),
      _IntField(
        label: 'Элитных особей',
        value: mc['elite_count'] as int? ?? 2,
        onChanged: (v) => cubit.setMethodConfigValue('elite_count', v),
      ),
      _SwitchField(
        label: 'Запрет самомиграции',
        value: mc['forbid_self_donation'] as bool? ?? true,
        onChanged: (v) => cubit.setMethodConfigValue('forbid_self_donation', v),
      ),
      _IntField(
        label: 'Поколений стагнации',
        value: mc['stagnation_generations'] as int? ?? 25,
        onChanged: (v) =>
            cubit.setMethodConfigValue('stagnation_generations', v),
      ),
      _DoubleField(
        label: 'Доля перезапуска',
        value: mc['restart_fraction'] as double? ?? 0.3,
        onChanged: (v) => cubit.setMethodConfigValue('restart_fraction', v),
      ),
      _DoubleField(
        label: 'Множитель усиления мутации',
        value: mc['mutation_boost_factor'] as double? ?? 4.0,
        onChanged: (v) =>
            cubit.setMethodConfigValue('mutation_boost_factor', v),
      ),
      _SwitchField(
        label: 'Локальный поиск',
        value: mc['enable_local_search'] as bool? ?? false,
        onChanged: (v) =>
            cubit.setMethodConfigValue('enable_local_search', v),
      ),
      if (mc['enable_local_search'] == true) ...[
        _IntField(
          label: 'Интервал лок. поиска',
          value: mc['local_search_interval'] as int? ?? 20,
          onChanged: (v) =>
              cubit.setMethodConfigValue('local_search_interval', v),
        ),
        _IntField(
          label: 'Кол-во лок. поисков',
          value: mc['local_search_count'] as int? ?? 2,
          onChanged: (v) =>
              cubit.setMethodConfigValue('local_search_count', v),
        ),
        _IntField(
          label: 'Шагов лок. поиска',
          value: mc['local_search_steps'] as int? ?? 20,
          onChanged: (v) =>
              cubit.setMethodConfigValue('local_search_steps', v),
        ),
        _DoubleField(
          label: 'Шаг лок. поиска (начало)',
          value: mc['local_search_step_start'] as double? ?? 0.25,
          onChanged: (v) =>
              cubit.setMethodConfigValue('local_search_step_start', v),
        ),
        _DoubleField(
          label: 'Шаг лок. поиска (конец)',
          value: mc['local_search_step_end'] as double? ?? 0.02,
          onChanged: (v) =>
              cubit.setMethodConfigValue('local_search_step_end', v),
        ),
      ],
      _NullableIntField(
        label: 'Seed',
        value: mc['random_seed'] as int?,
        onChanged: (v) => cubit.setMethodConfigValue('random_seed', v),
      ),
    ];
  }

  Widget _mixAlphaField(ConfigCubit cubit, Map<String, dynamic> mc) {
    return _DoubleField(
      label: 'Альфа смешивания',
      value: mc['mix_alpha'] as double? ?? 0.5,
      onChanged: (v) => cubit.setMethodConfigValue('mix_alpha', v),
    );
  }

  List<Widget> _psoFields(ConfigCubit cubit, Map<String, dynamic> mc) {
    return [
      _IntField(
        label: 'Размер роя',
        value: mc['swarm_size'] as int? ?? 50,
        onChanged: (v) => cubit.setMethodConfigValue('swarm_size', v),
      ),
      _IntField(
        label: 'Макс. поколений',
        value: mc['max_generations'] as int? ?? 200,
        onChanged: (v) => cubit.setMethodConfigValue('max_generations', v),
      ),
      _DoubleField(
        label: 'W (начало)',
        value: mc['w_start'] as double? ?? 0.9,
        onChanged: (v) => cubit.setMethodConfigValue('w_start', v),
      ),
      _DoubleField(
        label: 'W (конец)',
        value: mc['w_end'] as double? ?? 0.4,
        onChanged: (v) => cubit.setMethodConfigValue('w_end', v),
      ),
      _DoubleField(
        label: 'C1',
        value: mc['c1'] as double? ?? 2.0,
        onChanged: (v) => cubit.setMethodConfigValue('c1', v),
      ),
      _DoubleField(
        label: 'C2',
        value: mc['c2'] as double? ?? 2.0,
        onChanged: (v) => cubit.setMethodConfigValue('c2', v),
      ),
      _DoubleField(
        label: 'Доля Vmax',
        value: mc['vmax_frac'] as double? ?? 0.2,
        onChanged: (v) => cubit.setMethodConfigValue('vmax_frac', v),
      ),
      _NullableIntField(
        label: 'Seed',
        value: mc['random_seed'] as int?,
        onChanged: (v) => cubit.setMethodConfigValue('random_seed', v),
      ),
    ];
  }
}

class _IntField extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _IntField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        onChanged: (v) {
          final parsed = int.tryParse(v);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }
}

class _DoubleField extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _DoubleField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        onChanged: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }
}

class _NullableIntField extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  const _NullableIntField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        decoration: InputDecoration(
          labelText: '$label (необязательно)',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: TextInputType.number,
        onChanged: (v) {
          if (v.isEmpty) {
            onChanged(null);
          } else {
            final parsed = int.tryParse(v);
            onChanged(parsed);
          }
        },
      ),
    );
  }
}

class _SwitchField extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(label),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}
