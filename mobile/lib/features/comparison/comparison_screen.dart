import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/formatters/number_formatters.dart';
import '../../core/models/job_result.dart';
import '../../core/models/method_configs.dart';
import '../results/convergence_chart.dart';

class ComparisonScreen extends StatelessWidget {
  final List<SavedJobResult> results;

  const ComparisonScreen({super.key, required this.results});

  static const _colors = [
    Colors.indigo,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.brown,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Сравнение')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Сравнение сходимости',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: MultiConvergenceChart(
                series: results
                    .map((r) => r.resultData?.historyBestF ?? [])
                    .toList(),
                labels: results
                    .map(
                      (r) =>
                          '${methodNames[r.method] ?? r.method} (${r.objectiveName})',
                    )
                    .toList(),
                colors: _colors,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Таблица сравнения',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Метод')),
                  DataColumn(label: Text('Функция')),
                  DataColumn(label: Text('Разм.')),
                  DataColumn(label: Text('Лучшее f'), numeric: true),
                  DataColumn(label: Text('Итерации'), numeric: true),
                  DataColumn(label: Text('Время (с)'), numeric: true),
                ],
                rows: results.map((r) {
                  return DataRow(
                    cells: [
                      DataCell(Text(methodNames[r.method] ?? r.method)),
                      DataCell(Text(r.objectiveName)),
                      DataCell(Text(r.dims.toString())),
                      DataCell(Text(formatBestF(r.bestF, maxPlainLength: 12))),
                      DataCell(Text(r.metrics?.iterations.toString() ?? '-')),
                      DataCell(
                        Text(
                          r.metrics != null
                              ? (r.metrics!.wallTimeMs / 1000).toStringAsFixed(
                                  2,
                                )
                              : '-',
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Лучшее f(x) по методам',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: List.generate(results.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: results[i].bestF,
                          color: _colors[i % _colors.length],
                          width: 24,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= results.length) {
                            return const SizedBox.shrink();
                          }
                          return SideTitleWidget(
                            meta: meta,
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: Text(
                                methodNames[results[idx].method] ??
                                    results[idx].method,
                                style: const TextStyle(fontSize: 9),
                              ),
                            ),
                          );
                        },
                        reservedSize: 80,
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
