import 'package:flutter/material.dart';

import '../controllers/simulation_controller.dart';
import '../models/medium_object.dart';
import '../models/obstacle_object.dart';
import '../models/wave_source.dart';
import '../utils/constants.dart';

enum FileAction { newScene, resetDefault, save, load, exportJson, importJson }

enum EditAction { clearWaves, clearWalls, clearMedia, clearProbes, clearAll }

/// شريط القوائم: ملف، تحرير، إضافة، تجارب.
class SimulationMenuBar extends StatelessWidget {
  const SimulationMenuBar({
    super.key,
    required this.controller,
    required this.onFileAction,
    required this.onMessage,
  });

  final SimulationController controller;
  final ValueChanged<FileAction> onFileAction;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _menu<FileAction>(
            icon: Icons.folder_open_rounded,
            label: 'ملف',
            onSelected: onFileAction,
            items: const [
              (FileAction.newScene, 'مشهد جديد (New Scene)', Icons.note_add_outlined),
              (FileAction.resetDefault, 'الإعدادات الافتراضية (Reset Default)', Icons.restart_alt_rounded),
              (FileAction.save, 'حفظ المشهد (Save Scene)', Icons.save_outlined),
              (FileAction.load, 'فتح مشهد (Load Scene)', Icons.folder_outlined),
              (FileAction.exportJson, 'نسخ JSON', Icons.copy_rounded),
              (FileAction.importJson, 'لصق JSON', Icons.paste_rounded),
            ],
          ),
          _menu<EditAction>(
            icon: Icons.cleaning_services_outlined,
            label: 'تحرير',
            onSelected: (a) {
              switch (a) {
                case EditAction.clearWaves:
                  c.clearWaves();
                case EditAction.clearWalls:
                  c.clearWalls();
                case EditAction.clearMedia:
                  c.clearMedia();
                case EditAction.clearProbes:
                  c.clearProbes();
                case EditAction.clearAll:
                  c.clearAll();
              }
            },
            items: const [
              (EditAction.clearWaves, 'مسح الأمواج (Clear Waves)', Icons.waves_rounded),
              (EditAction.clearWalls, 'مسح العوائق (Clear Walls)', Icons.view_week_outlined),
              (EditAction.clearMedia, 'مسح الأوساط (Clear Media)', Icons.lens_outlined),
              (EditAction.clearProbes, 'مسح المجسات (Clear Probes)', Icons.sensors_off_rounded),
              (EditAction.clearAll, 'مسح الكل (Clear All)', Icons.delete_sweep_outlined),
            ],
          ),
          _addMenu(context),
          _menu<Preset>(
            icon: Icons.science_outlined,
            label: 'تجارب',
            onSelected: (p) {
              c.loadPreset(p);
              onMessage(p.label);
            },
            items: [
              for (final p in Preset.values) (p, p.label, Icons.science_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _addMenu(BuildContext context) {
    final c = controller;
    PopupMenuEntry<String> header(String t) => PopupMenuItem<String>(
          enabled: false,
          height: 30,
          child: Text(t,
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        );
    PopupMenuEntry<String> item(String v, String t) =>
        PopupMenuItem<String>(value: v, child: Text(t));

    return PopupMenuButton<String>(
      tooltip: 'إضافة',
      onSelected: (v) {
        final parts = v.split(':');
        switch (parts.first) {
          case 'src':
            final t = SourceType.values.byName(parts[1]);
            c.chooseSourceType(t);
            onMessage('${t.label}: ${ToolMode.addSource.hint}');
          case 'obs':
            final t = ObstacleType.values.byName(parts[1]);
            c.chooseObstacleType(t);
            onMessage('${t.label}: ${ToolMode.drawWall.hint}');
          case 'med':
            final t = MediumType.values.byName(parts[1]);
            c.chooseMediumType(t);
            onMessage('${t.label}: ${ToolMode.drawMedium.hint}');
          case 'probe':
            c.setTool(ToolMode.addProbe);
            onMessage(ToolMode.addProbe.hint);
          case 'text':
            c.setTool(ToolMode.addText);
            onMessage(ToolMode.addText.hint);
        }
      },
      itemBuilder: (_) => [
        header('المصادر (Sources)'),
        for (final t in SourceType.values) item('src:${t.name}', t.label),
        const PopupMenuDivider(),
        header('الجدران والعوائق (Walls & Obstacles)'),
        for (final t in ObstacleType.values) item('obs:${t.name}', t.label),
        const PopupMenuDivider(),
        header('الأوساط (Media)'),
        for (final t in MediumType.values) item('med:${t.name}', t.label),
        const PopupMenuDivider(),
        header('القياس (Measurement)'),
        item('probe', 'مجس قياس (Wave Probe)'),
        const PopupMenuDivider(),
        header('التوضيحات (Annotations)'),
        item('text', 'ملاحظة نصية (Text)'),
      ],
      child: const _MenuChip(icon: Icons.add_circle_outline_rounded, label: 'إضافة'),
    );
  }

  Widget _menu<T>({
    required IconData icon,
    required String label,
    required ValueChanged<T> onSelected,
    required List<(T, String, IconData)> items,
  }) {
    return PopupMenuButton<T>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final it in items)
          PopupMenuItem<T>(
            value: it.$1,
            child: Row(
              children: [
                Icon(it.$3, size: 20, color: AppColors.accent),
                const SizedBox(width: 10),
                Flexible(child: Text(it.$2)),
              ],
            ),
          ),
      ],
      child: _MenuChip(icon: icon, label: label),
    );
  }
}

class _MenuChip extends StatelessWidget {
  const _MenuChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        color: AppColors.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
