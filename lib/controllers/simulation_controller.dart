import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/wave_simulation_engine.dart';
import '../models/medium_object.dart';
import '../models/obstacle_object.dart';
import '../models/text_annotation.dart';
import '../models/wave_probe.dart';
import '../models/wave_source.dart';
import '../rendering/wave_2d_painter.dart';
import '../utils/constants.dart';
import '../utils/geometry.dart';

enum ToolMode { move, ripple, addSource, drawWall, drawMedium, addProbe, addText }

extension ToolModeInfo on ToolMode {
  String get label => switch (this) {
        ToolMode.move => 'تحريك',
        ToolMode.ripple => 'تموّج',
        ToolMode.addSource => 'مصدر',
        ToolMode.drawWall => 'عائق',
        ToolMode.drawMedium => 'وسط',
        ToolMode.addProbe => 'مجس',
        ToolMode.addText => 'نص',
      };

  String get hint => switch (this) {
        ToolMode.move => 'المس عنصراً لتحديده واسحبه لتحريكه',
        ToolMode.ripple => 'المس أو اسحب لإحداث اضطراب موجي',
        ToolMode.addSource => 'المس مكاناً لإضافة مصدر',
        ToolMode.drawWall => 'اسحب لرسم العائق أو المس لإضافته بحجم افتراضي',
        ToolMode.drawMedium => 'اسحب لرسم الوسط أو المس لإضافته بحجم افتراضي',
        ToolMode.addProbe => 'المس مكاناً لإضافة مجس قياس',
        ToolMode.addText => 'المس مكاناً لإضافة ملاحظة نصية',
      };
}

enum Preset { doubleSlit, convexLens, prism, parabolicMirror }

extension PresetInfo on Preset {
  String get label => switch (this) {
        Preset.doubleSlit => 'تجربة الشق المزدوج (Double Slit)',
        Preset.convexLens => 'تجربة العدسة المحدبة (Convex Lens)',
        Preset.prism => 'انكسار المنشور (Prism Refraction)',
        Preset.parabolicMirror => 'المرآة المكافئة (Parabolic Mirror)',
      };
}

/// يربط المحرك بالواجهة: يملك المشهد والإعدادات والأدوات.
/// يُستدعى notifyListeners فقط عند تغيّر بنيوي، أما الإطارات فتُبلَّغ عبر [frame]
/// حتى لا يُعاد بناء الواجهة كاملة في كل خطوة حسابية.
class SimulationController extends ChangeNotifier {
  SimulationController() {
    engine = WaveSimulationEngine();
    renderer = WaveImageRenderer(onImage: _onImageReady);
    loadDefaultScene();
  }

  late final WaveSimulationEngine engine;
  late final WaveImageRenderer renderer;

  /// يزداد مع كل إطار جديد جاهز للرسم.
  final ValueNotifier<int> frame = ValueNotifier<int>(0);

  final List<WaveSource> sources = [];
  final List<ObstacleObject> obstacles = [];
  final List<MediumObject> media = [];
  final List<WaveProbe> probes = [];
  final List<TextAnnotation> texts = [];

  int _nextId = 1;
  int _nextProbeColor = 0;

  bool _playing = true;
  bool _is3D = false;
  double _speed = SimDefaults.simulationSpeed;
  double _brightness = SimDefaults.brightness;
  ColorSchemeType _scheme = ColorSchemeType.cyan;

  ToolMode _tool = ToolMode.move;
  SourceType pendingSourceType = SourceType.point;
  ObstacleType pendingObstacleType = ObstacleType.wall;
  MediumType pendingMediumType = MediumType.rectangle;

  Object? _selected;
  bool _draggingSelected = false;

  // كاميرا العرض الثلاثي.
  double yaw = 0.55;
  double pitch = 0.95;
  double zoom = 1.0;

  /// معاينة الرسم بالسحب (إحداثيات نسبية).
  Offset? dragStart;
  Offset? dragEnd;

  double _stepAccumulator = 0;
  bool _dirty = true;
  bool _disposed = false;

  // ---------------------------------------------------------------- getters
  bool get playing => _playing;
  bool get is3D => _is3D;
  double get speed => _speed;
  double get brightness => _brightness;
  double get frequency => engine.frequency;
  double get damping => engine.damping;
  double get waveSpeed2 => engine.waveSpeed2;
  int get resolution => engine.size;
  ColorSchemeType get scheme => _scheme;
  ToolMode get tool => _tool;
  Object? get selected => _selected;

  // ------------------------------------------------------------------ loop
  /// يُستدعى من Ticker في كل إطار. [dt] بالثواني.
  void tick(double dt) {
    if (_disposed) return;
    if (_playing) {
      _stepAccumulator +=
          math.min(dt, 0.05) * SimDefaults.stepsPerSecond * _speed;
      var steps = _stepAccumulator.floor();
      _stepAccumulator -= steps;
      if (steps > SimDefaults.maxStepsPerFrame) {
        steps = SimDefaults.maxStepsPerFrame;
      }
      for (var k = 0; k < steps; k++) {
        engine.step(sources);
      }
      if (steps > 0) {
        _sampleProbes();
        _dirty = true;
      }
    }
    if (_dirty) {
      if (_is3D) {
        _dirty = false;
        frame.value++;
      } else if (renderer.render(engine, _scheme, _brightness)) {
        _dirty = false;
      }
    }
  }

  void _onImageReady() {
    if (!_disposed) frame.value++;
  }

  void _sampleProbes() {
    for (final p in probes) {
      p.record(engine.sample(p.x, p.y));
    }
  }

  void markDirty() => _dirty = true;

  // -------------------------------------------------------------- settings
  void togglePlay() {
    _playing = !_playing;
    notifyListeners();
  }

  void setPlaying(bool v) {
    _playing = v;
    notifyListeners();
  }

  void set3D(bool v) {
    _is3D = v;
    dragStart = null;
    dragEnd = null;
    _dirty = true;
    notifyListeners();
  }

  void setFrequency(double v) {
    engine.frequency = v;
    _dirty = true;
    notifyListeners();
  }

  void setSpeed(double v) {
    _speed = clampD(v, 0.1, 4.0);
    notifyListeners();
  }

  void setBrightness(double v) {
    _brightness = clampD(v, 0.5, 3.0);
    _dirty = true;
    notifyListeners();
  }

  void setDamping(double v) {
    engine.damping = v;
    notifyListeners();
  }

  void setWaveSpeed2(double v) {
    engine.waveSpeed2 = v;
    _dirty = true;
    notifyListeners();
  }

  void setScheme(ColorSchemeType s) {
    _scheme = s;
    _dirty = true;
    notifyListeners();
  }

  void setResolution(int n) {
    engine.resize(n);
    for (final p in probes) {
      p.reset();
    }
    _dirty = true;
    notifyListeners();
  }

  void rotate3D(double dx, double dy) {
    yaw -= dx * 0.008;
    pitch = clampD(pitch + dy * 0.006, 0.15, 1.5);
    _dirty = true;
  }

  void setZoom(double z) {
    zoom = clampD(z, 0.5, 2.8);
    _dirty = true;
  }

  void resetView() {
    yaw = 0.55;
    pitch = 0.95;
    zoom = 1.0;
    _dirty = true;
  }

  // ----------------------------------------------------------------- tools
  void setTool(ToolMode t) {
    _tool = t;
    dragStart = null;
    dragEnd = null;
    notifyListeners();
  }

  void chooseSourceType(SourceType t) {
    pendingSourceType = t;
    setTool(ToolMode.addSource);
  }

  void chooseObstacleType(ObstacleType t) {
    pendingObstacleType = t;
    setTool(ToolMode.drawWall);
  }

  void chooseMediumType(MediumType t) {
    pendingMediumType = t;
    setTool(ToolMode.drawMedium);
  }

  /// لمسة واحدة على مساحة المحاكاة (إحداثيات نسبية).
  /// أداة النص تُعالَج في الواجهة لأنها تحتاج نافذة إدخال.
  void tap(double x, double y) {
    switch (_tool) {
      case ToolMode.move:
        select(hitTest(x, y));
      case ToolMode.ripple:
        engine.addRipple(x, y);
        _dirty = true;
      case ToolMode.addSource:
        addSource(x, y);
      case ToolMode.drawWall:
        final t = pendingObstacleType;
        final angle = t == ObstacleType.box ? 0.0 : math.pi / 2;
        addObstacle(t, x, y, angle: angle);
      case ToolMode.drawMedium:
        addMedium(pendingMediumType, x, y);
      case ToolMode.addProbe:
        addProbe(x, y);
      case ToolMode.addText:
        break;
    }
  }

  void panStart(double x, double y) {
    switch (_tool) {
      case ToolMode.move:
        final h = hitTest(x, y);
        _draggingSelected = h != null;
        if (h != null && h != _selected) {
          _selected = h;
          notifyListeners();
        }
      case ToolMode.ripple:
        engine.addRipple(x, y);
        _dirty = true;
      case ToolMode.drawWall:
      case ToolMode.drawMedium:
        dragStart = Offset(x, y);
        dragEnd = Offset(x, y);
        _dirty = true;
      case ToolMode.addSource:
      case ToolMode.addProbe:
      case ToolMode.addText:
        break;
    }
  }

  void panUpdate(double x, double y, double dx, double dy) {
    switch (_tool) {
      case ToolMode.move:
        if (_draggingSelected) moveSelectedBy(dx, dy);
      case ToolMode.ripple:
        engine.addRipple(x, y, strength: 0.5);
        _dirty = true;
      case ToolMode.drawWall:
      case ToolMode.drawMedium:
        dragEnd = Offset(clampD(x, 0, 1), clampD(y, 0, 1));
        _dirty = true;
      case ToolMode.addSource:
      case ToolMode.addProbe:
      case ToolMode.addText:
        break;
    }
  }

  void panEnd() {
    final a = dragStart;
    final b = dragEnd;
    dragStart = null;
    dragEnd = null;
    _draggingSelected = false;
    if (a == null || b == null) {
      notifyListeners();
      return;
    }
    final d = b - a;
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    if (d.distance < 0.03) {
      tap(a.dx, a.dy);
      return;
    }
    if (_tool == ToolMode.drawWall) {
      final t = pendingObstacleType;
      if (t == ObstacleType.box) {
        addObstacle(t, mid.dx, mid.dy,
            width: math.max(0.02, d.dx.abs()),
            height: math.max(0.02, d.dy.abs()));
      } else {
        addObstacle(t, mid.dx, mid.dy,
            width: d.distance, angle: math.atan2(d.dy, d.dx));
      }
    } else if (_tool == ToolMode.drawMedium) {
      addMedium(pendingMediumType, mid.dx, mid.dy,
          width: math.max(0.03, d.dx.abs()),
          height: math.max(0.03, d.dy.abs()));
    }
  }

  // --------------------------------------------------------------- objects
  int _id() => _nextId++;

  void _rebuildGeometry() {
    engine.setGeometry(obstacles, media);
    _dirty = true;
  }

  WaveSource addSource(double x, double y, {SourceType? type}) {
    final t = type ?? pendingSourceType;
    final s = WaveSource(
      id: _id(),
      type: t,
      x: x,
      y: y,
      angle: t == SourceType.line ? math.pi / 2 : 0,
    );
    sources.add(s);
    _selected = s;
    _dirty = true;
    notifyListeners();
    return s;
  }

  ObstacleObject addObstacle(ObstacleType type, double x, double y,
      {double? width, double? height, double angle = 0}) {
    final o = ObstacleObject(
      id: _id(),
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      angle: angle,
    );
    obstacles.add(o);
    _selected = o;
    _rebuildGeometry();
    notifyListeners();
    return o;
  }

  MediumObject addMedium(MediumType type, double x, double y,
      {double? width, double? height, double angle = 0, double speedFactor = 0.6}) {
    final m = MediumObject(
      id: _id(),
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      angle: angle,
      speedFactor: speedFactor,
    );
    media.add(m);
    _selected = m;
    _rebuildGeometry();
    notifyListeners();
    return m;
  }

  WaveProbe addProbe(double x, double y) {
    final p = WaveProbe(
      id: _id(),
      x: x,
      y: y,
      color: kProbeColors[_nextProbeColor++ % kProbeColors.length],
    );
    probes.add(p);
    _selected = p;
    _dirty = true;
    notifyListeners();
    return p;
  }

  TextAnnotation addText(double x, double y, String text) {
    final t = TextAnnotation(id: _id(), x: x, y: y, text: text);
    texts.add(t);
    _selected = t;
    _dirty = true;
    notifyListeners();
    return t;
  }

  void select(Object? o) {
    _selected = o;
    _dirty = true;
    notifyListeners();
  }

  /// يبحث عن العنصر تحت نقطة اللمس، بأولوية: مجسات، مصادر، نصوص، عوائق، أوساط.
  Object? hitTest(double x, double y) {
    const r = 0.035;
    double dist(double ax, double ay) => math.sqrt(
        (ax - x) * (ax - x) + (ay - y) * (ay - y));

    for (final p in probes.reversed) {
      if (dist(p.x, p.y) < r) return p;
    }
    for (final s in sources.reversed) {
      switch (s.type) {
        case SourceType.point:
          if (dist(s.x, s.y) < r) return s;
        case SourceType.line:
          final l = toLocal(x, y, s.x, s.y, s.angle);
          if (l.x.abs() <= s.size / 2 + r && l.y.abs() <= r) return s;
        case SourceType.pair:
        case SourceType.multipole:
          if (dist(s.x, s.y) < s.size / 2 + r) return s;
      }
    }
    for (final t in texts.reversed) {
      if ((t.x - x).abs() < 0.14 && (t.y - y).abs() < 0.035) return t;
    }
    for (final o in obstacles.reversed) {
      if (o.hitTest(x, y, 0.02)) return o;
    }
    for (final m in media.reversed) {
      if (m.hitTest(x, y, 0.005)) return m;
    }
    return null;
  }

  void moveSelectedBy(double dx, double dy) {
    final o = _selected;
    if (o is WaveSource) {
      o.x = clampD(o.x + dx, 0, 1);
      o.y = clampD(o.y + dy, 0, 1);
    } else if (o is WaveProbe) {
      o.x = clampD(o.x + dx, 0, 1);
      o.y = clampD(o.y + dy, 0, 1);
    } else if (o is TextAnnotation) {
      o.x = clampD(o.x + dx, 0, 1);
      o.y = clampD(o.y + dy, 0, 1);
    } else if (o is ObstacleObject) {
      o.x = clampD(o.x + dx, 0, 1);
      o.y = clampD(o.y + dy, 0, 1);
      _rebuildGeometry();
    } else if (o is MediumObject) {
      o.x = clampD(o.x + dx, 0, 1);
      o.y = clampD(o.y + dy, 0, 1);
      _rebuildGeometry();
    }
    _dirty = true;
  }

  /// يُستدعى بعد تعديل خصائص العنصر المحدد من لوحة الخصائص.
  void selectionEdited() {
    final o = _selected;
    if (o is ObstacleObject || o is MediumObject) _rebuildGeometry();
    _dirty = true;
    notifyListeners();
  }

  void deleteSelected() {
    final o = _selected;
    if (o == null) return;
    remove(o);
  }

  void remove(Object o) {
    if (o is WaveSource) sources.remove(o);
    if (o is WaveProbe) probes.remove(o);
    if (o is TextAnnotation) texts.remove(o);
    if (o is ObstacleObject) {
      obstacles.remove(o);
      _rebuildGeometry();
    }
    if (o is MediumObject) {
      media.remove(o);
      _rebuildGeometry();
    }
    if (identical(_selected, o)) _selected = null;
    _dirty = true;
    notifyListeners();
  }

  // ----------------------------------------------------------------- clear
  void clearWaves() {
    engine.clearWaves();
    for (final p in probes) {
      p.reset();
    }
    _dirty = true;
    notifyListeners();
  }

  void clearWalls() {
    obstacles.clear();
    if (_selected is ObstacleObject) _selected = null;
    _rebuildGeometry();
    notifyListeners();
  }

  void clearMedia() {
    media.clear();
    if (_selected is MediumObject) _selected = null;
    _rebuildGeometry();
    notifyListeners();
  }

  void clearProbes() {
    probes.clear();
    if (_selected is WaveProbe) _selected = null;
    _dirty = true;
    notifyListeners();
  }

  void clearAll() {
    _clearObjects();
    _rebuildGeometry();
    engine.clearWaves();
    notifyListeners();
  }

  void _clearObjects() {
    sources.clear();
    obstacles.clear();
    media.clear();
    probes.clear();
    texts.clear();
    _selected = null;
    dragStart = null;
    dragEnd = null;
    _nextProbeColor = 0;
  }

  // ---------------------------------------------------------------- scenes
  /// مشهد جديد فارغ مع الحفاظ على الإعدادات.
  void newScene() => clearAll();

  /// إعادة كل الإعدادات للقيم الافتراضية مع المشهد الافتراضي.
  void resetDefault() {
    engine.frequency = SimDefaults.frequency;
    engine.damping = SimDefaults.damping;
    engine.resize(SimDefaults.gridSize);
    engine.waveSpeed2 = SimDefaults.waveSpeed2;
    _speed = SimDefaults.simulationSpeed;
    _brightness = SimDefaults.brightness;
    _scheme = ColorSchemeType.cyan;
    _is3D = false;
    _tool = ToolMode.move;
    resetView();
    loadDefaultScene();
  }

  /// المشهد الافتراضي: مصدران نقطيان يبدآن الإصدار فوراً فيظهر التداخل.
  void loadDefaultScene() {
    _clearObjects();
    sources.add(WaveSource(id: _id(), x: 0.4, y: 0.5));
    sources.add(WaveSource(id: _id(), x: 0.6, y: 0.5));
    _rebuildGeometry();
    engine.clearWaves();
    _playing = true;
    notifyListeners();
  }

  void loadPreset(Preset p) {
    _clearObjects();
    engine.clearWaves();
    const vertical = math.pi / 2;
    switch (p) {
      case Preset.doubleSlit:
        engine.frequency = 0.25;
        sources.add(WaveSource(
            id: _id(), type: SourceType.line, x: 0.1, y: 0.5,
            angle: vertical, size: 0.9));
        obstacles.add(ObstacleObject(
            id: _id(), type: ObstacleType.doubleSlit, x: 0.35, y: 0.5,
            width: 1.0, angle: vertical, slitWidth: 0.035, slitSeparation: 0.14));
        _addPresetProbe(0.8, 0.5);
        _addPresetProbe(0.8, 0.6);
        texts.add(TextAnnotation(
            id: _id(), x: 0.62, y: 0.07, text: 'تجربة الشق المزدوج'));
      case Preset.convexLens:
        engine.frequency = 0.25;
        sources.add(WaveSource(
            id: _id(), type: SourceType.line, x: 0.1, y: 0.5,
            angle: vertical, size: 0.9));
        media.add(MediumObject(
            id: _id(), type: MediumType.convexLens, x: 0.38, y: 0.5,
            width: 0.16, height: 0.7, speedFactor: 0.55));
        _addPresetProbe(0.72, 0.5);
        texts.add(TextAnnotation(
            id: _id(), x: 0.62, y: 0.07, text: 'العدسة المحدبة تجمع الأمواج'));
      case Preset.prism:
        engine.frequency = 0.28;
        sources.add(WaveSource(
            id: _id(), type: SourceType.line, x: 0.1, y: 0.5,
            angle: vertical, size: 0.9));
        media.add(MediumObject(
            id: _id(), type: MediumType.prism, x: 0.5, y: 0.52,
            width: 0.46, height: 0.42, speedFactor: 0.6));
        _addPresetProbe(0.82, 0.5);
        texts.add(TextAnnotation(
            id: _id(), x: 0.62, y: 0.07, text: 'انكسار الأمواج في المنشور'));
      case Preset.parabolicMirror:
        engine.frequency = 0.25;
        sources.add(WaveSource(
            id: _id(), type: SourceType.line, x: 0.12, y: 0.5,
            angle: vertical, size: 0.8));
        final mirror = ObstacleObject(
            id: _id(), type: ObstacleType.parabolicMirror, x: 0.84, y: 0.5,
            width: 0.72, angle: vertical, focal: 0.18);
        obstacles.add(mirror);
        final f = mirror.focusPoint;
        _addPresetProbe(f.x, f.y);
        texts.add(TextAnnotation(
            id: _id(), x: f.x, y: f.y + 0.06, text: 'البؤرة'));
    }
    _rebuildGeometry();
    _playing = true;
    notifyListeners();
  }

  void _addPresetProbe(double x, double y) {
    probes.add(WaveProbe(
      id: _id(),
      x: x,
      y: y,
      color: kProbeColors[_nextProbeColor++ % kProbeColors.length],
    ));
  }

  Map<String, dynamic> toSceneJson() => {
        'app': 'ripple_tank',
        'version': 1,
        'settings': {
          'frequency': engine.frequency,
          'damping': engine.damping,
          'waveSpeed2': engine.waveSpeed2,
          'resolution': engine.size,
          'speed': _speed,
          'brightness': _brightness,
          'scheme': _scheme.name,
          'is3D': _is3D,
          'yaw': yaw,
          'pitch': pitch,
          'zoom': zoom,
        },
        'sources': sources.map((e) => e.toJson()).toList(),
        'obstacles': obstacles.map((e) => e.toJson()).toList(),
        'media': media.map((e) => e.toJson()).toList(),
        'probes': probes.map((e) => e.toJson()).toList(),
        'texts': texts.map((e) => e.toJson()).toList(),
      };

  void loadSceneJson(Map<String, dynamic> j) {
    _clearObjects();
    final s = (j['settings'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    engine.resize(jsonInt(s['resolution'], SimDefaults.gridSize));
    engine.frequency = jsonDouble(s['frequency'], SimDefaults.frequency);
    engine.damping = jsonDouble(s['damping'], SimDefaults.damping);
    engine.waveSpeed2 = jsonDouble(s['waveSpeed2'], SimDefaults.waveSpeed2);
    _speed = clampD(jsonDouble(s['speed'], SimDefaults.simulationSpeed), 0.1, 4);
    _brightness =
        clampD(jsonDouble(s['brightness'], SimDefaults.brightness), 0.5, 3);
    _scheme = ColorSchemeType.values.firstWhere(
      (c) => c.name == s['scheme'],
      orElse: () => ColorSchemeType.cyan,
    );
    _is3D = jsonBool(s['is3D'], false);
    yaw = jsonDouble(s['yaw'], 0.55);
    pitch = clampD(jsonDouble(s['pitch'], 0.95), 0.15, 1.5);
    zoom = clampD(jsonDouble(s['zoom'], 1.0), 0.5, 2.8);

    List<Map<String, dynamic>> list(String key) => ((j[key] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    sources.addAll(list('sources').map(WaveSource.fromJson));
    obstacles.addAll(list('obstacles').map(ObstacleObject.fromJson));
    media.addAll(list('media').map(MediumObject.fromJson));
    probes.addAll(list('probes').map(WaveProbe.fromJson));
    texts.addAll(list('texts').map(TextAnnotation.fromJson));

    var maxId = 0;
    for (final id in [
      ...sources.map((e) => e.id),
      ...obstacles.map((e) => e.id),
      ...media.map((e) => e.id),
      ...probes.map((e) => e.id),
      ...texts.map((e) => e.id),
    ]) {
      if (id > maxId) maxId = id;
    }
    _nextId = maxId + 1;
    _nextProbeColor = probes.length;

    _rebuildGeometry();
    engine.clearWaves();
    _playing = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    renderer.dispose();
    frame.dispose();
    super.dispose();
  }
}
