import 'dart:ui' show Rect, Offset;

import '../utils/constants.dart';
import '../utils/geometry.dart';

enum MediumType { rectangle, convexLens, prism }

extension MediumTypeInfo on MediumType {
  String get label => switch (this) {
        MediumType.rectangle => 'وسط مستطيل (Rectangle)',
        MediumType.convexLens => 'عدسة محدبة (Convex Lens)',
        MediumType.prism => 'منشور (Prism)',
      };

  String get shortLabel => switch (this) {
        MediumType.rectangle => 'مستطيل',
        MediumType.convexLens => 'عدسة',
        MediumType.prism => 'منشور',
      };
}

/// وسط شفاف تكون سرعة الموجة فيه = السرعة الأساسية × [speedFactor].
/// معامل الانكسار التقريبي n = 1 / speedFactor.
class MediumObject {
  MediumObject({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    double? width,
    double? height,
    this.angle = 0,
    this.speedFactor = 0.6,
  })  : width = width ?? defaultWidth(type),
        height = height ?? defaultHeight(type);

  final int id;
  MediumType type;
  double x;
  double y;
  double width;
  double height;
  double angle;
  double speedFactor;

  static double defaultWidth(MediumType t) => switch (t) {
        MediumType.rectangle => 0.3,
        MediumType.convexLens => 0.14,
        MediumType.prism => 0.4,
      };

  static double defaultHeight(MediumType t) => switch (t) {
        MediumType.rectangle => 0.3,
        MediumType.convexLens => 0.6,
        MediumType.prism => 0.35,
      };

  double get refractiveIndex => 1 / speedFactor;

  bool contains(double px, double py) {
    final l = toLocal(px, py, x, y, angle);
    return containsLocal(l.x, l.y);
  }

  bool containsLocal(double lx, double ly) {
    final hw = width / 2;
    final hh = height / 2;
    switch (type) {
      case MediumType.rectangle:
        return lx.abs() <= hw && ly.abs() <= hh;
      case MediumType.convexLens:
        final a = lx / hw;
        final b = ly / hh;
        return a * a + b * b <= 1;
      case MediumType.prism:
        // مثلث رأسه للأعلى (y سالب) وقاعدته للأسفل.
        if (ly < -hh || ly > hh) return false;
        final t = (ly + hh) / height; // 0 عند الرأس، 1 عند القاعدة
        return lx.abs() <= hw * t;
    }
  }

  Rect get localBounds =>
      Rect.fromCenter(center: Offset.zero, width: width, height: height);

  bool hitTest(double px, double py, double tolerance) {
    final l = toLocal(px, py, x, y, angle);
    return localBounds.inflate(tolerance).contains(Offset(l.x, l.y));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'angle': angle,
        'speedFactor': speedFactor,
      };

  factory MediumObject.fromJson(Map<String, dynamic> j) {
    final type = MediumType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => MediumType.rectangle,
    );
    return MediumObject(
      id: jsonInt(j['id'], 0),
      type: type,
      x: jsonDouble(j['x'], 0.5),
      y: jsonDouble(j['y'], 0.5),
      width: jsonDouble(j['width'], defaultWidth(type)),
      height: jsonDouble(j['height'], defaultHeight(type)),
      angle: jsonDouble(j['angle'], 0),
      speedFactor: clampD(jsonDouble(j['speedFactor'], 0.6), 0.2, 1.0),
    );
  }
}
