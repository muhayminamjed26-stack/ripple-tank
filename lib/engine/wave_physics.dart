import 'dart:math' as math;
import 'dart:typed_data';

/// دوال فيزيائية خالصة، مستقلة عن الواجهة وقابلة للاختبار.
class WavePhysics {
  WavePhysics._();

  /// خطوة واحدة لمعادلة الموجة بالفروق المحدودة:
  ///   u_next = (2·u − u_prev + c²·∇²u) · damp
  /// حيث ∇²u هو اللابلاسيان بخمس نقاط. الخلايا الصلبة (wall = 1) تبقى صفراً،
  /// وهذا ما يسبب الانعكاس عن الجدران والحيود عند الشقوق.
  static void propagate({
    required Float32List cur,
    required Float32List prev,
    required Float32List next,
    required Float32List c2,
    required Float32List damp,
    required Uint8List wall,
    required int n,
  }) {
    for (var y = 1; y < n - 1; y++) {
      var i = y * n + 1;
      for (var x = 1; x < n - 1; x++, i++) {
        if (wall[i] != 0) {
          next[i] = 0;
          continue;
        }
        final c = cur[i];
        final lap = cur[i - 1] + cur[i + 1] + cur[i - n] + cur[i + n] - 4 * c;
        next[i] = (2 * c - prev[i] + c2[i] * lap) * damp[i];
      }
    }
  }

  /// معامل الامتصاص قرب الحواف (Sponge layer) حتى تختفي الموجة بسلاسة
  /// بدل أن ترتد عن حدود الشبكة.
  static double spongeFactor(int x, int y, int n) {
    final border = math.max(8, (n * 0.07).round());
    final d = math.min(math.min(x, y), math.min(n - 1 - x, n - 1 - y));
    if (d >= border) return 1.0;
    final t = (border - d) / border;
    return 1.0 - 0.12 * t * t;
  }

  /// التخميد لكل خطوة. قيمة Damping في الواجهة (افتراضياً 0.985) تمثّل
  /// الاحتفاظ بالطاقة لكل 10 خطوات، فتكون قيمة الخطوة الواحدة 1 − (1 − d)/10.
  static double retentionPerStep(double damping) => 1 - (1 - damping) * 0.1;

  /// الطول الموجي بوحدة الخلايا: λ = c·T = √(c²)·2π/ω
  static double wavelengthCells(double waveSpeed2, double omega) =>
      math.sqrt(waveSpeed2) * 2 * math.pi / omega;

  /// قراءة القيمة عند نقطة نسبية (0..1) بالاستيفاء الثنائي الخطي.
  static double sampleBilinear(Float32List f, int n, double nx, double ny) {
    var fx = nx * n - 0.5;
    var fy = ny * n - 0.5;
    if (fx < 0) fx = 0;
    if (fy < 0) fy = 0;
    if (fx > n - 1.001) fx = n - 1.001;
    if (fy > n - 1.001) fy = n - 1.001;
    final x0 = fx.floor();
    final y0 = fy.floor();
    final tx = fx - x0;
    final ty = fy - y0;
    final i = y0 * n + x0;
    final a = f[i];
    final b = f[i + 1];
    final c = f[i + n];
    final d = f[i + n + 1];
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty;
  }
}
