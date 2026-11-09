import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/wave_simulation_engine.dart';
import '../utils/constants.dart';

/// جدول ألوان (LUT) بـ 256 درجة لكل نظام ألوان: من القاع (0) إلى القمة (255).
class WaveColorMap {
  WaveColorMap._({
    required this.r,
    required this.g,
    required this.b,
    required this.wall,
    required this.tint,
    required this.background,
  });

  final Uint8List r;
  final Uint8List g;
  final Uint8List b;
  final List<int> wall; // [r, g, b]
  final List<int> tint; // لون الأوساط
  final Color background;

  static final Map<ColorSchemeType, WaveColorMap> _cache = {};

  static WaveColorMap of(ColorSchemeType t) =>
      _cache.putIfAbsent(t, () => _build(t));

  static WaveColorMap _build(ColorSchemeType t) {
    late List<int> bg, posMid, posPeak, negMid, negPeak, wall, tint;
    switch (t) {
      case ColorSchemeType.cyan:
        bg = [5, 16, 30];
        posMid = [0, 196, 230];
        posPeak = [215, 255, 255];
        negMid = [14, 48, 135];
        negPeak = [2, 5, 26];
        wall = [210, 225, 242];
        tint = [150, 95, 255];
      case ColorSchemeType.green:
        bg = [6, 24, 14];
        posMid = [0, 205, 105];
        posPeak = [205, 255, 215];
        negMid = [3, 12, 7];
        negPeak = [0, 0, 0];
        wall = [236, 242, 230];
        tint = [255, 190, 60];
      case ColorSchemeType.highContrast:
        bg = [110, 110, 110];
        posMid = [222, 222, 222];
        posPeak = [255, 255, 255];
        negMid = [40, 40, 40];
        negPeak = [0, 0, 0];
        wall = [255, 214, 0];
        tint = [0, 140, 255];
    }
    final r = Uint8List(256), g = Uint8List(256), b = Uint8List(256);
    List<int> lerp(List<int> a, List<int> c, double k) => [
          (a[0] + (c[0] - a[0]) * k).round(),
          (a[1] + (c[1] - a[1]) * k).round(),
          (a[2] + (c[2] - a[2]) * k).round(),
        ];
    for (var i = 0; i < 256; i++) {
      final v = i / 127.5 - 1.0;
      final a = v.abs();
      final mid = v >= 0 ? posMid : negMid;
      final peak = v >= 0 ? posPeak : negPeak;
      final col = a < 0.6 ? lerp(bg, mid, a / 0.6) : lerp(mid, peak, (a - 0.6) / 0.4);
      r[i] = col[0];
      g[i] = col[1];
      b[i] = col[2];
    }
    return WaveColorMap._(
      r: r,
      g: g,
      b: b,
      wall: wall,
      tint: tint,
      background: Color.fromARGB(255, bg[0], bg[1], bg[2]),
    );
  }

  /// فهرس الجدول لقيمة موجة مضروبة بالسطوع.
  static int indexOf(double v) {
    if (v > 1) v = 1;
    if (v < -1) v = -1;
    return ((v + 1) * 127.5).toInt();
  }
}

/// يحوّل حقل الموجة إلى صورة. يمنع تراكم عمليات التوليد: إذا كانت صورة
/// قيد التوليد يرفض الطلب الجديد ويعيد false، فيُعاد المحاولة في الإطار التالي.
class WaveImageRenderer {
  WaveImageRenderer({required this.onImage});

  final VoidCallback onImage;
  ui.Image? _image;
  Uint8List? _pixels;
  bool _busy = false;
  bool _disposed = false;

  ui.Image? get image => _image;

  bool render(WaveSimulationEngine e, ColorSchemeType scheme, double brightness) {
    if (_busy || _disposed) return false;
    _busy = true;

    final n = e.size;
    final len = n * n;
    var px = _pixels;
    if (px == null || px.length != len * 4) {
      px = Uint8List(len * 4);
      _pixels = px;
    }
    final map = WaveColorMap.of(scheme);
    final f = e.field;
    final w = e.walls;
    final sp = e.speedMap;
    final wr = map.wall[0], wg = map.wall[1], wb = map.wall[2];
    final tr = map.tint[0], tg = map.tint[1], tb = map.tint[2];

    for (var i = 0; i < len; i++) {
      final o = i * 4;
      if (w[i] != 0) {
        px[o] = wr;
        px[o + 1] = wg;
        px[o + 2] = wb;
        px[o + 3] = 255;
        continue;
      }
      final k = WaveColorMap.indexOf(f[i] * brightness);
      var r = map.r[k], g = map.g[k], b = map.b[k];
      final s = sp[i];
      if (s < 0.999) {
        final a = 0.22 + 0.4 * (1 - s);
        r = (r + (tr - r) * a).toInt();
        g = (g + (tg - g) * a).toInt();
        b = (b + (tb - b) * a).toInt();
      }
      px[o] = r;
      px[o + 1] = g;
      px[o + 2] = b;
      px[o + 3] = 255;
    }

    ui.decodeImageFromPixels(px, n, n, ui.PixelFormat.rgba8888, (img) {
      if (_disposed) {
        img.dispose();
        return;
      }
      _image?.dispose();
      _image = img;
      _busy = false;
      onImage();
    });
    return true;
  }

  void dispose() {
    _disposed = true;
    _image?.dispose();
    _image = null;
  }
}

/// يرسم صورة الموجة ثنائية الأبعاد مكبّرة بتنعيم.
class Wave2DPainter extends CustomPainter {
  Wave2DPainter({
    required this.renderer,
    required this.background,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final WaveImageRenderer renderer;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    final img = renderer.image;
    if (img == null) {
      canvas.drawRect(dst, Paint()..color = background);
      return;
    }
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant Wave2DPainter old) =>
      old.renderer != renderer || old.background != background;
}
