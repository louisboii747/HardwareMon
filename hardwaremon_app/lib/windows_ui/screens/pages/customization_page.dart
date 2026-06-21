import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_controller.dart';
import '../../models/chart_preferences.dart';
import '../../models/customization_preferences.dart';
import '../../models/dashboard_preferences.dart';
import '../../models/telemetry_sample.dart';
import '../../services/telemetry_service.dart';

class CustomizationPage extends StatefulWidget {
  final TelemetryService telemetry;
  final ChartPreferences chartPreferences;
  final DashboardPreferences dashboardPreferences;
  final CustomizationPreferences customizationPreferences;

  const CustomizationPage({
    super.key,
    required this.telemetry,
    required this.chartPreferences,
    required this.dashboardPreferences,
    required this.customizationPreferences,
  });

  @override
  State<CustomizationPage> createState() => _CustomizationPageState();
}

class _CustomizationPageState extends State<CustomizationPage> {
  @override
  Widget build(BuildContext context) {
    final listenables = Listenable.merge([
      widget.chartPreferences,
      widget.dashboardPreferences,
      widget.customizationPreferences,
      AppThemeController.instance,
    ]);

    return AnimatedBuilder(
      animation: listenables,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1040;
          final editor = _StudioEditor(
            telemetry: widget.telemetry,
            charts: widget.chartPreferences,
            dashboard: widget.dashboardPreferences,
            customization: widget.customizationPreferences,
          );
          final preview = _LivePreviewPanel(
            telemetry: widget.telemetry,
            charts: widget.chartPreferences,
            dashboard: widget.dashboardPreferences,
            customization: widget.customizationPreferences,
          );

          if (!wide) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StudioHeader(
                    customization: widget.customizationPreferences,
                    dashboard: widget.dashboardPreferences,
                    charts: widget.chartPreferences,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(height: 530, child: preview),
                  const SizedBox(height: 18),
                  editor,
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StudioHeader(
                customization: widget.customizationPreferences,
                dashboard: widget.dashboardPreferences,
                charts: widget.chartPreferences,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 30, right: 8),
                        child: editor,
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(flex: 4, child: preview),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudioHeader extends StatelessWidget {
  final CustomizationPreferences customization;
  final DashboardPreferences dashboard;
  final ChartPreferences charts;

  const _StudioHeader({
    required this.customization,
    required this.dashboard,
    required this.charts,
  });

  Future<void> _reset(BuildContext context) async {
    await Future.wait([
      dashboard.resetDefaults(),
      charts.resetDefaults(),
      customization.resetStudioDefaults(),
      AppThemeController.instance.setThemeAndPersist('Dark'),
      AppThemeController.instance.setAccent(const Color(0xFF0891B2)),
    ]);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Customization defaults restored')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = customization.profiles
        .where((profile) => profile.id == customization.activeProfileId)
        .firstOrNull;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Customization',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                active == null
                    ? 'Design your HardwareMon workspace in real time.'
                    : '${active.name} profile · Live changes are active',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _reset(context),
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: const Text('Reset studio'),
        ),
      ],
    );
  }
}

class _StudioEditor extends StatelessWidget {
  final TelemetryService telemetry;
  final ChartPreferences charts;
  final DashboardPreferences dashboard;
  final CustomizationPreferences customization;

  const _StudioEditor({
    required this.telemetry,
    required this.charts,
    required this.dashboard,
    required this.customization,
  });

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      _DashboardLayoutSection(dashboard: dashboard),
      _ThemeStudioSection(),
      _SidebarStudioSection(customization: customization),
      _GraphStudioSection(charts: charts, telemetry: telemetry),
      _AnimationStudioSection(customization: customization, charts: charts),
      _WidgetManagementSection(customization: customization),
      _ProfilesSection(
        customization: customization,
        dashboard: dashboard,
        charts: charts,
      ),
    ];
    return Column(
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          sections[index]
              .animate()
              .fadeIn(
                delay: Duration(milliseconds: index * 55),
                duration: 360.ms,
              )
              .slideY(
                begin: 0.025,
                end: 0,
                delay: Duration(milliseconds: index * 55),
                duration: 360.ms,
              ),
          if (index != sections.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _DashboardLayoutSection extends StatelessWidget {
  final DashboardPreferences dashboard;

  const _DashboardLayoutSection({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    return _StudioSection(
      icon: Icons.dashboard_customize_rounded,
      color: Colors.cyan,
      title: 'Dashboard Layout Editor',
      subtitle: 'Drag cards, hide modules, and tune information density.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SegmentedChoice<DashboardCardSize>(
            values: DashboardCardSize.values,
            selected: dashboard.cardSize,
            label: (value) => value.label,
            onSelected: dashboard.setCardSize,
          ),
          const SizedBox(height: 16),
          Container(
            height: 330,
            decoration: BoxDecoration(
              color: AppColors.overlay(context, 0.025),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              buildDefaultDragHandles: false,
              itemCount: dashboard.cardOrder.length,
              // ignore: deprecated_member_use
              onReorder: dashboard.reorderCard,
              itemBuilder: (context, index) {
                final id = dashboard.cardOrder[index];
                final visible = !dashboard.hiddenCards.contains(id);
                return _ReorderRow(
                  key: ValueKey(id),
                  index: index,
                  icon: _metricIcon(id),
                  title: id.label,
                  subtitle: visible ? 'Visible on supported layouts' : 'Hidden',
                  enabled: visible,
                  onEnabled: (value) => dashboard.setCardVisible(id, value),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '${dashboard.cardOrder.length - dashboard.hiddenCards.length} visible · ${dashboard.hiddenCards.length} hidden',
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await dashboard.applySnapshot(
                    order: dashboard.cardOrder,
                    hidden: dashboard.hiddenCards,
                    size: dashboard.cardSize,
                  );
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dashboard layout saved')),
                  );
                },
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save layout'),
              ),
              const SizedBox(width: 6),
              TextButton.icon(
                onPressed: dashboard.resetDefaults,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Reset layout'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThemeStudioSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = AppThemeController.instance;
    const accents = [
      ('HardwareMon Cyan', Color(0xFF0891B2)),
      ('Blue', Color(0xFF3B82F6)),
      ('Purple', Color(0xFF8B5CF6)),
      ('Green', Color(0xFF10B981)),
      ('Orange', Color(0xFFF97316)),
      ('Red', Color(0xFFEF4444)),
    ];

    return _StudioSection(
      icon: Icons.palette_rounded,
      color: Colors.purpleAccent,
      title: 'Theme Studio',
      subtitle: 'Choose the canvas, then shape HardwareMon’s visual voice.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final mode in ['Dark', 'Light', 'System']) ...[
                Expanded(
                  child: _ThemeModeCard(
                    label: mode,
                    selected: controller.theme == mode,
                    onTap: () => controller.setThemeAndPersist(mode),
                  ),
                ),
                if (mode != 'System') const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Accent color',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final accent in accents)
                _AccentSwatch(
                  label: accent.$1,
                  color: accent.$2,
                  selected:
                      controller.accent.toARGB32() == accent.$2.toARGB32(),
                  onTap: () => controller.setAccent(accent.$2),
                ),
              _AccentSwatch(
                label: 'Custom',
                color: controller.accent,
                selected: !accents.any(
                  (item) => item.$2.toARGB32() == controller.accent.toARGB32(),
                ),
                custom: true,
                onTap: () => _showColorPicker(context, controller),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showColorPicker(
    BuildContext context,
    AppThemeController controller,
  ) async {
    var red = controller.accent.r * 255;
    var green = controller.accent.g * 255;
    var blue = controller.accent.b * 255;
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final color = Color.fromARGB(
            255,
            red.round(),
            green.round(),
            blue.round(),
          );
          Widget slider(String label, double value, ValueChanged<double> set) {
            return Row(
              children: [
                SizedBox(width: 18, child: Text(label)),
                Expanded(
                  child: Slider(
                    value: value,
                    min: 0,
                    max: 255,
                    onChanged: (next) => setDialogState(() => set(next)),
                  ),
                ),
                SizedBox(width: 30, child: Text(value.round().toString())),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Custom accent'),
            content: SizedBox(
              width: 390,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 80,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.35),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  slider('R', red, (value) => red = value),
                  slider('G', green, (value) => green = value),
                  slider('B', blue, (value) => blue = value),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, color),
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
    if (selected != null) await controller.setAccent(selected);
  }
}

class _SidebarStudioSection extends StatelessWidget {
  final CustomizationPreferences customization;

  const _SidebarStudioSection({required this.customization});

  @override
  Widget build(BuildContext context) {
    return _StudioSection(
      icon: Icons.view_sidebar_rounded,
      color: Colors.blueAccent,
      title: 'Sidebar Customization',
      subtitle: 'Control density, labels, icon scale, and navigation motion.',
      child: Column(
        children: [
          _SegmentedChoice<SidebarMode>(
            values: SidebarMode.values,
            selected: customization.sidebarMode,
            label: (value) => value.label,
            onSelected: customization.setSidebarMode,
          ),
          const SizedBox(height: 14),
          _ControlRow(
            title: 'Show labels',
            subtitle: 'Keep page names visible beside navigation icons',
            trailing: Switch(
              value: customization.showSidebarLabels,
              onChanged: customization.setShowSidebarLabels,
            ),
          ),
          _SliderControl(
            label: 'Icon size',
            value: customization.sidebarIconSize,
            min: 18,
            max: 34,
            valueLabel: '${customization.sidebarIconSize.round()} px',
            onChanged: customization.setSidebarIconSize,
          ),
          _SliderControl(
            label: 'Animation intensity',
            value: customization.sidebarAnimationIntensity,
            min: 0,
            max: 1.5,
            valueLabel:
                '${(customization.sidebarAnimationIntensity * 100).round()}%',
            onChanged: customization.setSidebarAnimationIntensity,
          ),
        ],
      ),
    );
  }
}

class _GraphStudioSection extends StatelessWidget {
  final ChartPreferences charts;
  final TelemetryService telemetry;

  const _GraphStudioSection({required this.charts, required this.telemetry});

  @override
  Widget build(BuildContext context) {
    final samples = telemetry.cpuHistory.length >= 3
        ? telemetry.cpuHistory
        : _demoSamples();
    return _StudioSection(
      icon: Icons.show_chart_rounded,
      color: Colors.greenAccent,
      title: 'Graph Customization',
      subtitle: 'Fine-tune graph geometry, rhythm, and information density.',
      child: Column(
        children: [
          Container(
            height: 150,
            padding: const EdgeInsets.fromLTRB(12, 16, 18, 8),
            decoration: BoxDecoration(
              color: AppColors.overlay(context, 0.025),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: _GraphPreview(samples: samples, charts: charts),
          ),
          const SizedBox(height: 14),
          _SliderControl(
            label: 'Graph smoothness',
            value: charts.smoothness,
            min: 0,
            max: 0.55,
            valueLabel: charts.smoothness < 0.03
                ? 'Angular'
                : '${(charts.smoothness * 100).round()}%',
            onChanged: charts.setSmoothness,
          ),
          _SliderControl(
            label: 'Graph thickness',
            value: charts.thickness,
            min: 1,
            max: 5,
            valueLabel: '${charts.thickness.toStringAsFixed(1)} px',
            onChanged: charts.setThickness,
          ),
          _SliderControl(
            label: 'Timeline density',
            value: charts.timelineDensity,
            min: 0.55,
            max: 1.8,
            valueLabel: '${(charts.timelineDensity * 100).round()}%',
            onChanged: charts.setTimelineDensity,
          ),
          _ControlRow(
            title: 'Grid visibility',
            subtitle: 'Show horizontal and vertical chart guides',
            trailing: Switch(
              value: charts.gridLines,
              onChanged: (value) =>
                  charts.setPreference(ChartPreference.gridLines, value),
            ),
          ),
          _ControlRow(
            title: 'Area fill',
            subtitle: 'Add a soft accent gradient beneath graph lines',
            trailing: Switch(
              value: charts.areaFill,
              onChanged: (value) =>
                  charts.setPreference(ChartPreference.areaFill, value),
            ),
          ),
          const SizedBox(height: 8),
          _SegmentedChoice<GraphAnimationSpeed>(
            values: GraphAnimationSpeed.values,
            selected: charts.animationSpeed,
            label: (value) => value.label,
            onSelected: charts.setAnimationSpeed,
          ),
        ],
      ),
    );
  }
}

class _AnimationStudioSection extends StatelessWidget {
  final CustomizationPreferences customization;
  final ChartPreferences charts;

  const _AnimationStudioSection({
    required this.customization,
    required this.charts,
  });

  @override
  Widget build(BuildContext context) {
    return _StudioSection(
      icon: Icons.animation_rounded,
      color: Colors.orange,
      title: 'Animation Studio',
      subtitle: 'Set the personality and pace of the entire interface.',
      child: Column(
        children: [
          Row(
            children: [
              for (final level in MotionLevel.values) ...[
                Expanded(
                  child: _MotionCard(
                    level: level,
                    selected: customization.motionLevel == level,
                    onTap: () => customization.setMotionLevel(level),
                  ),
                ),
                if (level != MotionLevel.values.last) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 14),
          _SliderControl(
            label: 'Transition speed',
            value: customization.transitionSpeed,
            min: 0.6,
            max: 1.8,
            valueLabel: '${customization.transitionSpeed.toStringAsFixed(1)}×',
            onChanged: customization.setTransitionSpeed,
          ),
          _SliderControl(
            label: 'Ambient glow intensity',
            value: customization.ambientGlowIntensity,
            min: 0,
            max: 1.5,
            valueLabel:
                '${(customization.ambientGlowIntensity * 100).round()}%',
            onChanged: customization.setAmbientGlowIntensity,
          ),
          _ControlRow(
            title: 'Hover effects',
            subtitle: 'Lift cards and illuminate interactive controls',
            trailing: Switch(
              value: customization.hoverEffects,
              onChanged: customization.setHoverEffects,
            ),
          ),
          _ControlRow(
            title: 'Graph animations',
            subtitle: 'Interpolate new telemetry samples smoothly',
            trailing: Switch(
              value: charts.animations,
              onChanged: (value) =>
                  charts.setPreference(ChartPreference.animations, value),
            ),
          ),
        ],
      ),
    );
  }
}

class _WidgetManagementSection extends StatelessWidget {
  final CustomizationPreferences customization;

  const _WidgetManagementSection({required this.customization});

  @override
  Widget build(BuildContext context) {
    return _StudioSection(
      icon: Icons.widgets_rounded,
      color: Colors.pinkAccent,
      title: 'Widget Management',
      subtitle: 'Prepare and arrange modules for future dashboard surfaces.',
      child: SizedBox(
        height: 350,
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          itemCount: customization.widgetOrder.length,
          // ignore: deprecated_member_use
          onReorder: customization.reorderWidget,
          itemBuilder: (context, index) {
            final id = customization.widgetOrder[index];
            final enabled = customization.enabledWidgets.contains(id);
            return _ReorderRow(
              key: ValueKey(id),
              index: index,
              icon: _widgetIcon(id),
              title: id.label,
              subtitle: enabled ? 'Enabled architecture' : 'Disabled',
              enabled: enabled,
              onEnabled: (value) => customization.setWidgetEnabled(id, value),
            );
          },
        ),
      ),
    );
  }
}

class _ProfilesSection extends StatelessWidget {
  final CustomizationPreferences customization;
  final DashboardPreferences dashboard;
  final ChartPreferences charts;

  const _ProfilesSection({
    required this.customization,
    required this.dashboard,
    required this.charts,
  });

  Future<String?> _ask(
    BuildContext context, {
    required String title,
    String initial = '',
    String hint = '',
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: initial);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: maxLines == 1
              ? (_) => Navigator.pop(context, controller.text)
              : null,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _create(BuildContext context) async {
    final name = await _ask(
      context,
      title: 'Create customization profile',
      hint: 'Gaming, Productivity, Monitoring Wall…',
    );
    if (name == null || name.trim().isEmpty) return;
    await customization.createProfile(
      name: name,
      dashboard: dashboard,
      charts: charts,
    );
  }

  Future<void> _import(BuildContext context) async {
    final source = await _ask(
      context,
      title: 'Import profile JSON',
      hint: 'Paste a HardwareMon profile here',
      maxLines: 12,
    );
    if (source == null || source.trim().isEmpty) return;
    try {
      final profile = await customization.importProfile(source);
      await customization.applyProfile(
        profile,
        dashboard: dashboard,
        charts: charts,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Profile import failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StudioSection(
      icon: Icons.layers_rounded,
      color: Colors.amber,
      title: 'Profiles',
      subtitle: 'Capture, switch, export, and share complete studio setups.',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Import profile',
            onPressed: () => _import(context),
            icon: const Icon(Icons.file_download_outlined),
          ),
          FilledButton.icon(
            onPressed: () => _create(context),
            icon: const Icon(Icons.add_rounded, size: 17),
            label: const Text('Create'),
          ),
        ],
      ),
      child: customization.profiles.isEmpty
          ? _EmptyProfiles(onCreate: () => _create(context))
          : Column(
              children: [
                for (final profile in customization.profiles)
                  _ProfileTile(
                    profile: profile,
                    active: profile.id == customization.activeProfileId,
                    onApply: () => customization.applyProfile(
                      profile,
                      dashboard: dashboard,
                      charts: charts,
                    ),
                    onSave: () => customization.updateProfile(
                      profile.id,
                      dashboard: dashboard,
                      charts: charts,
                    ),
                    onRename: () async {
                      final name = await _ask(
                        context,
                        title: 'Rename profile',
                        initial: profile.name,
                      );
                      if (name?.trim().isNotEmpty == true) {
                        await customization.renameProfile(profile.id, name!);
                      }
                    },
                    onDelete: () => customization.deleteProfile(profile.id),
                    onExport: () async {
                      final path = await customization.exportProfile(profile);
                      await Clipboard.setData(ClipboardData(text: path));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Profile exported. Path copied:\n$path',
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

class _LivePreviewPanel extends StatelessWidget {
  final TelemetryService telemetry;
  final ChartPreferences charts;
  final DashboardPreferences dashboard;
  final CustomizationPreferences customization;

  const _LivePreviewPanel({
    required this.telemetry,
    required this.charts,
    required this.dashboard,
    required this.customization,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppThemeController.instance.accent;
    final samples = telemetry.cpuHistory.length >= 3
        ? telemetry.cpuHistory
        : _demoSamples();
    final labels =
        customization.showSidebarLabels ||
        customization.sidebarMode == SidebarMode.expanded;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(
              alpha: 0.12 * customization.ambientGlowIntensity,
            ),
            blurRadius: 36 * customization.ambientGlowIntensity,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              top: -70,
              right: -40,
              child: AnimatedContainer(
                duration: customization.transitionDuration,
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(
                    alpha: 0.12 * customization.ambientGlowIntensity,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          'LIVE PREVIEW',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        dashboard.cardSize.label,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.background(context),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: customization.transitionDuration,
                            width: labels ? 112 : 54,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface(context),
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(18),
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.memory_rounded,
                                  color: accent,
                                  size: customization.sidebarIconSize * 0.75,
                                ),
                                const SizedBox(height: 18),
                                for (final item in [
                                  ('Dashboard', Icons.dashboard_rounded),
                                  ('Performance', Icons.analytics_rounded),
                                  ('Storage', Icons.storage_rounded),
                                  ('Customize', Icons.palette_rounded),
                                ])
                                  _PreviewDockItem(
                                    label: item.$1,
                                    icon: item.$2,
                                    selected: item.$1 == 'Customize',
                                    showLabel: labels,
                                    iconSize:
                                        customization.sidebarIconSize * 0.68,
                                    accent: accent,
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'HardwareMon',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Expanded(
                                    flex:
                                        dashboard.cardSize ==
                                            DashboardCardSize.expanded
                                        ? 5
                                        : dashboard.cardSize ==
                                              DashboardCardSize.compact
                                        ? 3
                                        : 4,
                                    child: _PreviewMetricCard(
                                      title: 'CPU Usage',
                                      value: '${telemetry.cpuUsage}%',
                                      accent: accent,
                                      samples: samples,
                                      charts: charts,
                                      customization: customization,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _PreviewHealthCard(
                                            accent: Colors.greenAccent,
                                            value: '86',
                                            title: 'Health',
                                          ),
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: _PreviewRecommendationCard(
                                            accent: accent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _PreviewLegend(
                        color: accent,
                        label: AppThemeController.instance.theme,
                      ),
                      const SizedBox(width: 8),
                      _PreviewLegend(
                        color: Colors.purpleAccent,
                        label: customization.motionLevel.label,
                      ),
                      const Spacer(),
                      Icon(
                        customization.hoverEffects
                            ? Icons.auto_awesome_rounded
                            : Icons.motion_photos_off_rounded,
                        size: 16,
                        color: accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudioSection extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _StudioSection({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  State<_StudioSection> createState() => _StudioSectionState();
}

class _StudioSectionState extends State<_StudioSection> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, hovering ? -2 : 0, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: hovering
                ? widget.color.withValues(alpha: 0.3)
                : AppColors.border(context),
          ),
          boxShadow: [
            BoxShadow(
              color: hovering
                  ? widget.color.withValues(alpha: 0.07)
                  : AppColors.shadow(context),
              blurRadius: hovering ? 28 : 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(widget.icon, color: widget.color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
            const SizedBox(height: 18),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _SegmentedChoice<T> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T value) label;
  final ValueChanged<T> onSelected;

  const _SegmentedChoice({
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<T>(
        segments: [
          for (final value in values)
            ButtonSegment(value: value, label: Text(label(value))),
        ],
        selected: {selected},
        onSelectionChanged: (selection) => onSelected(selection.first),
      ),
    );
  }
}

class _ReorderRow extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final ValueChanged<bool> onEnabled;

  const _ReorderRow({
    super.key,
    required this.index,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: index,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Icon(
              Icons.drag_indicator_rounded,
              color: AppColors.textMuted(context),
            ),
          ),
        ),
        title: Row(
          children: [
            Icon(icon, size: 17, color: AppColors.accent),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(left: 26, top: 2),
          child: Text(
            subtitle,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 9,
            ),
          ),
        ),
        trailing: Switch(value: enabled, onChanged: onEnabled),
      ),
    );
  }
}

class _ThemeModeCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = label == 'Dark';
    final system = label == 'System';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.overlay(context, 0.025),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border(context),
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 55,
              decoration: BoxDecoration(
                color: system
                    ? null
                    : dark
                    ? const Color(0xFF0A0A0A)
                    : const Color(0xFFF7F9FC),
                gradient: system
                    ? const LinearGradient(
                        colors: [Color(0xFF0A0A0A), Color(0xFFF7F9FC)],
                      )
                    : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  system
                      ? Icons.brightness_auto_rounded
                      : dark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: system || dark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final bool custom;
  final VoidCallback onTap;

  const _AccentSwatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.custom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: selected
                  ? AppColors.textPrimary(context)
                  : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: selected ? 0.45 : 0.18),
                blurRadius: selected ? 18 : 8,
              ),
            ],
          ),
          child: custom
              ? const Icon(
                  Icons.colorize_rounded,
                  size: 17,
                  color: Colors.white,
                )
              : selected
              ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;

  const _ControlRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _SliderControl extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _SliderControl({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                valueLabel,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          Slider(value: value, min: min, max: max, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _MotionCard extends StatelessWidget {
  final MotionLevel level;
  final bool selected;
  final VoidCallback onTap;

  const _MotionCard({
    required this.level,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.1)
              : AppColors.overlay(context, 0.025),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border(context),
          ),
        ),
        child: Column(
          children: [
            Icon(
              level == MotionLevel.minimal
                  ? Icons.horizontal_rule_rounded
                  : level == MotionLevel.balanced
                  ? Icons.motion_photos_on_rounded
                  : Icons.auto_awesome_rounded,
              color: selected
                  ? AppColors.accent
                  : AppColors.textSecondary(context),
            ),
            const SizedBox(height: 8),
            Text(
              level.label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              level.description,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary(context),
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final CustomizationProfile profile;
  final bool active;
  final VoidCallback onApply;
  final VoidCallback onSave;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onExport;

  const _ProfileTile({
    required this.profile,
    required this.active,
    required this.onApply,
    required this.onSave,
    required this.onRename,
    required this.onDelete,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? AppColors.accent.withValues(alpha: 0.08)
            : AppColors.overlay(context, 0.025),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? AppColors.accent : AppColors.border(context),
        ),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.layers_outlined,
            color: active ? AppColors.accent : AppColors.textMuted(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Updated ${profile.updatedAt.toLocal().toString().substring(0, 16)}',
                  style: TextStyle(
                    color: AppColors.textSecondary(context),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onApply, child: const Text('Apply')),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'save') onSave();
              if (value == 'rename') onRename();
              if (value == 'export') onExport();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'save', child: Text('Save current changes')),
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'export', child: Text('Export')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyProfiles extends StatelessWidget {
  final VoidCallback onCreate;

  const _EmptyProfiles({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.overlay(context, 0.025),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Icon(Icons.layers_clear_rounded, size: 30),
          const SizedBox(height: 8),
          const Text(
            'No saved profiles yet',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Capture the current theme, dashboard, graph, animation, and widget setup.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onCreate,
            child: const Text('Create profile'),
          ),
        ],
      ),
    );
  }
}

class _GraphPreview extends StatelessWidget {
  final List<TelemetrySample> samples;
  final ChartPreferences charts;

  const _GraphPreview({required this.samples, required this.charts});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: charts.gridLines,
          drawVerticalLine: true,
          horizontalInterval: 25,
          verticalInterval: math
              .max(1, samples.length / (5 * charts.timelineDensity))
              .toDouble(),
          getDrawingHorizontalLine: (_) =>
              FlLine(color: AppColors.border(context), strokeWidth: 1),
          getDrawingVerticalLine: (_) =>
              FlLine(color: AppColors.border(context), strokeWidth: 1),
        ),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < samples.length; index++)
                FlSpot(index.toDouble(), samples[index].value),
            ],
            isCurved: charts.smoothLines,
            curveSmoothness: charts.smoothness,
            preventCurveOverShooting: true,
            color: AppColors.accent,
            barWidth: charts.thickness,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: charts.areaFill,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.accent.withValues(alpha: 0.22),
                  AppColors.accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ],
      ),
      duration: charts.animationDuration,
      curve: Curves.easeOutCubic,
    );
  }
}

class _PreviewDockItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool showLabel;
  final double iconSize;
  final Color accent;

  const _PreviewDockItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.showLabel,
    required this.iconSize,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: showLabel ? 8 : 0, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisAlignment: showLabel
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: iconSize,
            color: selected ? accent : AppColors.textMuted(context),
          ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? accent : AppColors.textSecondary(context),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;
  final List<TelemetrySample> samples;
  final ChartPreferences charts;
  final CustomizationPreferences customization;

  const _PreviewMetricCard({
    required this.title,
    required this.value,
    required this.accent,
    required this.samples,
    required this.charts,
    required this.customization,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: customization.transitionDuration,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: 0.17)),
        boxShadow: customization.hoverEffects
            ? [
                BoxShadow(
                  color: accent.withValues(
                    alpha: 0.09 * customization.ambientGlowIntensity,
                  ),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.memory_rounded, color: accent, size: 15),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const Spacer(),
          Expanded(
            flex: 3,
            child: _GraphPreview(samples: samples, charts: charts),
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 8,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHealthCard extends StatelessWidget {
  final Color accent;
  final String value;
  final String title;

  const _PreviewHealthCard({
    required this.accent,
    required this.value,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 32,
            child: CircularProgressIndicator(
              value: 0.86,
              strokeWidth: 4,
              color: accent,
              backgroundColor: accent.withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textSecondary(context),
                  fontSize: 7,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewRecommendationCard extends StatelessWidget {
  final Color accent;

  const _PreviewRecommendationCard({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: accent, size: 14),
          const Spacer(),
          const Text(
            'Recommendation',
            style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700),
          ),
          Text(
            'System looks healthy',
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 7,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _PreviewLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textSecondary(context),
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

IconData _metricIcon(DashboardMetricId id) {
  return switch (id) {
    DashboardMetricId.cpuUsage => Icons.memory_rounded,
    DashboardMetricId.memory => Icons.storage_rounded,
    DashboardMetricId.gpuUsage => Icons.developer_board_rounded,
    DashboardMetricId.cpuTemperature => Icons.thermostat_rounded,
    DashboardMetricId.gpuTemperature => Icons.device_thermostat_rounded,
    DashboardMetricId.cpuPower => Icons.bolt_rounded,
    DashboardMetricId.gpuPower => Icons.electric_bolt_rounded,
  };
}

IconData _widgetIcon(CustomWidgetId id) {
  return switch (id) {
    CustomWidgetId.weather => Icons.cloud_rounded,
    CustomWidgetId.networkSummary => Icons.language_rounded,
    CustomWidgetId.hardwareHealth => Icons.health_and_safety_rounded,
    CustomWidgetId.activityFeed => Icons.dynamic_feed_rounded,
    CustomWidgetId.benchmarks => Icons.speed_rounded,
    CustomWidgetId.updates => Icons.system_update_alt_rounded,
  };
}

List<TelemetrySample> _demoSamples() {
  final now = DateTime.now();
  const values = [24.0, 31, 28, 43, 39, 52, 46, 61, 55, 68, 57, 63];
  return [
    for (var index = 0; index < values.length; index++)
      TelemetrySample(
        timestamp: now.subtract(Duration(seconds: (values.length - index) * 5)),
        value: values[index].toDouble(),
      ),
  ];
}
