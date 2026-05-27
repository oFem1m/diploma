import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class ConvergenceLiveChart extends StatelessWidget {
  final List<double?> values;
  final Color color;

  const ConvergenceLiveChart({
    super.key,
    required this.values,
    this.color = Colors.indigo,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) {
      return const Center(child: Text('Ожидание данных...'));
    }

    final bars = <LineChartBarData>[];
    var spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        if (spots.isNotEmpty) {
          bars.add(_bar(spots));
          spots = <FlSpot>[];
        }
        continue;
      }
      spots.add(FlSpot(i.toDouble(), value));
    }
    if (spots.isNotEmpty) {
      bars.add(_bar(spots));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 50),
          ),
          bottomTitles: const AxisTitles(
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
        lineTouchData: const LineTouchData(enabled: false),
      ),
    );
  }

  LineChartBarData _bar(List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color,
      barWidth: 2,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.1),
      ),
    );
  }
}
