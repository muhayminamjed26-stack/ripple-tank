import 'package:flutter_test/flutter_test.dart';
import 'package:ripple_tank/engine/wave_simulation_engine.dart';
import 'package:ripple_tank/models/medium_object.dart';
import 'package:ripple_tank/models/obstacle_object.dart';
import 'package:ripple_tank/models/wave_probe.dart';
import 'package:ripple_tank/models/wave_source.dart';
import 'package:ripple_tank/utils/constants.dart';

double energy(WaveSimulationEngine e) {
  var s = 0.0;
  for (final v in e.field) {
    s += v * v;
  }
  return s;
}

void main() {
  group('WaveSimulationEngine', () {
    test('المصدر يصدر موجات تلقائياً دون أي لمس', () {
      final e = WaveSimulationEngine(size: 100);
      final src = [WaveSource(id: 1, x: 0.5, y: 0.5)];
      for (var i = 0; i < 120; i++) {
        e.step(src);
      }
      // الموجة وصلت لنقطة بعيدة عن المصدر.
      var reached = false;
      for (var i = 0; i < 40; i++) {
        e.step(src);
        if (e.sample(0.7, 0.5).abs() > 1e-3) reached = true;
      }
      expect(reached, isTrue);
      expect(energy(e), greaterThan(0));
    });

    test('تحريك المصدر يجعله يصدر من الموقع الجديد', () {
      final e = WaveSimulationEngine(size: 100);
      final s = WaveSource(id: 1, x: 0.25, y: 0.25);
      for (var i = 0; i < 60; i++) {
        e.step([s]);
      }
      s.x = 0.75;
      s.y = 0.75;
      e.step([s]);
      expect(e.sample(0.755, 0.755).abs(), greaterThan(0));
    });

    test('بدون استدعاء step (إيقاف) تبقى الحالة كما هي', () {
      final e = WaveSimulationEngine(size: 80);
      final src = [WaveSource(id: 1, x: 0.5, y: 0.5)];
      for (var i = 0; i < 50; i++) {
        e.step(src);
      }
      final before = List<double>.from(e.field);
      expect(e.field, equals(before));
    });

    test('تغيير التردد يغير الطول الموجي', () {
      final e = WaveSimulationEngine(size: 100);
      final l1 = e.wavelength;
      e.frequency = 0.36;
      expect(e.wavelength, closeTo(l1 / 2, 1e-9));
    });

    test('الجدار يبقى صفراً ويحجب الموجة', () {
      final e = WaveSimulationEngine(size: 100);
      e.setGeometry([
        ObstacleObject(
            id: 1, type: ObstacleType.wall, x: 0.5, y: 0.5,
            width: 1.2, height: 0.04, angle: 1.5707963267948966),
      ], []);
      final src = [WaveSource(id: 2, x: 0.3, y: 0.5)];
      for (var i = 0; i < 200; i++) {
        e.step(src);
      }
      expect(e.isWallAt(0.5, 0.5), isTrue);
      expect(e.sample(0.5, 0.5).abs(), lessThan(0.05));
      // الجهة الأخرى من الجدار شبه ساكنة.
      expect(e.sample(0.75, 0.5).abs(), lessThan(0.02));
    });

    test('الشق المزدوج يحتوي فتحتين', () {
      final o = ObstacleObject(
          id: 1, type: ObstacleType.doubleSlit, x: 0.5, y: 0.5,
          width: 1.0, slitWidth: 0.04, slitSeparation: 0.2);
      const cell = 1 / 180;
      expect(o.contains(0.6, 0.5, cell), isFalse); // فتحة
      expect(o.contains(0.4, 0.5, cell), isFalse); // فتحة
      expect(o.contains(0.5, 0.5, cell), isTrue); // جدار بين الفتحتين
      expect(o.contains(0.9, 0.5, cell), isTrue);
    });

    test('الشق المفرد يسمح بمرور الموجة (حيود)', () {
      final e = WaveSimulationEngine(size: 100);
      e.setGeometry([
        ObstacleObject(
            id: 1, type: ObstacleType.singleSlit, x: 0.5, y: 0.5,
            width: 1.2, slitWidth: 0.1, angle: 1.5707963267948966),
      ], []);
      final src = [
        WaveSource(id: 2, type: SourceType.line, x: 0.2, y: 0.5,
            angle: 1.5707963267948966, size: 0.8)
      ];
      var maxAfter = 0.0;
      for (var i = 0; i < 260; i++) {
        e.step(src);
        final v = e.sample(0.62, 0.5).abs();
        if (v > maxAfter) maxAfter = v;
      }
      expect(maxAfter, greaterThan(0.02));
    });

    test('الوسط يقلل سرعة الموجة داخله (العدسة والمنشور)', () {
      final e = WaveSimulationEngine(size: 100);
      e.setGeometry([], [
        MediumObject(id: 1, type: MediumType.convexLens, x: 0.3, y: 0.5,
            speedFactor: 0.5),
        MediumObject(id: 2, type: MediumType.prism, x: 0.7, y: 0.5,
            speedFactor: 0.7),
      ]);
      final n = e.size;
      int idx(double x, double y) => (y * n).floor() * n + (x * n).floor();
      expect(e.speedMap[idx(0.3, 0.5)], closeTo(0.5, 1e-6));
      expect(e.speedMap[idx(0.7, 0.6)], closeTo(0.7, 1e-6));
      expect(e.speedMap[idx(0.1, 0.1)], closeTo(1.0, 1e-6));
    });

    test('تغيير الدقة يحافظ على العوائق', () {
      final e = WaveSimulationEngine(size: 100);
      e.setGeometry([
        ObstacleObject(id: 1, type: ObstacleType.box, x: 0.5, y: 0.5),
      ], []);
      e.resize(140);
      expect(e.size, 140);
      expect(e.isWallAt(0.5, 0.5), isTrue);
    });
  });

  group('WaveProbe', () {
    test('يسجل آخر 100 قراءة وأعلى سعة', () {
      final p = WaveProbe(id: 1, x: 0.5, y: 0.5, color: kProbeColors.first);
      for (var i = 0; i < 150; i++) {
        p.record(i == 10 ? -2.0 : 0.1);
      }
      expect(p.history.length, SimDefaults.probeHistory);
      expect(p.maxAmplitude, 2.0);
      expect(p.current, 0.1);
    });
  });

  group('JSON', () {
    test('حفظ واسترجاع المصدر والعائق', () {
      final s = WaveSource(
          id: 3, type: SourceType.multipole, x: 0.2, y: 0.3, poles: 6);
      final s2 = WaveSource.fromJson(s.toJson());
      expect(s2.type, SourceType.multipole);
      expect(s2.poles, 6);
      expect(s2.x, 0.2);

      final o = ObstacleObject(
          id: 4, type: ObstacleType.parabolicMirror, x: 0.8, y: 0.5, focal: 0.2);
      final o2 = ObstacleObject.fromJson(o.toJson());
      expect(o2.type, ObstacleType.parabolicMirror);
      expect(o2.focal, 0.2);
    });
  });
}
