import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/wave_probe.dart';
import '../utils/constants.dart';

/// يرسم علامة المجس على مساحة المحاكاة. نصف القطر ينبض مع السعة الحالية.
void paintProbeMarker(Canvas canvas, Offset p, WaveProbe probe,
    {bool selected = false}) {
  final double pulse = 9.0 + 7.0 * math.min(1.0, probe.current.abs());
  canvas.drawCircle(
    p,
    pulse + 6,
    Paint()
      ..color = probe.color.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
  );
  canvas.drawCircle(
    p,
    pulse,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = selected ? 3.2 : 2.2
      ..color = probe.color,
  );
  final cross = Paint()
    ..color = probe.color
    ..strokeWidth = 1.4;
  canvas.drawLine(p + const Offset(-5, 0), p + const Offset(5, 0), cross);
  canvas.drawLine(p + const Offset(0, -5), p + const Offset(0, 5), cross);

  final tp = TextPainter(
    text: TextSpan(
      text: '#${probe.id}',
      style: TextStyle(
        color: probe.color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        shadows: const [Shadow(blurRadius: 3, color: Colors.black)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, p + Offset(pulse + 3, -pulse - 6));
  tp.dispose();
}

/// رسم بياني مباشر لآخر 100 قراءة من المجس.
class ProbeChartPainter extends CustomPainter {
  ProbeChartPainter(this.probe, {required Listenable repaint})
      : super(repaint: repaint);

  final WaveProbe probe;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()..color = AppColors.bg,
    );
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), grid);

    final h = probe.history;
    if (h.length < 2) return;
    final scale = math.max(probe.maxAmplitude, 0.2);
    final dx = size.width / (SimDefaults.probeHistory - 1);
    final startX = size.width - (h.length - 1) * dx;
    final path = Path();
    for (var i = 0; i < h.length; i++) {
      final x = startX + i * dx;
      final y = midY - (h[i] / scale) * (size.height / 2 - 4);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = probe.color,
    );
  }

  @override
  bool shouldRepaint(covariant ProbeChartPainter old) => old.probe != probe;
}
