import 'dart:math';
import 'package:flutter/material.dart';
import 'color_maps.dart';

typedef TestFunction3D = double Function(List<double> x);

class _Face {
  final Offset a, b, c, d;
  final double depth;
  final Color color;

  _Face(this.a, this.b, this.c, this.d, this.depth, this.color);
}

class Surface3DPainter extends CustomPainter {
  final TestFunction3D function;
  final double xMin, xMax, yMin, yMax;
  final int resolution;
  final double rotX;
  final double rotZ;
  final int dimX;
  final int dimY;

  final List<List<double>>? historyBestX;

  final List<double>? bestPoint;

  Surface3DPainter({
    required this.function,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    this.resolution = 50,
    this.rotX = -0.6,
    this.rotZ = 0.8,
    this.dimX = 0,
    this.dimY = 1,
    this.historyBestX,
    this.bestPoint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sw = size.width;
    final sh = size.height;
    final cx = sw / 2;
    final cy = sh / 2;
    final scale = min(sw, sh) * 0.38;

    final n = resolution;
    final grid = List.generate(n + 1, (_) => List<double>.filled(n + 1, 0.0));
    double fMin = double.infinity;
    double fMax = double.negativeInfinity;

    for (int i = 0; i <= n; i++) {
      final xVal = xMin + (xMax - xMin) * i / n;
      for (int j = 0; j <= n; j++) {
        final yVal = yMin + (yMax - yMin) * j / n;
        final point = _makePoint(xVal, yVal);
        final f = function(point);
        grid[i][j] = f;
        if (f < fMin) fMin = f;
        if (f > fMax) fMax = f;
      }
    }

    final fRange = fMax - fMin;
    if (fRange == 0) return;

    final cosX = cos(rotX), sinX = sin(rotX);
    final cosZ = cos(rotZ), sinZ = sin(rotZ);

    Offset project(double px, double py, double pz) {
      final nx = 2 * (px - xMin) / (xMax - xMin) - 1;
      final ny = 2 * (py - yMin) / (yMax - yMin) - 1;
      final nz = 2 * (pz - fMin) / fRange - 1;

      final rx = nx * cosZ - ny * sinZ;
      final ry = nx * sinZ + ny * cosZ;
      final rz = nz;

      final ry2 = ry * cosX - rz * sinX;

      return Offset(cx + rx * scale, cy - ry2 * scale);
    }

    double depth(double px, double py, double pz) {
      final nx = 2 * (px - xMin) / (xMax - xMin) - 1;
      final ny = 2 * (py - yMin) / (yMax - yMin) - 1;
      final nz = 2 * (pz - fMin) / fRange - 1;

      final ry = nx * sinZ + ny * cosZ;

      return ry * sinX + nz * cosX;
    }

    final faces = <_Face>[];

    for (int i = 0; i < n; i++) {
      final x0 = xMin + (xMax - xMin) * i / n;
      final x1 = xMin + (xMax - xMin) * (i + 1) / n;
      for (int j = 0; j < n; j++) {
        final y0 = yMin + (yMax - yMin) * j / n;
        final y1 = yMin + (yMax - yMin) * (j + 1) / n;

        final f00 = grid[i][j];
        final f10 = grid[i + 1][j];
        final f11 = grid[i + 1][j + 1];
        final f01 = grid[i][j + 1];

        final a = project(x0, y0, f00);
        final b = project(x1, y0, f10);
        final c = project(x1, y1, f11);
        final d = project(x0, y1, f01);

        final avgF = (f00 + f10 + f11 + f01) / 4;
        final t = _logScale(avgF, fMin, fRange);
        final color = ColorMaps.viridis(t);

        final avgDepth = (depth(x0, y0, f00) + depth(x1, y0, f10) +
                depth(x1, y1, f11) + depth(x0, y1, f01)) /
            4;

        faces.add(_Face(a, b, c, d, avgDepth, color));
      }
    }

    faces.sort((a, b) => a.depth.compareTo(b.depth));

    final paint = Paint()..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3
      ..color = Colors.black26;

    for (final face in faces) {
      final path = Path()
        ..moveTo(face.a.dx, face.a.dy)
        ..lineTo(face.b.dx, face.b.dy)
        ..lineTo(face.c.dx, face.c.dy)
        ..lineTo(face.d.dx, face.d.dy)
        ..close();

      paint.color = face.color;
      canvas.drawPath(path, paint);
      canvas.drawPath(path, edgePaint);
    }

    _drawAxes(canvas, size, project, cx, cy, scale);

    if (historyBestX != null && historyBestX!.isNotEmpty) {
      final pathPaint = Paint()
        ..color = Colors.red.withValues(alpha: 0.9)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final dotPaint = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.fill;

      final path = _samplePath(historyBestX!, 60);

      Offset? prev;
      for (final pt in path) {
        if (pt.length <= max(dimX, dimY)) continue;
        final px = pt[dimX];
        final py = pt[dimY];
        if (px < xMin || px > xMax || py < yMin || py > yMax) continue;
        final fVal = function(_makePoint(px, py));
        final projected = project(px, py, fVal);

        if (prev != null) {
          canvas.drawLine(prev, projected, pathPaint);
        }
        canvas.drawCircle(projected, 3.0, dotPaint);
        prev = projected;
      }
    }

    if (bestPoint != null && bestPoint!.length > max(dimX, dimY)) {
      final bx = bestPoint![dimX];
      final by = bestPoint![dimY];
      if (bx >= xMin && bx <= xMax && by >= yMin && by <= yMax) {
        final fVal = function(_makePoint(bx, by));
        final projected = project(bx, by, fVal);
        _drawStar(canvas, projected, 10, Colors.yellow, Colors.red);
      }
    }
  }

  List<double> _makePoint(double xVal, double yVal) {
    final dims = max(dimX, dimY) + 1;
    final point = List<double>.filled(max(dims, 2), 0.0);
    if (bestPoint != null) {
      for (int i = 0; i < min(bestPoint!.length, point.length); i++) {
        point[i] = bestPoint![i];
      }
    }
    point[dimX] = xVal;
    point[dimY] = yVal;
    return point;
  }

  double _logScale(double val, double fMin, double fRange) {
    final shifted = val - fMin;
    if (fRange <= 0) return 0;
    return log(shifted + 1) / log(fRange + 1);
  }

  List<List<double>> _samplePath(List<List<double>> full, int maxPoints) {
    if (full.length <= maxPoints) return full;
    final step = full.length / maxPoints;
    return List.generate(maxPoints, (i) => full[(i * step).floor()]);
  }

  void _drawAxes(Canvas canvas, Size size, Offset Function(double, double, double) project,
      double cx, double cy, double scale) {
    final tp = TextPainter(textDirection: TextDirection.ltr);

    void drawLabel(String text, Offset pos) {
      tp.text = TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.w600),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    final xEnd = project(xMax, yMin, 0);
    drawLabel('x$dimX', Offset(xEnd.dx, xEnd.dy + 14));

    final yEnd = project(xMin, yMax, 0);
    drawLabel('x$dimY', Offset(yEnd.dx - 14, yEnd.dy));
  }

  void _drawStar(Canvas canvas, Offset center, double r, Color fill, Color stroke) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r / 2.5;
      final angle = -pi / 2 + i * pi / 5;
      final point = Offset(center.dx + radius * cos(angle), center.dy + radius * sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = fill..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant Surface3DPainter old) =>
      old.rotX != rotX || old.rotZ != rotZ || old.resolution != resolution;
}
