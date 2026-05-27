import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/formatters/number_formatters.dart';

class ConvergenceChart extends StatelessWidget {
  final List<double> values;
  final Color color;
  final String? label;

  const ConvergenceChart({
    super.key,
    required this.values,
    this.color = Colors.indigo,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(child: Text('Нет данных'));
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            axisNameWidget: Text('f(x)', style: TextStyle(fontSize: 11)),
            sideTitles: SideTitles(showTitles: true, reservedSize: 50),
          ),
          bottomTitles: const AxisTitles(
            axisNameWidget: Text('Итерация', style: TextStyle(fontSize: 11)),
            sideTitles: SideTitles(showTitles: true, reservedSize: 30),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              return LineTooltipItem(
                'Ит: ${s.x.toInt()}\nf: ${formatBestF(s.y, maxPlainLength: 12)}',
                const TextStyle(color: Colors.white, fontSize: 11),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class MultiConvergenceChart extends StatelessWidget {
  final List<List<double>> series;
  final List<String> labels;
  final List<Color> colors;

  const MultiConvergenceChart({
    super.key,
    required this.series,
    required this.labels,
    required this.colors,
  });

  static const _defaultColors = [
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
    final effectiveColors = colors.isEmpty ? _defaultColors : colors;

    final bars = <LineChartBarData>[];
    for (int s = 0; s < series.length; s++) {
      final spots = <FlSpot>[];
      for (int i = 0; i < series[s].length; i++) {
        spots.add(FlSpot(i.toDouble(), series[s][i]));
      }
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: effectiveColors[s % effectiveColors.length],
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      );
    }

    return Column(
      children: [
        Wrap(
          spacing: 12,
          children: List.generate(labels.length, (i) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  color: effectiveColors[i % effectiveColors.length],
                ),
                const SizedBox(width: 4),
                Text(labels[i], style: const TextStyle(fontSize: 11)),
              ],
            );
          }),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: true),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 50),
                ),
                bottomTitles: const AxisTitles(
                  axisNameWidget: Text(
                    'Итерация',
                    style: TextStyle(fontSize: 11),
                  ),
                  sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              borderData: FlBorderData(show: true),
              lineBarsData: bars,
              lineTouchData: const LineTouchData(enabled: true),
            ),
          ),
        ),
      ],
    );
  }
}
