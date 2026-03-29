import 'dart:ui';

class ColorMaps {
  static const _viridis = [
    Color(0xFF440154),
    Color(0xFF482777),
    Color(0xFF3E4A89),
    Color(0xFF31688E),
    Color(0xFF26838E),
    Color(0xFF1F9E89),
    Color(0xFF35B779),
    Color(0xFF6DCD59),
    Color(0xFFB4DE2C),
    Color(0xFFFDE725),
  ];

  static Color viridis(double t) {
    final clamped = t.clamp(0.0, 1.0);
    final idx = clamped * (_viridis.length - 1);
    final lo = idx.floor();
    final hi = idx.ceil();
    if (lo == hi) return _viridis[lo];
    final frac = idx - lo;
    return Color.lerp(_viridis[lo], _viridis[hi], frac)!;
  }
}
