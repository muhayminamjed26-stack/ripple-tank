import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../controllers/simulation_controller.dart';
import '../models/wave_source.dart';
import '../utils/constants.dart';
import 'wave_2d_painter.dart';

/// عرض ثلاثي الأبعاد لسطح الموجة: شبكة Mesh بحجم 60×60 يتغير ارتفاعها مع
/// قيمة الموجة، مع إضاءة بسيطة وترتيب المضلعات من الأبعد للأقرب.
/// المصادر والمجسات تُرسم كأعمدة في مواقعها الحقيقية، والعوائق كحواف مرتفعة.
class Wave3DPainter extends CustomPainter {
  Wave3DPainter(this.c) : super(repaint: c.frame);

  final SimulationController c;

  static const int _m = SimDefaults.meshSize;
  static const double _heightScale = 0.16;
  static const double _wallHeight = 0.12;

  // مخازن يُعاد استخدامها بين الإطارات لتقليل الضغط على الذاكرة.
  final Float32List _h = Float32List(_m * _m);
  final Float32List _val = Float32List(_m * _m);
  final Uint8List _kind = Uint8List(_m * _m); // 0 موجة، 1 جدار
  final Float32List _spd = Float32List(_m * _m);
  final Float32List _sx = Float32List(_m * _m);
  final Float32List _sy = Float32List(_m * _m);
  final Float32List _sz = Float32List(_m * _m);
  final Int32List _vc = Int32List(_m * _m);
  final Float32List _depth = Float32List((_m - 1) * (_m - 1));
  final List<int> _order =
      List<int>.generate((_m - 1) * (_m - 1), (i) => i, growable: false);
  final Float32List _pos = Float32List((_m - 1) * (_m - 1) * 12);
  final Int32List _col = Int32List((_m - 1) * (_m - 1) * 6);

  late double _cy, _syaw, _cp, _sp, _dist, _f, _ox, _oy;

  /// إسقاط نقطة من فضاء المشهد إلى الشاشة. يعيد (x, y, depth).
  (double, double, double) _project(double wx, double wy, double wz) {
    final x1 = wx * _cy - wz * _syaw;
    final z1 = wx * _syaw + wz * _cy;
    final y2 = wy * _cp + z1 * _sp;
    final z2 = -wy * _sp + z1 * _cp;
    var w = _dist + z2;
    if (w < 0.1) w = 0.1;
    return (_ox + _f * x1 / w, _oy - _f * y2 / w, z2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [Color(0xFF0B1C38), Color(0xFF02050C)],
        ),
    );

    final e = c.engine;
    final n = e.size;
    final field = e.field;
    final walls = e.walls;
    final speed = e.speedMap;
    final map = WaveColorMap.of(c.scheme);
    final bright = c.brightness;

    _cy = math.cos(c.yaw);
    _syaw = math.sin(c.yaw);
    _cp = math.cos(c.pitch);
    _sp = math.sin(c.pitch);
    _dist = 3.4 / c.zoom;
    _f = size.shortestSide * 1.05;
    _ox = size.width / 2;
    _oy = size.height * 0.56;

    // 1) أخذ عينات من الحقل.
    for (var j = 0; j < _m; j++) {
      final gy = ((j / (_m - 1)) * (n - 1)).round();
      for (var i = 0; i < _m; i++) {
        final gx = ((i / (_m - 1)) * (n - 1)).round();
        final gi = gy * n + gx;
        final k = j * _m + i;
        _spd[k] = speed[gi];
        if (walls[gi] != 0) {
          _kind[k] = 1;
          _h[k] = _wallHeight;
          _val[k] = 0;
        } else {
          _kind[k] = 0;
          var v = field[gi] * bright;
          if (v > 1.5) v = 1.5;
          if (v < -1.5) v = -1.5;
          _val[k] = v;
          _h[k] = v * _heightScale;
        }
      }
    }

    // 2) الإسقاط والإضاءة.
    const step = 2.0 / (_m - 1);
    const lx = 0.35, ly = 0.85, lz = -0.4;
    final ll = math.sqrt(lx * lx + ly * ly + lz * lz);
    final tr = map.tint[0], tg = map.tint[1], tb = map.tint[2];
    for (var j = 0; j < _m; j++) {
      for (var i = 0; i < _m; i++) {
        final k = j * _m + i;
        final wx = (i / (_m - 1) - 0.5) * 2;
        final wz = (0.5 - j / (_m - 1)) * 2;
        final p = _project(wx, _h[k], wz);
        _sx[k] = p.$1;
        _sy[k] = p.$2;
        _sz[k] = p.$3;

        final hl = _h[j * _m + math.max(0, i - 1)];
        final hr = _h[j * _m + math.min(_m - 1, i + 1)];
        final hu = _h[math.max(0, j - 1) * _m + i];
        final hd = _h[math.min(_m - 1, j + 1) * _m + i];
        final nx = -(hr - hl) / (2 * step);
        final nz = (hd - hu) / (2 * step);
        final nl = math.sqrt(nx * nx + 1 + nz * nz);
        final dot = (nx * lx + ly + nz * lz) / (nl * ll);
        final shade = 0.42 + 0.58 * math.max(0.0, dot);

        int r, g, b;
        if (_kind[k] == 1) {
          r = map.wall[0];
          g = map.wall[1];
          b = map.wall[2];
        } else {
          final idx = WaveColorMap.indexOf(_val[k]);
          r = map.r[idx];
          g = map.g[idx];
          b = map.b[idx];
          final sp = _spd[k];
          if (sp < 0.999) {
            final a = 0.22 + 0.4 * (1 - sp);
            r = (r + (tr - r) * a).toInt();
            g = (g + (tg - g) * a).toInt();
            b = (b + (tb - b) * a).toInt();
          }
        }
        r = math.min(255, (r * shade).toInt());
        g = math.min(255, (g * shade).toInt());
        b = math.min(255, (b * shade).toInt());
        _vc[k] = (0xFF << 24) | (r << 16) | (g << 8) | b;
      }
    }

    // 3) ترتيب المربعات من الأبعد للأقرب.
    const q = _m - 1;
    for (var j = 0; j < q; j++) {
      for (var i = 0; i < q; i++) {
        final a = j * _m + i;
        _depth[j * q + i] =
            _sz[a] + _sz[a + 1] + _sz[a + _m] + _sz[a + _m + 1];
      }
    }
    _order.sort((a, b) => _depth[b].compareTo(_depth[a]));

    // 4) بناء المثلثات.
    var pIdx = 0, cIdx = 0;
    void put(int v) {
      _pos[pIdx++] = _sx[v];
      _pos[pIdx++] = _sy[v];
      _col[cIdx++] = _vc[v];
    }

    for (final quad in _order) {
      final j = quad ~/ q;
      final i = quad % q;
      final a = j * _m + i;
      final b = a + 1;
      final cc = a + _m;
      final d = cc + 1;
      put(a);
      put(b);
      put(d);
      put(a);
      put(d);
      put(cc);
    }
    final verts = ui.Vertices.raw(ui.VertexMode.triangles, _pos, colors: _col);
    canvas.drawVertices(verts, BlendMode.dst, Paint());
    verts.dispose();

    // 5) المصادر والمجسات كأعمدة.
    double heightAt(double nx, double ny) => e.isWallAt(nx, ny)
        ? _wallHeight
        : clampD(e.sample(nx, ny) * bright, -1.5, 1.5) * _heightScale;

    Offset scr(double nx, double ny, double y) {
      final p = _project((nx - 0.5) * 2, y, (0.5 - ny) * 2);
      return Offset(p.$1, p.$2);
    }

    for (final s in c.sources) {
      final color = s.enabled ? AppColors.accent : AppColors.muted;
      final pts = s.emitterPoints(n);
      if (s.type == SourceType.line) {
        final a = scr(pts.first.x, pts.first.y, 0.06);
        final b = scr(pts.last.x, pts.last.y, 0.06);
        canvas.drawLine(
            a,
            b,
            Paint()
              ..color = color
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round);
        continue;
      }
      for (final p in pts) {
        final base = heightAt(p.x, p.y);
        _pole(canvas, scr(p.x, p.y, base), scr(p.x, p.y, base + 0.32),
            const Color(0xFFD06BFF), color);
      }
    }
    for (final p in c.probes) {
      final base = heightAt(p.x, p.y);
      _pole(canvas, scr(p.x, p.y, base), scr(p.x, p.y, base + 0.22), p.color,
          p.color);
    }
  }

  void _pole(Canvas canvas, Offset base, Offset top, Color pole, Color glow) {
    canvas.drawLine(
      base,
      top,
      Paint()
        ..color = pole
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      top,
      11,
      Paint()
        ..color = glow.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(top, 5, Paint()..color = glow);
  }

  @override
  bool shouldRepaint(covariant Wave3DPainter old) => old.c != c;
}
