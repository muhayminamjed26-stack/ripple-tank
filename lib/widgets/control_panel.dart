import 'package:flutter/material.dart';

import '../controllers/simulation_controller.dart';
import '../utils/constants.dart';
import 'labeled_slider.dart';

/// لوحة التحكم السفلية القابلة للفتح والإغلاق.
class ControlPanel extends StatelessWidget {
  const ControlPanel({
    super.key,
    required this.controller,
    required this.expanded,
    required this.onToggle,
  });

  final SimulationController controller;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final lambdaCells = c.engine.wavelength * c.resolution;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              FilledButton.icon(
                onPressed: c.togglePlay,
                icon: Icon(c.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                label: Text(c.playing ? 'إيقاف' : 'تشغيل'),
              ),
              const SizedBox(width: 8),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('2D')),
                  ButtonSegment(value: true, label: Text('3D')),
                ],
                selected: {c.is3D},
                onSelectionChanged: (s) => c.set3D(s.first),
              ),
              const Spacer(),
              IconButton(
                tooltip: expanded ? 'إخفاء الإعدادات' : 'إظهار الإعدادات',
                onPressed: onToggle,
                icon: Icon(expanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.tune_rounded),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LabeledSlider(
                        label: 'التردد\nFrequency',
                        value: c.frequency,
                        min: 0.05,
                        max: 0.6,
                        onChanged: c.setFrequency,
                        display: (v) => v.toStringAsFixed(2),
                      ),
                      LabeledSlider(
                        label: 'سرعة المحاكاة\nSimulation Speed',
                        value: c.speed,
                        min: 0.25,
                        max: 4,
                        onChanged: c.setSpeed,
                        display: (v) => '${v.toStringAsFixed(2)}×',
                      ),
                      LabeledSlider(
                        label: 'السطوع\nBrightness',
                        value: c.brightness,
                        min: 0.5,
                        max: 3,
                        onChanged: c.setBrightness,
                        display: (v) => '${(v * 100).round()}%',
                      ),
                      LabeledSlider(
                        label: 'التخميد\nDamping',
                        value: c.damping,
                        min: 0.95,
                        max: 1.0,
                        onChanged: c.setDamping,
                        display: (v) => v.toStringAsFixed(3),
                      ),
                      LabeledSlider(
                        label: 'سرعة الموجة c²\nWave Speed',
                        value: c.waveSpeed2,
                        min: 0.1,
                        max: SimDefaults.maxWaveSpeed2,
                        onChanged: c.setWaveSpeed2,
                        display: (v) => v.toStringAsFixed(2),
                      ),
                      const SizedBox(height: 6),
                      _row(
                        'الألوان',
                        SegmentedButton<ColorSchemeType>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                              visualDensity: VisualDensity.compact),
                          segments: [
                            for (final s in ColorSchemeType.values)
                              ButtonSegment(value: s, label: Text(s.label)),
                          ],
                          selected: {c.scheme},
                          onSelectionChanged: (s) => c.setScheme(s.first),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _row(
                        'دقة الشبكة',
                        SegmentedButton<int>(
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                              visualDensity: VisualDensity.compact),
                          segments: [
                            for (final n in SimDefaults.gridSizes)
                              ButtonSegment(value: n, label: Text('$n')),
                          ],
                          selected: {c.resolution},
                          onSelectionChanged: (s) => c.setResolution(s.first),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 2),
                        child: Text(
                          'الطول الموجي λ ≈ ${lambdaCells.toStringAsFixed(1)} خلية'
                          ' • الشبكة ${c.resolution}×${c.resolution}',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, Widget child) => Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
        ],
      );
}
