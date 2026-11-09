import 'dart:ui' show Color;

import '../utils/constants.dart';

/// مجس لقياس سعة الموجة عند نقطة.
class WaveProbe {
  WaveProbe({
    required this.id,
    required this.x,
    required this.y,
    required this.color,
  });

  final int id;
  double x;
  double y;
  Color color;

  /// آخر [SimDefaults.probeHistory] قراءة.
  final List<double> history = <double>[];
  double current = 0;
  double maxAmplitude = 0;

  void record(double value) {
    current = value;
    final a = value.abs();
    if (a > maxAmplitude) maxAmplitude = a;
    history.add(value);
    if (history.length > SimDefaults.probeHistory) history.removeAt(0);
  }

  void reset() {
    history.clear();
    current = 0;
    maxAmplitude = 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'color': color.toARGB32(),
      };

  factory WaveProbe.fromJson(Map<String, dynamic> j) => WaveProbe(
        id: jsonInt(j['id'], 0),
        x: jsonDouble(j['x'], 0.5),
        y: jsonDouble(j['y'], 0.5),
        color: Color(jsonInt(j['color'], kProbeColors.first.toARGB32())),
      );
}
