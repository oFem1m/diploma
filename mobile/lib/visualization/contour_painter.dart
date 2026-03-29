import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'test_functions.dart';
import 'color_maps.dart';

class ContourPainter extends CustomPainter {
  final TestFunction function;
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
  final List<List<double>>? population;
  final List<double>? bestPoint;
  final int resolution;
  final int dimX;
  final int dimY;

  ContourPainter({
    required this.function,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    this.population,
    this.bestPoint,
    this.resolution = 80,
    this.dimX = 0,
    this.dimY = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final grid = _computeGrid();
    final minVal = grid.min;
    final maxVal = grid.max;
    final range = maxVal - minVal;

    final cellW = size.width / resolution;
    final cellH = size.height / resolution;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int j = 0; j < resolution; j++) {
      for (int i = 0; i < resolution; i++) {
        final val = grid.values[j][i];
        final logT = range > 0 ? (math.log(val - minVal + 1) / math.log(range + 1)).clamp(0.0, 1.0) : 0.0;
        paint.color = ColorMaps.viridis(logT);
        canvas.drawRect(
          Rect.fromLTWH(i * cellW, j * cellH, cellW + 0.5, cellH + 0.5),
          paint,
        );
      }
    }

    if (population != null) {
      final dotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;
      final borderPaint = Paint()
        ..color = Colors.black54
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      for (final p in population!) {
        if (p.length <= math.max(dimX, dimY)) continue;
        final px = _mapX(p[dimX], size.width);
        final py = _mapY(p[dimY], size.height);
        canvas.drawCircle(Offset(px, py), 3, dotPaint);
        canvas.drawCircle(Offset(px, py), 3, borderPaint);
      }
    }

    if (bestPoint != null && bestPoint!.length > math.max(dimX, dimY)) {
      final bx = _mapX(bestPoint![dimX], size.width);
      final by = _mapY(bestPoint![dimY], size.height);
      _drawStar(canvas, Offset(bx, by), 8, Colors.red);
    }
  }

  double _mapX(double val, double width) {
    return ((val - xMin) / (xMax - xMin) * width).clamp(0, width);
  }

  double _mapY(double val, double height) {
    return ((val - yMin) / (yMax - yMin) * height).clamp(0, height);
  }

  void _drawStar(Canvas canvas, Offset center, double r, Color color) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final angle = math.pi / 2 + i * math.pi / 5;
      final radius = i.isEven ? r : r / 2.5;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy - radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  _GridData _computeGrid() {
    final values = List.generate(resolution, (_) => List.filled(resolution, 0.0));
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int j = 0; j < resolution; j++) {
      final y = yMin + (yMax - yMin) * j / (resolution - 1);
      for (int i = 0; i < resolution; i++) {
        final x = xMin + (xMax - xMin) * i / (resolution - 1);
        final val = function([x, y]);
        values[j][i] = val;
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }
    return _GridData(values, minVal, maxVal);
  }

  @override
  bool shouldRepaint(ContourPainter oldDelegate) => true;
}

class _GridData {
  final List<List<double>> values;
  final double min;
  final double max;
  _GridData(this.values, this.min, this.max);
}
