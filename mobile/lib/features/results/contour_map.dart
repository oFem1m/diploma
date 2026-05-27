import 'package:flutter/material.dart';
import '../../visualization/contour_painter.dart';
import '../../visualization/expression_function.dart';
import '../../visualization/test_functions.dart';

class ContourMapWidget extends StatelessWidget {
  final String functionName;
  final String? expression;
  final int dims;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final List<List<double>>? population;
  final List<double>? bestPoint;
  final int dimX;
  final int dimY;

  const ContourMapWidget({
    super.key,
    required this.functionName,
    this.expression,
    this.dims = 2,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    this.population,
    this.bestPoint,
    this.dimX = 0,
    this.dimY = 1,
  });

  @override
  Widget build(BuildContext context) {
    final TestFunction? fn;
    try {
      fn = expression != null && expression!.trim().isNotEmpty
          ? compileExpressionFunction(expression!, dims)
          : getTestFunction(functionName);
    } catch (_) {
      return const Center(child: Text('Не удалось разобрать выражение'));
    }
    if (fn == null) {
      return const Center(child: Text('Неизвестная функция'));
    }

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: ContourPainter(
            function: fn,
            xMin: xMin,
            xMax: xMax,
            yMin: yMin,
            yMax: yMax,
            population: population,
            bestPoint: bestPoint,
            dimX: dimX,
            dimY: dimY,
            dims: dims,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
