import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/simulation_controller.dart';
import '../services/scene_storage_service.dart';
import '../utils/constants.dart';
import '../widgets/control_panel.dart';
import '../widgets/menu_bar.dart';
import '../widgets/probe_card.dart';
import '../widgets/properties_panel.dart';
import '../widgets/simulation_canvas.dart';
import '../widgets/simulation_toolbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SimulationController _c = SimulationController();
  final SceneStorageService _storage = SceneStorageService();
  bool _panelOpen = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ));
  }

  // ------------------------------------------------------------ file menu
  Future<void> _onFileAction(FileAction a) async {
    switch (a) {
      case FileAction.newScene:
        _c.newScene();
        _toast('مشهد جديد');
      case FileAction.resetDefault:
        _c.resetDefault();
        _toast('تمت إعادة الإعدادات الافتراضية');
      case FileAction.save:
        await _saveScene();
      case FileAction.load:
        await _loadScene();
      case FileAction.exportJson:
        await Clipboard.setData(ClipboardData(
            text: SceneStorageService.encodePretty(_c.toSceneJson())));
        _toast('تم نسخ المشهد بصيغة JSON');
      case FileAction.importJson:
        await _importJson();
    }
  }

  Future<void> _saveScene() async {
    final name = await showTextInputDialog(
      context,
      title: 'حفظ المشهد',
      hint: 'اسم المشهد',
      initial: 'مشهد ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
    );
    if (name == null || name.trim().isEmpty) return;
    await _storage.saveScene(name.trim(), _c.toSceneJson());
    _toast('تم حفظ "${name.trim()}"');
  }

  Future<void> _loadScene() async {
    final names = await _storage.listScenes();
    if (!mounted) return;
    if (names.isEmpty) {
      _toast('لا توجد مشاهد محفوظة بعد');
      return;
    }
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => _SceneListSheet(names: names, storage: _storage),
    );
    if (chosen == null) return;
    final scene = await _storage.loadScene(chosen);
    if (scene == null) {
      _toast('تعذّر فتح المشهد');
      return;
    }
    _c.loadSceneJson(scene);
    _toast('تم فتح "$chosen"');
  }

  Future<void> _importJson() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final scene = SceneStorageService.tryDecode(data?.text ?? '');
    if (scene == null) {
      _toast('الحافظة لا تحتوي على مشهد JSON صالح');
      return;
    }
    _c.loadSceneJson(scene);
    _toast('تم استيراد المشهد');
  }

  // --------------------------------------------------------------- layout
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [AppColors.accent, AppColors.accent2, AppColors.bg],
                  stops: [0.15, 0.55, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.5),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Icon(Icons.waves_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ripple Tank',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('محاكي حوض الأمواج • by Muhaymin',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ],
            ),
          ],
        ),
        actions: [
          ListenableBuilder(
            listenable: _c,
            builder: (context, _) => IconButton(
              tooltip: _c.playing ? 'إيقاف (Pause)' : 'تشغيل (Play)',
              onPressed: _c.togglePlay,
              icon: Icon(_c.playing
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded),
              color: AppColors.accent,
              iconSize: 30,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => LayoutBuilder(
            builder: (context, cons) {
              final landscape = cons.maxWidth > cons.maxHeight * 1.1;
              return landscape ? _landscape(cons) : _portrait();
            },
          ),
        ),
      ),
    );
  }

  Widget _menuBar() => SimulationMenuBar(
        controller: _c,
        onFileAction: _onFileAction,
        onMessage: _toast,
      );

  Widget _probes() => _c.probes.isEmpty
      ? const SizedBox.shrink()
      : SizedBox(
          height: 108,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            children: [
              for (final p in _c.probes)
                ProbeCard(
                    key: ValueKey('probe-${p.id}'), controller: _c, probe: p),
            ],
          ),
        );

  Widget _hint() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Text(
          _c.is3D ? 'العرض ثلاثي الأبعاد' : _c.tool.hint,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
        ),
      );

  Widget _controls() => ControlPanel(
        controller: _c,
        expanded: _panelOpen,
        onToggle: () => setState(() => _panelOpen = !_panelOpen),
      );

  Widget _portrait() {
    return Column(
      children: [
        _menuBar(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: SimulationCanvas(controller: _c),
          ),
        ),
        _hint(),
        SimulationToolbar(controller: _c),
        _probes(),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.42,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_c.selected != null) ...[
                    PropertiesPanel(controller: _c),
                    const SizedBox(height: 6),
                  ],
                  _controls(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _landscape(BoxConstraints cons) {
    final sideWidth = cons.maxWidth < 900 ? 330.0 : 380.0;
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SimulationCanvas(controller: _c),
          ),
        ),
        SizedBox(
          width: sideWidth,
          child: Column(
            children: [
              _menuBar(),
              SimulationToolbar(controller: _c),
              _hint(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(4, 4, 8, 8),
                  children: [
                    _probes(),
                    if (_c.selected != null) ...[
                      PropertiesPanel(controller: _c),
                      const SizedBox(height: 6),
                    ],
                    ControlPanel(
                      controller: _c,
                      expanded: true,
                      onToggle: () => setState(() => _panelOpen = !_panelOpen),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SceneListSheet extends StatefulWidget {
  const _SceneListSheet({required this.names, required this.storage});

  final List<String> names;
  final SceneStorageService storage;

  @override
  State<_SceneListSheet> createState() => _SceneListSheetState();
}

class _SceneListSheetState extends State<_SceneListSheet> {
  late final List<String> _names = List.of(widget.names);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('المشاهد المحفوظة',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final n in _names)
                  ListTile(
                    leading: const Icon(Icons.waves_rounded,
                        color: AppColors.accent),
                    title: Text(n),
                    onTap: () => Navigator.of(context).pop(n),
                    trailing: IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger),
                      onPressed: () async {
                        await widget.storage.deleteScene(n);
                        if (!mounted) return;
                        setState(() => _names.remove(n));
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
