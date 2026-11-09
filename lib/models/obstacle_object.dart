import 'dart:math' as math;
import 'dart:ui' show Rect, Offset;

import '../utils/constants.dart';
import '../utils/geometry.dart';

enum ObstacleType { box, wall, singleSlit, doubleSlit, parabolicMirror }

extension ObstacleTypeInfo on ObstacleType {
  String get label => switch (this) {
        ObstacleType.box => 'صندوق صلب (Solid Box)',
        ObstacleType.wall => 'جدار (Wall)',
        ObstacleType.singleSlit => 'شق مفرد (Single Slit)',
        ObstacleType.doubleSlit => 'شق مزدوج (Double Slit)',
        ObstacleType.parabolicMirror => 'مرآة مكافئة (Parabolic Mirror)',
      };

  String get shortLabel => switch (this) {
        ObstacleType.box => 'صندوق',
        ObstacleType.wall => 'جدار',
        ObstacleType.singleSlit => 'شق مفرد',
        ObstacleType.doubleSlit => 'شق مزدوج',
        ObstacleType.parabolicMirror => 'مرآة',
      };

  /// هل يُرسم بالسحب كخط (الطول والزاوية من اتجاه السحب)؟
  bool get isLinear => this != ObstacleType.box;
}

/// عائق صلب يعكس الأمواج (شرط حدّي u = 0).
/// الإحداثيات المحلية: المحور x على طول العائق، والمحور y عمودي عليه.
class ObstacleObject {
  ObstacleObject({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    double? width,
    double? height,
    this.angle = 0,
    this.slitWidth = 0.04,
    this.slitSeparation = 0.14,
    this.focal = 0.16,
  })  : width = width ?? defaultWidth(type),
        height = height ?? defaultHeight(type);

  final int id;
  ObstacleType type;
  double x;
  double y;

  /// الطول على المحور المحلي x.
  double width;

  /// السُمك (أو ارتفاع الصندوق).
  double height;
  double angle;
  double slitWidth;
  double slitSeparation;
  double focal;

  static double defaultWidth(ObstacleType t) => switch (t) {
        ObstacleType.box => 0.16,
        ObstacleType.wall => 0.5,
        ObstacleType.singleSlit => 1.0,
        ObstacleType.doubleSlit => 1.0,
        ObstacleType.parabolicMirror => 0.6,
      };

  static double defaultHeight(ObstacleType t) =>
      t == ObstacleType.box ? 0.16 : 0.014;

  bool contains(double px, double py, double cell) {
    final l = toLocal(px, py, x, y, angle);
    return containsLocal(l.x, l.y, cell);
  }

  /// [cell] حجم خلية الشبكة، ويُستخدم لضمان سُمك أدنى يمنع تسرّب الموجة.
  bool containsLocal(double lx, double ly, double cell) {
    if (lx.abs() > width / 2) return false;
    final halfT = math.max(height / 2, cell * 1.25);
    switch (type) {
      case ObstacleType.box:
        return ly.abs() <= math.max(height / 2, cell);
      case ObstacleType.wall:
        return ly.abs() <= halfT;
      case ObstacleType.singleSlit:
        if (ly.abs() > halfT) return false;
        return lx.abs() >= slitWidth / 2;
      case ObstacleType.doubleSlit:
        if (ly.abs() > halfT) return false;
        return (lx.abs() - slitSeparation / 2).abs() >= slitWidth / 2;
      case ObstacleType.parabolicMirror:
        final f = math.max(focal, 0.02);
        final curve = lx * lx / (4 * f);
        final slope = lx / (2 * f);
        final tol = halfT * math.sqrt(1 + slope * slope);
        return (ly - curve).abs() <= tol;
    }
  }

  /// حدود العنصر في الإحداثيات المحلية.
  Rect get localBounds {
    if (type == ObstacleType.parabolicMirror) {
      final f = math.max(focal, 0.02);
      final depth = (width / 2) * (width / 2) / (4 * f);
      return Rect.fromLTRB(
          -width / 2, -height / 2, width / 2, depth + height / 2);
    }
    final h = math.max(height, 0.012);
    return Rect.fromCenter(center: Offset.zero, width: width, height: h);
  }

  /// بؤرة المرآة المكافئة في إحداثيات العالم.
  LocalPoint get focusPoint => toWorld(0, math.max(focal, 0.02), x, y, angle);

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
        'slitWidth': slitWidth,
        'slitSeparation': slitSeparation,
        'focal': focal,
      };

  factory ObstacleObject.fromJson(Map<String, dynamic> j) {
    final type = ObstacleType.values.firstWhere(
      (t) => t.name == j['type'],
      orElse: () => ObstacleType.wall,
    );
    return ObstacleObject(
      id: jsonInt(j['id'], 0),
      type: type,
      x: jsonDouble(j['x'], 0.5),
      y: jsonDouble(j['y'], 0.5),
      width: jsonDouble(j['width'], defaultWidth(type)),
      height: jsonDouble(j['height'], defaultHeight(type)),
      angle: jsonDouble(j['angle'], 0),
      slitWidth: jsonDouble(j['slitWidth'], 0.04),
      slitSeparation: jsonDouble(j['slitSeparation'], 0.14),
      focal: jsonDouble(j['focal'], 0.16),
    );
  }
}
