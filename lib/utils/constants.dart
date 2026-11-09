import 'package:flutter/material.dart';

/// القيم الافتراضية للمحاكاة.
class SimDefaults {
  SimDefaults._();

  static const int gridSize = 180;
  static const List<int> gridSizes = [120, 180, 240];

  static const double damping = 0.985;
  static const double frequency = 0.18;
  static const double brightness = 1.2;
  static const double simulationSpeed = 1.0;
  static const double waveSpeed2 = 0.4;

  /// حد الاستقرار لطريقة الفروق المحدودة ثنائية الأبعاد (c² ≤ 0.5).
  static const double maxWaveSpeed2 = 0.5;

  /// عدد خطوات المحاكاة في الثانية عند سرعة 1.0 (خطوتان لكل إطار عند 60 FPS).
  static const double stepsPerSecond = 120;
  static const int maxStepsPerFrame = 12;

  static const int meshSize = 60;
  static const int probeHistory = 100;

  /// عدد الخطوات اللازمة ليصل المصدر إلى سعته الكاملة (بداية ناعمة).
  static const int sourceRampSteps = 40;
}

class AppColors {
  AppColors._();

  static const bg = Color(0xFF050A14);
  static const surface = Color(0xFF0D1524);
  static const surface2 = Color(0xFF142036);
  static const border = Color(0xFF223252);
  static const accent = Color(0xFF00E5FF);
  static const accent2 = Color(0xFF2979FF);
  static const text = Color(0xFFE6EDF7);
  static const muted = Color(0xFF8899B8);
  static const danger = Color(0xFFFF5370);
}

const List<Color> kProbeColors = [
  Color(0xFF00E676), // أخضر
  Color(0xFFFF5252), // أحمر
  Color(0xFF448AFF), // أزرق
  Color(0xFFFFD740), // أصفر
  Color(0xFFB388FF), // بنفسجي
  Color(0xFFFFAB40), // برتقالي
  Color(0xFFFF4081), // وردي
  Color(0xFF1DE9B6), // فيروزي
];

enum ColorSchemeType { cyan, green, highContrast }

extension ColorSchemeTypeInfo on ColorSchemeType {
  String get label => switch (this) {
        ColorSchemeType.cyan => 'سماوي',
        ColorSchemeType.green => 'أخضر',
        ColorSchemeType.highContrast => 'تباين عالٍ',
      };
}

/// تحويل آمن لقيم JSON.
double jsonDouble(Object? v, double fallback) =>
    v is num ? v.toDouble() : fallback;

int jsonInt(Object? v, int fallback) => v is num ? v.toInt() : fallback;

bool jsonBool(Object? v, bool fallback) => v is bool ? v : fallback;

double clampD(double v, double lo, double hi) {
  if (v < lo) return lo;
  if (v > hi) return hi;
  return v;
}
