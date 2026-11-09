import 'dart:math' as math;

/// نقطة في الإحداثيات المحلية لعنصر مُدار بزاوية.
class LocalPoint {
  const LocalPoint(this.x, this.y);
  final double x;
  final double y;
}

/// يحوّل نقطة من إحداثيات العالم إلى الإحداثيات المحلية لعنصر
/// مركزه (cx, cy) ومُدار بالزاوية [angle].
LocalPoint toLocal(double px, double py, double cx, double cy, double angle) {
  final dx = px - cx;
  final dy = py - cy;
  final c = math.cos(angle);
  final s = math.sin(angle);
  return LocalPoint(dx * c + dy * s, -dx * s + dy * c);
}

/// يحوّل نقطة محلية إلى إحداثيات العالم.
LocalPoint toWorld(double lx, double ly, double cx, double cy, double angle) {
  final c = math.cos(angle);
  final s = math.sin(angle);
  return LocalPoint(cx + lx * c - ly * s, cy + lx * s + ly * c);
}
