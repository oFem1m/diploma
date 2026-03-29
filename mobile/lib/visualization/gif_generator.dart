import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'test_functions.dart';
import 'color_maps.dart';


class GifGenerator {
  static Future<Uint8List> generate({
    required String functionName,
    required double xMin,
    required double xMax,
    required double yMin,
    required double yMax,
    required List<double> bestPoint,
    List<List<double>>? population,
    required List<double> historyBestF,
    int dimX = 0,
    int dimY = 1,
    int frameCount = 20,
    int size = 200,
  }) async {
    final fn = getTestFunction(functionName);
    if (fn == null) throw Exception('Unknown function: $functionName');

    final grid = _computeGrid(fn, xMin, xMax, yMin, yMax, size);
    final bgFrame = _renderBackground(grid, size);

    final frames = <img.Image>[];

    final totalIterations = historyBestF.length;
    final step = math.max(1, totalIterations ~/ frameCount);

    for (int f = 0; f < frameCount; f++) {
      final iterIndex = math.min(f * step, totalIterations - 1);
      final progress = (f + 1) / frameCount;

      final frame = img.Image.from(bgFrame);
      frame.frameDuration = 15;

      if (population != null) {
        final visibleCount = (population.length * progress).round().clamp(1, population.length);
        for (int p = 0; p < visibleCount; p++) {
          final point = population[p];
          if (point.length <= math.max(dimX, dimY)) continue;
          final px = _mapCoord(point[dimX], xMin, xMax, size);
          final py = _mapCoord(point[dimY], yMin, yMax, size);
          _drawDot(frame, px, py, 2, img.ColorRgba8(255, 255, 255, 200));
          _drawDotBorder(frame, px, py, 2, img.ColorRgba8(0, 0, 0, 140));
        }
      }

      if (bestPoint.length > math.max(dimX, dimY)) {
        final bx = _mapCoord(bestPoint[dimX], xMin, xMax, size);
        final by = _mapCoord(bestPoint[dimY], yMin, yMax, size);
        final starSize = (3 + progress * 5).round();
        _drawStar(frame, bx, by, starSize, img.ColorRgba8(255, 0, 0, 255));
      }

      _drawInfoBar(frame, iterIndex, historyBestF[iterIndex], size);

      frames.add(frame);
    }

    final lastFrame = img.Image.from(bgFrame);
    lastFrame.frameDuration = 100;

    if (population != null) {
      for (final point in population) {
        if (point.length <= math.max(dimX, dimY)) continue;
        final px = _mapCoord(point[dimX], xMin, xMax, size);
        final py = _mapCoord(point[dimY], yMin, yMax, size);
        _drawDot(lastFrame, px, py, 2, img.ColorRgba8(255, 255, 255, 220));
        _drawDotBorder(lastFrame, px, py, 2, img.ColorRgba8(0, 0, 0, 140));
      }
    }

    if (bestPoint.length > math.max(dimX, dimY)) {
      final bx = _mapCoord(bestPoint[dimX], xMin, xMax, size);
      final by = _mapCoord(bestPoint[dimY], yMin, yMax, size);
      _drawStar(lastFrame, bx, by, 8, img.ColorRgba8(255, 0, 0, 255));
    }

    _drawInfoBar(lastFrame, totalIterations - 1, historyBestF.last, size);
    frames.add(lastFrame);

    final encoder = img.GifEncoder(repeat: 0);
    for (final f in frames) {
      encoder.addFrame(f, duration: f.frameDuration);
    }
    return Uint8List.fromList(encoder.finish()!);
  }

  static _GridData _computeGrid(
      TestFunction fn, double xMin, double xMax, double yMin, double yMax, int res) {
    final values = List.generate(res, (_) => List.filled(res, 0.0));
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (int j = 0; j < res; j++) {
      final y = yMin + (yMax - yMin) * j / (res - 1);
      for (int i = 0; i < res; i++) {
        final x = xMin + (xMax - xMin) * i / (res - 1);
        final val = fn([x, y]);
        values[j][i] = val;
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }
    return _GridData(values, minVal, maxVal);
  }

  static img.Image _renderBackground(_GridData grid, int size) {
    final frame = img.Image(width: size, height: size);
    final range = grid.max - grid.min;

    for (int j = 0; j < size; j++) {
      for (int i = 0; i < size; i++) {
        final val = grid.values[j][i];
        final logT = range > 0
            ? (math.log(val - grid.min + 1) / math.log(range + 1)).clamp(0.0, 1.0)
            : 0.0;
        final c = ColorMaps.viridis(logT);
        final r = (c.r * 255.0).round() & 0xff;
        final g = (c.g * 255.0).round() & 0xff;
        final b = (c.b * 255.0).round() & 0xff;
        frame.setPixelRgba(i, j, r, g, b, 255);
      }
    }
    return frame;
  }

  static int _mapCoord(double val, double min, double max, int size) {
    return ((val - min) / (max - min) * (size - 1)).round().clamp(0, size - 1);
  }

  static void _drawDot(img.Image image, int cx, int cy, int r, img.Color color) {
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        if (dx * dx + dy * dy <= r * r) {
          final px = cx + dx;
          final py = cy + dy;
          if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
            image.setPixel(px, py, color);
          }
        }
      }
    }
  }

  static void _drawDotBorder(img.Image image, int cx, int cy, int r, img.Color color) {
    final r2Inner = (r - 1) * (r - 1);
    final r2Outer = (r + 1) * (r + 1);
    for (int dy = -(r + 1); dy <= r + 1; dy++) {
      for (int dx = -(r + 1); dx <= r + 1; dx++) {
        final d2 = dx * dx + dy * dy;
        if (d2 > r2Inner && d2 <= r2Outer) {
          final px = cx + dx;
          final py = cy + dy;
          if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
            image.setPixel(px, py, color);
          }
        }
      }
    }
  }

  static void _drawStar(img.Image image, int cx, int cy, int r, img.Color color) {
    for (int i = 0; i < 10; i++) {
      final angle1 = math.pi / 2 + i * math.pi / 5;
      final angle2 = math.pi / 2 + (i + 1) * math.pi / 5;
      final r1 = i.isEven ? r.toDouble() : r / 2.5;
      final r2 = (i + 1).isEven ? r.toDouble() : r / 2.5;
      final x1 = cx + r1 * math.cos(angle1);
      final y1 = cy - r1 * math.sin(angle1);
      final x2 = cx + r2 * math.cos(angle2);
      final y2 = cy - r2 * math.sin(angle2);
      _drawLine(image, x1.round(), y1.round(), x2.round(), y2.round(), color);
    }
    _drawDot(image, cx, cy, (r * 0.4).round().clamp(1, r), color);
  }

  static void _drawLine(img.Image image, int x0, int y0, int x1, int y1, img.Color color) {
    int dx = (x1 - x0).abs();
    int dy = (y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1;
    int sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;

    while (true) {
      if (x0 >= 0 && x0 < image.width && y0 >= 0 && y0 < image.height) {
        image.setPixel(x0, y0, color);
      }
      if (x0 == x1 && y0 == y1) break;
      final e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x0 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y0 += sy;
      }
    }
  }

  static void _drawInfoBar(img.Image image, int iteration, double bestF, int size) {
    final barHeight = 16;
    final barColor = img.ColorRgba8(0, 0, 0, 160);
    for (int y = size - barHeight; y < size; y++) {
      for (int x = 0; x < size; x++) {
        image.setPixel(x, y, barColor);
      }
    }
    img.drawString(
      image,
      'It:$iteration f:${bestF.toStringAsExponential(2)}',
      font: img.arial14,
      x: 4,
      y: size - 14,
      color: img.ColorRgba8(255, 255, 255, 255),
    );
  }
}

class _GridData {
  final List<List<double>> values;
  final double min;
  final double max;
  _GridData(this.values, this.min, this.max);
}
