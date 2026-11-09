import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// حفظ واسترجاع المشاهد محلياً بصيغة JSON.
class SceneStorageService {
  static const _key = 'ripple_tank_scenes_v1';

  Future<Map<String, String>> _all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      }
    } catch (_) {
      // بيانات تالفة: نتجاهلها ونبدأ من جديد.
    }
    return {};
  }

  Future<void> _write(Map<String, String> all) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(all));
  }

  Future<List<String>> listScenes() async {
    final names = (await _all()).keys.toList()..sort();
    return names;
  }

  Future<void> saveScene(String name, Map<String, dynamic> scene) async {
    final all = await _all();
    all[name] = jsonEncode(scene);
    await _write(all);
  }

  Future<Map<String, dynamic>?> loadScene(String name) async {
    final raw = (await _all())[name];
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    return decoded is Map ? decoded.cast<String, dynamic>() : null;
  }

  Future<void> deleteScene(String name) async {
    final all = await _all();
    all.remove(name);
    await _write(all);
  }

  /// تحويل مشهد إلى نص JSON منسّق (للنسخ والمشاركة).
  static String encodePretty(Map<String, dynamic> scene) =>
      const JsonEncoder.withIndent('  ').convert(scene);

  /// قراءة مشهد من نص JSON. يعيد null إذا كان النص غير صالح.
  static Map<String, dynamic>? tryDecode(String text) {
    try {
      final d = jsonDecode(text);
      return d is Map ? d.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }
}
