import 'dart:math' as math;

import '../utils/constants.dart';

enum SourceType { point, line, pair, multipole }

extension SourceTypeInfo on SourceType {
  String get label => switch (this) {
        SourceType.point => 'مصدر نقطي (Point)',
        SourceType.line => 'مصدر خطي (Line)',
        SourceType.pair => 'مصدر مزدوج (Double)',
        SourceType.multipole => 'متعدد الأقطاب (Multipole)',
      };

  String get shortLabel => switch (this) {
        SourceType.point => 'نقطي',
        SourceType.line => 'خطي',
        SourceType.pair => 'مزدوج',
        SourceType.multipole => 'متعدد',
      };
}

/// نقطة إصدار واحدة تابعة لمصدر، مع إزاحة طور خاصة بها.
class EmitterPoint {
  const EmitterPoint(this.x, this.y, this.phaseOffset);
  final double x;
  final double y;
  final double phaseOffset;
}

/// مصدر أمواج. الإحداثيات والأحجام كلها نسبية (0..1) حتى لا تتأثر بدقة الشبكة.
class WaveSource {
  WaveSource({
    required this.id,
    this.type = SourceType.point,
    required this.x,
    required this.y,
    this.angle = 0,
    double? size,
    this.poles = 4,
    this.amplitude = 1.0,
    this.phase = 0,
    this.enabled = true,
  }) : size = size ?? defaultSize(type);

  final int id;
  SourceType type;
  double x;
  double y;

  /// زاوية الاتجاه (للخطي: اتجاه الخط، للمزدوج: محور المصدرين).
  double angle;

  /// طول الخط أو المسافة بين المصدرين أو قطر المتعدد.
  double size;
  int poles;
  double amplitude;
  double phase;
  bool enabled;

  /// عدد الخطوات منذ بدء الإصدار (للبداية الناعمة) — لا يُحفظ.
  int age = 0;

  static double defaultSize(SourceType type) => switch (type) {
        SourceType.point => 0.0,
        SourceType.line => 0.5,
        SourceType.pair => 0.16,
        SourceType.multipole => 0.08,
      };

  /// نقاط الإصدار الفعلية على شبكة بحجم [gridSize].
  List<EmitterPoint> emitterPoints(int gridSize) {
    final dx = math.cos(angle);
    final dy = math.sin(angle);
    switch (type) {
      case SourceType.point:
        return [EmitterPoint(x, y, 0)];
      case SourceType.pair:
        final h = size / 2;
        return [
          EmitterPoint(x - dx * h, y - dy * h, 0),
          EmitterPoint(x + dx * h, y + dy * h, 0),
        ];
      case SourceType.multipole:
        final count = math.min(8, math.max(2, poles));
        final r = size / 2;
        return List<EmitterPoint>.generate(count, (j) {
          final a = angle + 2 * math.pi * j / count;
          final double off = count.isEven
              ? (j.isOdd ? math.pi : 0.0)
              : 2 * math.pi * j / count;
          return EmitterPoint(x + math.cos(a) * r, y + math.sin(a) * r, off);
        });
      case SourceType.line:
        final count = math.max(2, (size * gridSize * 2).ceil());
        return List<EmitterPoint>.generate(count + 1, (j) {
          final t = -size / 2 + size * j / count;
          return EmitterPoint(x + dx * t, y + dy * t, 0);
        });
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'angle': angle,
        'size': size,
        'poles': poles,
        'amplitude': amplitude,
        'phase': phase,
        'enabled': enabled,
      };

  factory WaveSource.fromJson(Map<String, dynamic> j) {
    final type = SourceType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => SourceType.point,
    );
    return WaveSource(
      id: jsonInt(j['id'], 0),
      type: type,
      x: jsonDouble(j['x'], 0.5),
      y: jsonDouble(j['y'], 0.5),
      angle: jsonDouble(j['angle'], 0),
      size: jsonDouble(j['size'], defaultSize(type)),
      poles: jsonInt(j['poles'], 4),
      amplitude: jsonDouble(j['amplitude'], 1),
      phase: jsonDouble(j['phase'], 0),
      enabled: jsonBool(j['enabled'], true),
    );
  }
}
