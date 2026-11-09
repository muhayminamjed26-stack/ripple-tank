import '../utils/constants.dart';

/// ملاحظة نصية توضيحية فوق المحاكاة.
class TextAnnotation {
  TextAnnotation({
    required this.id,
    required this.x,
    required this.y,
    required this.text,
    this.fontSize = 14,
  });

  final int id;
  double x;
  double y;
  String text;
  double fontSize;

  Map<String, dynamic> toJson() => {
        'id': id,
        'x': x,
        'y': y,
        'text': text,
        'fontSize': fontSize,
      };

  factory TextAnnotation.fromJson(Map<String, dynamic> j) => TextAnnotation(
        id: jsonInt(j['id'], 0),
        x: jsonDouble(j['x'], 0.5),
        y: jsonDouble(j['y'], 0.5),
        text: (j['text'] as String?) ?? '',
        fontSize: jsonDouble(j['fontSize'], 14),
      );
}
