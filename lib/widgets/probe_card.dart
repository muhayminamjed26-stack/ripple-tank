import 'package:flutter/material.dart';

import '../controllers/simulation_controller.dart';
import '../models/wave_probe.dart';
import '../rendering/probe_painter.dart';
import '../utils/constants.dart';

/// بطاقة مجس: الرقم، القراءة الحالية، أعلى سعة، ورسم بياني مباشر.
class ProbeCard extends StatelessWidget {
  const ProbeCard({super.key, required this.controller, required this.probe});

  final SimulationController controller;
  final WaveProbe probe;

  @override
  Widget build(BuildContext context) {
    final selected = identical(controller.selected, probe);
    return GestureDetector(
      onTap: () => controller.select(probe),
      child: Container(
        width: 176,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? probe.color : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: probe.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text('مجس #${probe.id}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                const Spacer(),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    tooltip: 'حذف المجس',
                    onPressed: () => controller.remove(probe),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.danger),
                  ),
                ),
              ],
            ),
            ValueListenableBuilder<int>(
              valueListenable: controller.frame,
              builder: (context, _, __) => Text(
                'السعة ${probe.current.toStringAsFixed(3)}   '
                'الأعلى ${probe.maxAmplitude.toStringAsFixed(3)}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: CustomPaint(
                painter: ProbeChartPainter(probe, repaint: controller.frame),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
