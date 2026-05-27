import 'dart:math';
import 'package:flutter/material.dart';
import '../../visualization/expression_function.dart';
import '../../visualization/surface_3d_painter.dart';
import '../../visualization/test_functions.dart';

class Surface3DScreen extends StatefulWidget {
  final String functionName;
  final String? expression;
  final double xMin, xMax, yMin, yMax;
  final List<List<double>>? historyBestX;
  final List<double>? bestPoint;
  final int dimX;
  final int dimY;
  final int dims;

  const Surface3DScreen({
    super.key,
    required this.functionName,
    this.expression,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    this.historyBestX,
    this.bestPoint,
    this.dimX = 0,
    this.dimY = 1,
    this.dims = 2,
  });

  @override
  State<Surface3DScreen> createState() => _Surface3DScreenState();
}

class _Surface3DScreenState extends State<Surface3DScreen> {
  double _rotX = -0.6;
  double _rotZ = 0.8;
  int _resolution = 50;
  int _projX = 0;
  int _projY = 1;

  @override
  void initState() {
    super.initState();
    _projX = widget.dimX;
    _projY = widget.dimY;
  }

  @override
  Widget build(BuildContext context) {
    final TestFunction? fn;
    try {
      fn = widget.expression != null && widget.expression!.trim().isNotEmpty
          ? compileExpressionFunction(widget.expression!, widget.dims)
          : getTestFunction(widget.functionName);
    } catch (_) {
      return Scaffold(
        appBar: AppBar(title: const Text('3D-визуализация')),
        body: const Center(child: Text('Не удалось разобрать выражение')),
      );
    }
    if (fn == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('3D-визуализация')),
        body: const Center(child: Text('Неизвестная функция')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('3D-визуализация'),
        actions: [
          PopupMenuButton<int>(
            icon: const Icon(Icons.grid_on),
            tooltip: 'Разрешение сетки',
            onSelected: (v) => setState(() => _resolution = v),
            itemBuilder: (_) => [
              for (final r in [25, 40, 50, 70, 90])
                PopupMenuItem(
                  value: r,
                  child: Row(
                    children: [
                      if (r == _resolution)
                        const Icon(Icons.check, size: 18)
                      else
                        const SizedBox(width: 18),
                      const SizedBox(width: 8),
                      Text('$r x $r'),
                    ],
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Сбросить поворот',
            onPressed: () => setState(() {
              _rotX = -0.6;
              _rotZ = 0.8;
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.dims > 2)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('3d_projX_$_projX'),
                      initialValue: _projX,
                      decoration: const InputDecoration(
                        labelText: 'Ось X',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: List.generate(
                        widget.dims,
                        (i) => DropdownMenuItem(value: i, child: Text('x$i')),
                      ),
                      onChanged: (v) => setState(() => _projX = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: ValueKey('3d_projY_$_projY'),
                      initialValue: _projY,
                      decoration: const InputDecoration(
                        labelText: 'Ось Y',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: List.generate(
                        widget.dims,
                        (i) => DropdownMenuItem(value: i, child: Text('x$i')),
                      ),
                      onChanged: (v) => setState(() => _projY = v!),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                _LegendDot(color: Colors.red, label: 'Путь лучших решений'),
                const SizedBox(width: 16),
                _LegendDot(
                  color: Colors.yellow,
                  label: 'Лучшее решение',
                  isStar: true,
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _rotZ += details.delta.dx * 0.008;
                    _rotX += details.delta.dy * 0.008;
                    _rotX = _rotX.clamp(-pi / 2 + 0.05, 0.05);
                  });
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: CustomPaint(
                      painter: Surface3DPainter(
                        function: fn,
                        xMin: widget.xMin,
                        xMax: widget.xMax,
                        yMin: widget.yMin,
                        yMax: widget.yMax,
                        resolution: _resolution,
                        rotX: _rotX,
                        rotZ: _rotZ,
                        dimX: _projX,
                        dimY: _projY,
                        historyBestX: widget.historyBestX,
                        bestPoint: widget.bestPoint,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Проведите пальцем для вращения',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool isStar;

  const _LegendDot({
    required this.color,
    required this.label,
    this.isStar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isStar)
          Icon(Icons.star, color: color, size: 14)
        else
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
