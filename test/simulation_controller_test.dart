import 'package:flutter_test/flutter_test.dart';
import 'package:ripple_tank/controllers/simulation_controller.dart';
import 'package:ripple_tank/models/obstacle_object.dart';

/// العرض الثلاثي لا يحتاج توليد صور، فيناسب الاختبارات دون محرك رسم.
SimulationController make() => SimulationController()..set3D(true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('التشغيل والإيقاف', () {
    final c = make();
    final before = c.engine.steps;
    c.tick(1 / 60);
    expect(c.engine.steps, greaterThan(before));

    c.setPlaying(false);
    final paused = c.engine.steps;
    c.tick(1 / 60);
    expect(c.engine.steps, paused);
    c.dispose();
  });

  test('سرعة المحاكاة تزيد عدد الخطوات', () {
    final c = make();
    c.setSpeed(1);
    final s0 = c.engine.steps;
    c.tick(1 / 60);
    final normal = c.engine.steps - s0;
    c.setSpeed(3);
    final s1 = c.engine.steps;
    c.tick(1 / 60);
    expect(c.engine.steps - s1, greaterThan(normal));
    c.dispose();
  });

  test('التجارب الجاهزة تبني المشهد', () {
    final c = make();
    c.loadPreset(Preset.doubleSlit);
    expect(c.sources, isNotEmpty);
    expect(c.obstacles.single.type, ObstacleType.doubleSlit);

    c.loadPreset(Preset.convexLens);
    expect(c.media, isNotEmpty);
    expect(c.obstacles, isEmpty);

    c.loadPreset(Preset.parabolicMirror);
    expect(c.obstacles.single.type, ObstacleType.parabolicMirror);
    c.dispose();
  });

  test('المجسات تسجل القراءات', () {
    final c = make();
    final p = c.addProbe(0.45, 0.5);
    for (var i = 0; i < 30; i++) {
      c.tick(1 / 60);
    }
    expect(p.history.length, greaterThan(10));
    c.dispose();
  });

  test('حفظ المشهد واسترجاعه', () {
    final c = make();
    c.loadPreset(Preset.prism);
    c.addProbe(0.3, 0.3);
    c.setFrequency(0.3);
    final json = c.toSceneJson();

    final c2 = make();
    c2.loadSceneJson(json);
    expect(c2.sources.length, c.sources.length);
    expect(c2.media.length, c.media.length);
    expect(c2.probes.length, c.probes.length);
    expect(c2.texts.length, c.texts.length);
    expect(c2.frequency, closeTo(0.3, 1e-9));
    c.dispose();
    c2.dispose();
  });

  test('رسم جدار بالسحب', () {
    final c = make();
    c.chooseObstacleType(ObstacleType.wall);
    c.panStart(0.2, 0.2);
    c.panUpdate(0.6, 0.2, 0.4, 0);
    c.panEnd();
    expect(c.obstacles.length, 1);
    expect(c.obstacles.first.width, closeTo(0.4, 1e-9));
    c.dispose();
  });
}
