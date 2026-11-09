import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../controllers/simulation_controller.dart';
import '../models/medium_object.dart';
import '../models/obstacle_object.dart';
import '../models/text_annotation.dart';
import '../models/wave_source.dart';
import '../utils/constants.dart';
import 'probe_painter.dart';

/// طبقة فوق صورة الموجة: توهج المصادر وحلقاتها النابضة، حدود الأوساط،
/// المجسات، النصوص، التحديد، ومعاينة الرسم بالسحب.
///
/// الحلقات النابضة مأخوذة من طور المحرك نفسه وطوله الموجي، فتتطابق مع قمم
/// الموجة الفعلية قرب المصدر ولا تحل محل المحاكاة.
class OverlayPainter extends CustomPainter {
  OverlayPainter(this.c) : super(repaint: c.frame);

  final SimulationController c;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    Offset pt(double x, double y) => Offset(x * s, y * s);

    for (final m in c.media) {
      _drawMedium(canvas, m, s, identical(c.selected, m));
    }
    for (final o in c.obstacles) {
      _drawObstacle(canvas, o, s, identical(c.selected, o));
    }

    final lambdaPx = c.engine.wavelength * s;
    for (final src in c.sources) {
      _drawSource(canvas, src, s, lambdaPx, identical(c.selected, src));
    }

    for (final p in c.probes) {
      paintProbeMarker(canvas, pt(p.x, p.y), p,
          selected: identical(c.selected, p));
    }

    for (final t in c.texts) {
      _drawText(canvas, t, s, identical(c.selected, t));
    }

    _drawDragPreview(canvas, s);
    _drawSignature(canvas, s);
  }

  /// توقيع صاحب التطبيق في زاوية المحاكاة.
  void _drawSignature(Canvas canvas, double s) {
    final tp = TextPainter(
      text: TextSpan(
        text: 'MUHAYMIN',
        style: TextStyle(
          color: AppColors.accent.withValues(alpha: 0.35),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(s - tp.width - 10, s - tp.height - 8));
    tp.dispose();
  }

  void _drawSource(Canvas canvas, WaveSource src, double s, double lambdaPx,
      bool selected) {
    final pts = src.emitterPoints(c.engine.size);
    final color = src.enabled ? AppColors.accent : AppColors.muted;

    if (src.type == SourceType.line) {
      final a = Offset(pts.first.x * s, pts.first.y * s);
      final b = Offset(pts.last.x * s, pts.last.y * s);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = Colors.white
          ..strokeWidth = selected ? 4 : 3
          ..strokeCap = StrokeCap.round,
      );
      if (selected) _selectionRing(canvas, Offset(src.x * s, src.y * s), 14);
      return;
    }

    for (final e in pts) {
      final center = Offset(e.x * s, e.y * s);
      if (src.enabled) {
        // توهج خفيف حول المصدر.
        canvas.drawCircle(
          center,
          28,
          Paint()
            ..shader = ui.Gradient.radial(center, 28, [
              color.withValues(alpha: 0.55),
              color.withValues(alpha: 0.0),
            ]),
        );
        // حلقات متتابعة متزامنة مع قمم الموجة: r = λ·(frac(φ/2π) + k)
        if (lambdaPx > 4) {
          final phi =
              (c.engine.phase + src.phase + e.phaseOffset - math.pi / 2) /
                  (2 * math.pi);
          final frac = phi - phi.floorToDouble();
          for (var k = 0; k < 3; k++) {
            final t = (frac + k) / 3;
            final r = (frac + k) * lambdaPx;
            canvas.drawCircle(
              center,
              r,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.2 * (1 - t) + 0.6
                ..color = color.withValues(
                    alpha: 0.5 * (1 - t) * clampD(src.amplitude, 0.3, 1.0)),
            );
          }
        }
      }
      canvas.drawCircle(center, 5.5, Paint()..color = Colors.white);
      canvas.drawCircle(
        center,
        5.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    }
    if (selected) {
      final r = src.type == SourceType.point ? 14.0 : src.size * s / 2 + 14;
      _selectionRing(canvas, Offset(src.x * s, src.y * s), r);
    }
  }

  void _selectionRing(Canvas canvas, Offset c0, double r) {
    canvas.drawCircle(
      c0,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _drawMedium(Canvas canvas, MediumObject m, double s, bool selected) {
    canvas.save();
    canvas.translate(m.x * s, m.y * s);
    canvas.rotate(m.angle);
    final w = m.width * s, h = m.height * s;
    final path = Path();
    switch (m.type) {
      case MediumType.rectangle:
        path.addRect(Rect.fromCenter(center: Offset.zero, width: w, height: h));
      case MediumType.convexLens:
        path.addOval(Rect.fromCenter(center: Offset.zero, width: w, height: h));
      case MediumType.prism:
        path
          ..moveTo(0, -h / 2)
          ..lineTo(w / 2, h / 2)
          ..lineTo(-w / 2, h / 2)
          ..close();
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.4 : 1.2
        ..color = (selected ? Colors.white : const Color(0xFFB39DFF))
            .withValues(alpha: selected ? 0.95 : 0.6),
    );
    if (selected) _handles(canvas, w, h);
    canvas.restore();
  }

  void _drawObstacle(Canvas canvas, ObstacleObject o, double s, bool selected) {
    if (o.type == ObstacleType.parabolicMirror) {
      final f = o.focusPoint;
      final p = Offset(f.x * s, f.y * s);
      final paint = Paint()
        ..color = const Color(0xFFFFD740)
        ..strokeWidth = 1.6;
      canvas.drawLine(p + const Offset(-6, -6), p + const Offset(6, 6), paint);
      canvas.drawLine(p + const Offset(-6, 6), p + const Offset(6, -6), paint);
    }
    if (!selected) return;
    canvas.save();
    canvas.translate(o.x * s, o.y * s);
    canvas.rotate(o.angle);
    final b = o.localBounds;
    final r = Rect.fromLTRB(b.left * s, b.top * s, b.right * s, b.bottom * s)
        .inflate(5);
    canvas.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.restore();
  }

  void _handles(Canvas canvas, double w, double h) {
    final p = Paint()..color = Colors.white;
    for (final o in [
      Offset(-w / 2, -h / 2),
      Offset(w / 2, -h / 2),
      Offset(-w / 2, h / 2),
      Offset(w / 2, h / 2),
    ]) {
      canvas.drawRect(Rect.fromCenter(center: o, width: 7, height: 7), p);
    }
  }

  void _drawText(Canvas canvas, TextAnnotation t, double s, bool selected) {
    final tp = TextPainter(
      text: TextSpan(
        text: t.text,
        style: TextStyle(
          color: Colors.white,
          fontSize: t.fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: s * 0.6);
    final center = Offset(t.x * s, t.y * s);
    final box = Rect.fromCenter(
      center: center,
      width: tp.width + 16,
      height: tp.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(8)),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(8)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.accent,
      );
    }
    tp.paint(canvas, Offset(box.left + 8, box.top + 4));
    tp.dispose();
  }

  void _drawDragPreview(Canvas canvas, double s) {
    final a = c.dragStart, b = c.dragEnd;
    if (a == null || b == null) return;
    final pa = Offset(a.dx * s, a.dy * s), pb = Offset(b.dx * s, b.dy * s);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.accent;
    final isLine = c.tool == ToolMode.drawWall &&
        c.pendingObstacleType != ObstacleType.box;
    if (isLine) {
      canvas.drawLine(pa, pb, paint..strokeWidth = 4);
    } else {
      canvas.drawRect(Rect.fromPoints(pa, pb), paint);
    }
  }

  @override
  bool shouldRepaint(covariant OverlayPainter old) => old.c != c;
}
