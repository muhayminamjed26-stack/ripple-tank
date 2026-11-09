import 'package:flutter/material.dart';

import '../controllers/simulation_controller.dart';
import '../models/medium_object.dart';
import '../models/obstacle_object.dart';
import '../models/wave_source.dart';
import '../utils/constants.dart';

IconData toolIcon(ToolMode t) => switch (t) {
      ToolMode.move => Icons.open_with_rounded,
      ToolMode.ripple => Icons.water_drop_outlined,
      ToolMode.addSource => Icons.wifi_tethering_rounded,
      ToolMode.drawWall => Icons.view_week_outlined,
      ToolMode.drawMedium => Icons.lens_outlined,
      ToolMode.addProbe => Icons.sensors_rounded,
      ToolMode.addText => Icons.text_fields_rounded,
    };

/// شريط الأدوات: أزرار كبيرة للمس. أدوات المصدر والعائق والوسط تفتح قائمة
/// لاختيار النوع.
class SimulationToolbar extends StatelessWidget {
  const SimulationToolbar({super.key, required this.controller});

  final SimulationController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        children: [
          _chip(ToolMode.move, ToolMode.move.label),
          _chip(ToolMode.ripple, ToolMode.ripple.label),
          PopupMenuButton<SourceType>(
            tooltip: 'نوع المصدر',
            onSelected: c.chooseSourceType,
            itemBuilder: (_) => [
              for (final t in SourceType.values)
                PopupMenuItem(value: t, child: Text(t.label)),
            ],
            child: _ToolChipVisual(
              icon: toolIcon(ToolMode.addSource),
              label: 'مصدر: ${c.pendingSourceType.shortLabel}',
              selected: c.tool == ToolMode.addSource,
              dropdown: true,
            ),
          ),
          PopupMenuButton<ObstacleType>(
            tooltip: 'نوع العائق',
            onSelected: c.chooseObstacleType,
            itemBuilder: (_) => [
              for (final t in ObstacleType.values)
                PopupMenuItem(value: t, child: Text(t.label)),
            ],
            child: _ToolChipVisual(
              icon: toolIcon(ToolMode.drawWall),
              label: c.pendingObstacleType.shortLabel,
              selected: c.tool == ToolMode.drawWall,
              dropdown: true,
            ),
          ),
          PopupMenuButton<MediumType>(
            tooltip: 'نوع الوسط',
            onSelected: c.chooseMediumType,
            itemBuilder: (_) => [
              for (final t in MediumType.values)
                PopupMenuItem(value: t, child: Text(t.label)),
            ],
            child: _ToolChipVisual(
              icon: toolIcon(ToolMode.drawMedium),
              label: c.pendingMediumType.shortLabel,
              selected: c.tool == ToolMode.drawMedium,
              dropdown: true,
            ),
          ),
          _chip(ToolMode.addProbe, ToolMode.addProbe.label),
          _chip(ToolMode.addText, ToolMode.addText.label),
        ],
      ),
    );
  }

  Widget _chip(ToolMode t, String label) => InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => controller.setTool(t),
        child: _ToolChipVisual(
          icon: toolIcon(t),
          label: label,
          selected: controller.tool == t,
        ),
      );
}

class _ToolChipVisual extends StatelessWidget {
  const _ToolChipVisual({
    required this.icon,
    required this.label,
    required this.selected,
    this.dropdown = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool dropdown;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.black : AppColors.text;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: selected ? AppColors.accent : AppColors.surface2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 19, color: fg),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 13, fontWeight: FontWeight.w600)),
          if (dropdown) Icon(Icons.arrow_drop_down, size: 18, color: fg),
        ],
      ),
    );
  }
}
