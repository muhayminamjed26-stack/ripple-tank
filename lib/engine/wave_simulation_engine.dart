import 'dart:math' as math;
import 'dart:typed_data';

import '../models/medium_object.dart';
import '../models/obstacle_object.dart';
import '../models/wave_source.dart';
import '../utils/constants.dart';
import 'wave_physics.dart';

/// محرك محاكاة الأمواج — لا يعتمد على Flutter إطلاقاً.
class WaveSimulationEngine {
  WaveSimulationEngine({
    int size = SimDefaults.gridSize,
    double damping = SimDefaults.damping,
    double frequency = SimDefaults.frequency,
    double waveSpeed2 = SimDefaults.waveSpeed2,
  })  : _damping = damping,
        _frequency = frequency,
        _waveSpeed2 = waveSpeed2 {
    _allocate(size);
  }

  late int _n;
  late Float32List _cur;
  late Float32List _prev;
  late Float32List _next;
  late Float32List _c2;
  late Float32List _damp;
  late Float32List _speed;
  late Uint8List _wall;

  double _damping;
  double _frequency;
  double _waveSpeed2;
  double _phase = 0;
  int _steps = 0;

  List<ObstacleObject> _obstacles = const [];
  List<MediumObject> _media = const [];

  int get size => _n;
  Float32List get field => _cur;
  Uint8List get walls => _wall;

  /// معامل السرعة لكل خلية (1 = الوسط الأساسي).
  Float32List get speedMap => _speed;
  int get steps => _steps;

  /// الطور الحالي للمصادر (ω·t).
  double get phase => _phase;

  double get damping => _damping;
  set damping(double v) {
    _damping = clampD(v, 0.9, 1.0);
    _rebuildDamp();
  }

  double get frequency => _frequency;
  set frequency(double v) => _frequency = clampD(v, 0.02, 1.2);

  double get waveSpeed2 => _waveSpeed2;
  set waveSpeed2(double v) {
    _waveSpeed2 = clampD(v, 0.05, SimDefaults.maxWaveSpeed2);
    _rebuildMediumAndWalls();
  }

  /// الطول الموجي النسبي (بالنسبة لعرض الشبكة) في الوسط الأساسي.
  double get wavelength =>
      WavePhysics.wavelengthCells(_waveSpeed2, _frequency) / _n;

  void _allocate(int n) {
    _n = n;
    final len = n * n;
    _cur = Float32List(len);
    _prev = Float32List(len);
    _next = Float32List(len);
    _c2 = Float32List(len);
    _damp = Float32List(len);
    _speed = Float32List(len);
    _wall = Uint8List(len);
    _rebuildMediumAndWalls();
    _rebuildDamp();
  }

  /// تغيير دقة الشبكة مع الحفاظ على العوائق والأوساط.
  void resize(int n) {
    if (n == _n) return;
    _allocate(math.max(40, n));
  }

  void clearWaves() {
    _cur.fillRange(0, _cur.length, 0);
    _prev.fillRange(0, _prev.length, 0);
    _next.fillRange(0, _next.length, 0);
  }

  /// يعيد بناء خرائط الجدران والسرعة بعد إضافة أو تحريك عائق أو وسط.
  void setGeometry(List<ObstacleObject> obstacles, List<MediumObject> media) {
    _obstacles = List<ObstacleObject>.of(obstacles);
    _media = List<MediumObject>.of(media);
    _rebuildMediumAndWalls();
  }

  void _rebuildMediumAndWalls() {
    final n = _n;
    final cell = 1.0 / n;
    for (var y = 0; y < n; y++) {
      final py = (y + 0.5) / n;
      for (var x = 0; x < n; x++) {
        final px = (x + 0.5) / n;
        final i = y * n + x;

        var sf = 1.0;
        for (final m in _media) {
          if (m.contains(px, py)) sf = m.speedFactor;
        }
        _speed[i] = sf;
        var c2 = _waveSpeed2 * sf * sf;
        if (c2 > SimDefaults.maxWaveSpeed2) c2 = SimDefaults.maxWaveSpeed2;
        _c2[i] = c2;

        var w = 0;
        for (final o in _obstacles) {
          if (o.contains(px, py, cell)) {
            w = 1;
            break;
          }
        }
        _wall[i] = w;
        if (w == 1) {
          _cur[i] = 0;
          _prev[i] = 0;
          _next[i] = 0;
        }
      }
    }
  }

  void _rebuildDamp() {
    final n = _n;
    final retention = WavePhysics.retentionPerStep(_damping);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        _damp[y * n + x] = retention * WavePhysics.spongeFactor(x, y, n);
      }
    }
  }

  /// خطوة زمنية واحدة: انتشار الموجة ثم تحديث المصادر.
  void step(List<WaveSource> sources) {
    WavePhysics.propagate(
      cur: _cur,
      prev: _prev,
      next: _next,
      c2: _c2,
      damp: _damp,
      wall: _wall,
      n: _n,
    );
    final t = _prev;
    _prev = _cur;
    _cur = _next;
    _next = t;

    _phase += _frequency;
    const wrap = 2 * math.pi * 1000;
    if (_phase > wrap) _phase -= wrap;
    _steps++;

    _applySources(sources);
  }

  void _applySources(List<WaveSource> sources) {
    final n = _n;
    for (final s in sources) {
      if (!s.enabled) continue;
      s.age++;
      final ramp = math.min(1.0, s.age / SimDefaults.sourceRampSteps);
      final spread = s.type != SourceType.line;
      for (final e in s.emitterPoints(n)) {
        final ix = (e.x * n).floor();
        final iy = (e.y * n).floor();
        if (ix < 2 || iy < 2 || ix > n - 3 || iy > n - 3) continue;
        final i = iy * n + ix;
        if (_wall[i] != 0) continue;
        final v = s.amplitude * ramp * math.sin(_phase + s.phase + e.phaseOffset);
        _cur[i] = v;
        if (spread) {
          // نواة صغيرة بنصف قطر خلية واحدة لموجات دائرية أنعم.
          if (_wall[i - 1] == 0) _cur[i - 1] = v;
          if (_wall[i + 1] == 0) _cur[i + 1] = v;
          if (_wall[i - n] == 0) _cur[i - n] = v;
          if (_wall[i + n] == 0) _cur[i + n] = v;
        }
      }
    }
  }

  /// اضطراب يدوي (أداة Ripple): نتوء غاوسي بسرعة ابتدائية صفرية،
  /// فينتج حلقة تتوسع للخارج.
  void addRipple(double nx, double ny,
      {double strength = 1.5, double radius = 0.02}) {
    final n = _n;
    final r = math.max(1.5, radius * n);
    final cx = nx * n;
    final cy = ny * n;
    final reach = (r * 2.5).ceil();
    final x0 = math.max(1, cx.floor() - reach);
    final x1 = math.min(n - 2, cx.floor() + reach);
    final y0 = math.max(1, cy.floor() - reach);
    final y1 = math.min(n - 2, cy.floor() + reach);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * n + x;
        if (_wall[i] != 0) continue;
        final dx = x + 0.5 - cx;
        final dy = y + 0.5 - cy;
        final g = strength * math.exp(-(dx * dx + dy * dy) / (r * r));
        _cur[i] += g;
        _prev[i] += g;
      }
    }
  }

  double sample(double nx, double ny) =>
      WavePhysics.sampleBilinear(_cur, _n, nx, ny);

  bool isWallAt(double nx, double ny) {
    final x = math.min(_n - 1, math.max(0, (nx * _n).floor()));
    final y = math.min(_n - 1, math.max(0, (ny * _n).floor()));
    return _wall[y * _n + x] != 0;
  }
}
