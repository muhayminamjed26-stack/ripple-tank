import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controllers/simulation_controller.dart';
import '../models/wave_source.dart';
import '../utils/constants.dart';
import 'labeled_slider.dart';

/// تعديل خصائص مصدر الأمواج المحدد.
class SourceControls extends StatelessWidget {
  const SourceControls({
    super.key,
    required this.controller,
    required this.source,
  });

  final SimulationController controller;
  final WaveSource source;

  void _edit(void Function() fn) {
    fn();
    controller.selectionEdited();
  }

  @override
  Widget build(BuildContext context) {
    final s = source;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 118,
              child: Text('النوع',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ),
            Expanded(
              child: DropdownButton<SourceType>(
                isExpanded: true,
                value: s.type,
                dropdownColor: AppColors.surface2,
                items: [
                  for (final t in SourceType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (t) {
                  if (t == null) return;
                  _edit(() {
                    s.type = t;
                    s.size = WaveSource.defaultSize(t);
                    s.angle = t == SourceType.line ? math.pi / 2 : 0.0;
                  });
                },
              ),
            ),
          ],
        ),
        SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: const Text('يعمل (Enabled)', style: TextStyle(fontSize: 13)),
          value: s.enabled,
          onChanged: (v) => _edit(() => s.enabled = v),
        ),
        LabeledSlider(
          label: 'السعة\nAmplitude',
          value: s.amplitude,
          min: 0.1,
          max: 2.0,
          onChanged: (v) => _edit(() => s.amplitude = v),
        ),
        LabeledSlider(
          label: 'الطور\nPhase',
          value: s.phase,
          min: 0,
          max: 2 * math.pi,
          onChanged: (v) => _edit(() => s.phase = v),
          display: (v) => '${(v * 180 / math.pi).round()}°',
        ),
        if (s.type != SourceType.point)
          LabeledSlider(
            label: 'الزاوية\nAngle',
            value: s.angle,
            min: 0,
            max: 2 * math.pi,
            onChanged: (v) => _edit(() => s.angle = v),
            display: (v) => '${(v * 180 / math.pi).round()}°',
          ),
        if (s.type == SourceType.line)
          LabeledSlider(
            label: 'طول الخط\nLength',
            value: s.size,
            min: 0.05,
            max: 1.0,
            onChanged: (v) => _edit(() => s.size = v),
          ),
        if (s.type == SourceType.pair || s.type == SourceType.multipole)
          LabeledSlider(
            label: 'المسافة\nSpacing',
            value: s.size,
            min: 0.03,
            max: 0.5,
            onChanged: (v) => _edit(() => s.size = v),
          ),
        if (s.type == SourceType.multipole)
          LabeledSlider(
            label: 'عدد الأقطاب\nPoles',
            value: s.poles.toDouble(),
            min: 2,
            max: 8,
            divisions: 6,
            onChanged: (v) => _edit(() => s.poles = v.round()),
            display: (v) => '${v.round()}',
          ),
      ],
    );
  }
}
