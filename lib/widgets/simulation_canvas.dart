import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../controllers/simulation_controller.dart';
import '../rendering/overlay_painter.dart';
import '../rendering/wave_2d_painter.dart';
import '../rendering/wave_3d_painter.dart';
import '../utils/constants.dart';

/// مساحة المحاكاة: تشغّل حلقة الإطارات (Ticker) وتستقبل اللمس.
class SimulationCanvas extends StatefulWidget {
  const SimulationCanvas({super.key, required this.controller});

  final SimulationController controller;

  @override
  State<SimulationCanvas> createState() => _SimulationCanvasState();
}

class _SimulationCanvasState extends State<SimulationCanvas>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _startZoom = 1;

  SimulationController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    c.tick(dt);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Offset _norm(Offset local, double side) => Offset(
        clampD(local.dx / side, 0, 1),
        clampD(local.dy / side, 0, 1),
      );

  Future<void> _onTap(Offset local, double side) async {
    final p = _norm(local, side);
    if (c.tool == ToolMode.addText) {
      final text = await showTextInputDialog(context, title: 'إضافة ملاحظة نصية');
      if (text != null && text.trim().isNotEmpty) {
        c.addText(p.dx, p.dy, text.trim());
      }
      return;
    }
    c.tap(p.dx, p.dy);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => LayoutBuilder(
        builder: (context, cons) {
          final side = math.max(
              50.0, math.min(cons.maxWidth, cons.maxHeight) - 8);
          return Center(
            child: Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.10),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: c.is3D ? _build3D(side) : _build2D(side),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _build2D(double side) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (d) => _onTap(d.localPosition, side),
      onPanStart: (d) {
        final p = _norm(d.localPosition, side);
        c.panStart(p.dx, p.dy);
      },
      onPanUpdate: (d) {
        final p = _norm(d.localPosition, side);
        c.panUpdate(p.dx, p.dy, d.delta.dx / side, d.delta.dy / side);
      },
      onPanEnd: (_) => c.panEnd(),
      onPanCancel: c.panEnd,
      child: CustomPaint(
        size: Size.square(side),
        painter: Wave2DPainter(
          renderer: c.renderer,
          background: WaveColorMap.of(c.scheme).background,
          repaint: c.frame,
        ),
        foregroundPainter: OverlayPainter(c),
      ),
    );
  }

  Widget _build3D(double side) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (_) => _startZoom = c.zoom,
      onScaleUpdate: (d) {
        if (d.pointerCount >= 2) {
          c.setZoom(_startZoom * d.scale);
        } else {
          c.rotate3D(d.focalPointDelta.dx, d.focalPointDelta.dy);
        }
      },
      onDoubleTap: c.resetView,
      child: Stack(
        children: [
          CustomPaint(size: Size.square(side), painter: Wave3DPainter(c)),
          const Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Text(
              'اسحب للتدوير • إصبعان للتكبير • نقرتان لإعادة الزاوية',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

/// نافذة إدخال نص بسيطة.
Future<String?> showTextInputDialog(BuildContext context,
    {required String title, String initial = '', String hint = 'اكتب هنا'}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text),
          child: const Text('موافق'),
        ),
      ],
    ),
  );
}
