import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/simulation_controller.dart';
import '../models/medium_object.dart';
import '../models/obstacle_object.dart';
import '../models/text_annotation.dart';
import '../models/wave_probe.dart';
import '../models/wave_source.dart';
import '../utils/constants.dart';
import 'labeled_slider.dart';
import 'source_controls.dart';

/// لوحة خصائص العنصر المحدد: تعديل الحجم والموقع والقيم الفيزيائية والحذف.
class PropertiesPanel extends StatelessWidget {
  const PropertiesPanel({super.key, required this.controller});

  final SimulationController controller;

  @override
  Widget build(BuildContext context) {
    final o = controller.selected;
    if (o == null) return const SizedBox.shrink();

    final (String title, Widget body) = switch (o) {
      WaveSource s => (
          'مصدر #${s.id} — ${s.type.shortLabel}',
          SourceControls(controller: controller, source: s)
        ),
      ObstacleObject ob => (
          'عائق #${ob.id} — ${ob.type.shortLabel}',
          _ObstacleControls(controller: controller, obstacle: ob)
        ),
      MediumObject m => (
          'وسط #${m.id} — ${m.type.shortLabel}',
          _MediumControls(controller: controller, medium: m)
        ),
      WaveProbe p => (
          'مجس #${p.id}',
          _ProbeInfo(controller: controller, probe: p)
        ),
      TextAnnotation t => (
          'ملاحظة #${t.id}',
          _TextControls(
              key: ValueKey('text-${t.id}'), controller: controller, text: t)
        ),
      _ => ('عنصر', const SizedBox.shrink()),
    };

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 2, 4, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note_rounded,
                  size: 20, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
              ),
              IconButton(
                tooltip: 'حذف',
                onPressed: controller.deleteSelected,
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
              ),
              IconButton(
                tooltip: 'إلغاء التحديد',
                onPressed: () => controller.select(null),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Flexible(child: SingleChildScrollView(child: body)),
        ],
      ),
    );
  }
}

String _deg(double v) => '${(v * 180 / math.pi).round()}°';

class _ObstacleControls extends StatelessWidget {
  const _ObstacleControls({required this.controller, required this.obstacle});

  final SimulationController controller;
  final ObstacleObject obstacle;

  void _edit(void Function() fn) {
    fn();
    controller.selectionEdited();
  }

  @override
  Widget build(BuildContext context) {
    final o = obstacle;
    final isBox = o.type == ObstacleType.box;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TypeRow<ObstacleType>(
          value: o.type,
          values: ObstacleType.values,
          labelOf: (t) => t.label,
          onChanged: (t) => _edit(() {
            o.type = t;
            o.height = ObstacleObject.defaultHeight(t);
          }),
        ),
        LabeledSlider(
          label: isBox ? 'العرض\nWidth' : 'الطول\nLength',
          value: o.width,
          min: 0.02,
          max: 1.2,
          onChanged: (v) => _edit(() => o.width = v),
        ),
        LabeledSlider(
          label: isBox ? 'الارتفاع\nHeight' : 'السُمك\nThickness',
          value: o.height,
          min: isBox ? 0.02 : 0.005,
          max: isBox ? 0.8 : 0.06,
          onChanged: (v) => _edit(() => o.height = v),
          display: (v) => v.toStringAsFixed(3),
        ),
        LabeledSlider(
          label: 'الزاوية\nAngle',
          value: o.angle,
          min: 0,
          max: 2 * math.pi,
          onChanged: (v) => _edit(() => o.angle = v),
          display: _deg,
        ),
        if (o.type == ObstacleType.singleSlit ||
            o.type == ObstacleType.doubleSlit)
          LabeledSlider(
            label: 'عرض الشق\nSlit Width',
            value: o.slitWidth,
            min: 0.01,
            max: 0.2,
            onChanged: (v) => _edit(() => o.slitWidth = v),
            display: (v) => v.toStringAsFixed(3),
          ),
        if (o.type == ObstacleType.doubleSlit)
          LabeledSlider(
            label: 'المسافة بين الشقين\nSeparation',
            value: o.slitSeparation,
            min: 0.04,
            max: 0.5,
            onChanged: (v) => _edit(() => o.slitSeparation = v),
            display: (v) => v.toStringAsFixed(3),
          ),
        if (o.type == ObstacleType.parabolicMirror)
          LabeledSlider(
            label: 'البعد البؤري\nFocal Length',
            value: o.focal,
            min: 0.05,
            max: 0.5,
            onChanged: (v) => _edit(() => o.focal = v),
          ),
      ],
    );
  }
}

class _MediumControls extends StatelessWidget {
  const _MediumControls({required this.controller, required this.medium});

  final SimulationController controller;
  final MediumObject medium;

  void _edit(void Function() fn) {
    fn();
    controller.selectionEdited();
  }

  @override
  Widget build(BuildContext context) {
    final m = medium;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TypeRow<MediumType>(
          value: m.type,
          values: MediumType.values,
          labelOf: (t) => t.label,
          onChanged: (t) => _edit(() => m.type = t),
        ),
        LabeledSlider(
          label: 'العرض\nWidth',
          value: m.width,
          min: 0.03,
          max: 1.0,
          onChanged: (v) => _edit(() => m.width = v),
        ),
        LabeledSlider(
          label: 'الارتفاع\nHeight',
          value: m.height,
          min: 0.03,
          max: 1.0,
          onChanged: (v) => _edit(() => m.height = v),
        ),
        LabeledSlider(
          label: 'الزاوية\nAngle',
          value: m.angle,
          min: 0,
          max: 2 * math.pi,
          onChanged: (v) => _edit(() => m.angle = v),
          display: _deg,
        ),
        LabeledSlider(
          label: 'معامل السرعة\nSpeed Factor',
          value: m.speedFactor,
          min: 0.2,
          max: 1.0,
          onChanged: (v) => _edit(() => m.speedFactor = v),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            'معامل الانكسار n ≈ ${m.refractiveIndex.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _ProbeInfo extends StatelessWidget {
  const _ProbeInfo({required this.controller, required this.probe});

  final SimulationController controller;
  final WaveProbe probe;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.frame,
      builder: (context, _, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          'الموقع (${probe.x.toStringAsFixed(2)}, ${probe.y.toStringAsFixed(2)})\n'
          'السعة الحالية ${probe.current.toStringAsFixed(3)} • '
          'أعلى سعة ${probe.maxAmplitude.toStringAsFixed(3)} • '
          'القراءات ${probe.history.length}/${SimDefaults.probeHistory}',
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
      ),
    );
  }
}

class _TextControls extends StatefulWidget {
  const _TextControls({super.key, required this.controller, required this.text});

  final SimulationController controller;
  final TextAnnotation text;

  @override
  State<_TextControls> createState() => _TextControlsState();
}

class _TextControlsState extends State<_TextControls> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.text.text);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: _ctrl,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'النص',
            ),
            onChanged: (v) {
              t.text = v;
              widget.controller.selectionEdited();
            },
          ),
        ),
        LabeledSlider(
          label: 'حجم الخط\nFont Size',
          value: t.fontSize,
          min: 10,
          max: 30,
          onChanged: (v) {
            t.fontSize = v;
            widget.controller.selectionEdited();
          },
          display: (v) => v.round().toString(),
        ),
      ],
    );
  }
}

class _TypeRow<T> extends StatelessWidget {
  const _TypeRow({
    required this.value,
    required this.values,
    required this.labelOf,
    required this.onChanged,
  });

  final T value;
  final List<T> values;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 118,
          child: Text('النوع',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ),
        Expanded(
          child: DropdownButton<T>(
            isExpanded: true,
            value: value,
            dropdownColor: AppColors.surface2,
            items: [
              for (final v in values)
                DropdownMenuItem<T>(value: v, child: Text(labelOf(v))),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
