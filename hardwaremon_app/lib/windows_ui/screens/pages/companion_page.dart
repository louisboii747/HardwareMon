import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../services/companion_service.dart';
import '../../services/telemetry_service.dart';
import '../../widgets/glass_panel.dart';

enum SnapshotLayout { compact, standard, social, minimal }

class CompanionPage extends StatefulWidget {
  const CompanionPage({
    super.key,
    required this.telemetry,
    required this.service,
  });

  final TelemetryService telemetry;
  final CompanionService service;

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  final _snapshotKey = GlobalKey();
  SnapshotLayout _layout = SnapshotLayout.standard;
  Color _accent = const Color(0xff5ce1c2);
  bool _branding = true;
  bool _inventory = true;
  bool _telemetry = true;
  bool _plugins = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
    if (widget.service.portableMode == null) {
      widget.service.initialise().catchError((Object error) {
        if (mounted) setState(() => _message = error.toString());
      });
    }
  }

  @override
  void dispose() {
    widget.service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _exportSnapshot() async {
    final boundary =
        _snapshotKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return;
    final path = await _saveBytes('snapshot', bytes.buffer.asUint8List());
    setState(() => _message = 'Snapshot exported to $path');
  }

  Future<String> _saveBytes(String name, Uint8List bytes) async {
    final directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}hardwaremon-$name-${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _toggleDashboard() async {
    if (widget.service.dashboardRunning) {
      await widget.service.stopDashboard();
      setState(() => _message = 'Local dashboard stopped');
    } else {
      final url = await widget.service.startDashboard();
      await Clipboard.setData(ClipboardData(text: url));
      setState(() => _message = 'Pairing link copied: $url');
    }
  }

  Future<void> _exportBundle() async {
    final path = await widget.service.exportBundle(
      includeInventory: _inventory,
      includeTelemetry: _telemetry,
      includePlugins: _plugins,
    );
    setState(() => _message = 'Export created at $path');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const PageStorageKey('companion-page'),
      padding: const EdgeInsets.only(bottom: 30),
      children: [
        const Text(
          'Companion Centre',
          style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Share, export, connect and extend HardwareMon—locally and on your terms.',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        if (_message != null) ...[
          const SizedBox(height: 14),
          _StatusBanner(message: _message!),
        ],
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 960;
            final preview = _SnapshotStudio(
              repaintKey: _snapshotKey,
              layout: _layout,
              accent: _accent,
              branding: _branding,
              telemetry: widget.telemetry,
              onLayout: (value) => setState(() => _layout = value),
              onBranding: (value) => setState(() => _branding = value),
              onAccent: () => setState(() {
                _accent = _accent == const Color(0xff5ce1c2)
                    ? const Color(0xff8a7dff)
                    : const Color(0xff5ce1c2);
              }),
              onExport: _exportSnapshot,
            );
            final remote = _RemoteDashboard(
              service: widget.service,
              onToggle: _toggleDashboard,
            );
            return wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: preview),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: remote),
                    ],
                  )
                : Column(
                    children: [preview, const SizedBox(height: 16), remote],
                  );
          },
        ),
        const SizedBox(height: 16),
        _InventoryCard(service: widget.service),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: constraints.maxWidth >= 900
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth,
                child: _ExportCard(
                  inventory: _inventory,
                  telemetry: _telemetry,
                  plugins: _plugins,
                  onInventory: (v) => setState(() => _inventory = v),
                  onTelemetry: (v) => setState(() => _telemetry = v),
                  onPlugins: (v) => setState(() => _plugins = v),
                  onExport: _exportBundle,
                ),
              ),
              SizedBox(
                width: constraints.maxWidth >= 900
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth,
                child: _RuntimeCard(service: widget.service),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SnapshotStudio extends StatelessWidget {
  const _SnapshotStudio({
    required this.repaintKey,
    required this.layout,
    required this.accent,
    required this.branding,
    required this.telemetry,
    required this.onLayout,
    required this.onBranding,
    required this.onAccent,
    required this.onExport,
  });
  final GlobalKey repaintKey;
  final SnapshotLayout layout;
  final Color accent;
  final bool branding;
  final TelemetryService telemetry;
  final ValueChanged<SnapshotLayout> onLayout;
  final ValueChanged<bool> onBranding;
  final VoidCallback onAccent;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Shareable system snapshot',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 14),
        RepaintBoundary(
          key: repaintKey,
          child: Container(
            height: layout == SnapshotLayout.social ? 330 : 230,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xff0c111c),
                  Color.lerp(const Color(0xff0c111c), accent, .18)!,
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: accent.withValues(alpha: .42)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                likelyBrand(),
                const Spacer(),
                Text(
                  telemetry.cpuName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 22,
                  runSpacing: 14,
                  children: [
                    _SnapshotMetric('CPU', '${telemetry.cpuUsage}%', accent),
                    _SnapshotMetric('GPU', '${telemetry.gpuUsage}%', accent),
                    _SnapshotMetric('RAM', '${telemetry.ramUsage}%', accent),
                    if (layout != SnapshotLayout.minimal)
                      _SnapshotMetric(
                        'CPU TEMP',
                        '${telemetry.cpuTemp}°',
                        accent,
                      ),
                    if (layout == SnapshotLayout.standard ||
                        layout == SnapshotLayout.social)
                      _SnapshotMetric(
                        'DISK',
                        '${telemetry.diskUsage}%',
                        accent,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            DropdownButton<SnapshotLayout>(
              value: layout,
              items: [
                for (final value in SnapshotLayout.values)
                  DropdownMenuItem(value: value, child: Text(value.name)),
              ],
              onChanged: (v) {
                if (v != null) onLayout(v);
              },
            ),
            FilterChip(
              label: const Text('Branding'),
              selected: branding,
              onSelected: onBranding,
            ),
            ActionChip(
              avatar: CircleAvatar(backgroundColor: accent),
              label: const Text('Colour'),
              onPressed: onAccent,
            ),
            FilledButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Export PNG'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget likelyBrand() => branding
      ? Text(
          'HARDWAREMON · SYSTEM SNAPSHOT',
          style: TextStyle(
            color: accent,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        )
      : const SizedBox(height: 11);
}

class _SnapshotMetric extends StatelessWidget {
  const _SnapshotMetric(this.label, this.value, this.accent);
  final String label;
  final String value;
  final Color accent;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 88,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: accent, fontSize: 9)),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _RemoteDashboard extends StatelessWidget {
  const _RemoteDashboard({required this.service, required this.onToggle});
  final CompanionService service;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final running = service.dashboardRunning;
    final url = running ? service.dashboardUrl() : null;
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Local Web Dashboard',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'LAN-only live telemetry. A pairing token is required and no account or cloud service is involved.',
            style: TextStyle(color: AppColors.textSecondary(context)),
          ),
          const SizedBox(height: 18),
          if (url != null)
            Center(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(10),
                child: QrImageView(data: url, size: 180),
              ),
            ),
          if (url != null) ...[
            const SizedBox(height: 12),
            SelectableText(url, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 8),
            Text(
              '${service.connectedViewers.length} viewer(s) connected',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onToggle,
              icon: Icon(
                running ? Icons.stop_circle_outlined : Icons.qr_code_2_rounded,
              ),
              label: Text(running ? 'Stop dashboard' : 'Start & pair'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.service});
  final CompanionService service;
  @override
  Widget build(BuildContext context) {
    final data = service.inventory;
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Hardware Inventory',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Refresh inventory',
                onPressed: service.refreshInventory,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (data == null)
            const LinearProgressIndicator()
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Fact(
                  'CPU',
                  (data['cpu'] as Map?)?['name']?.toString() ?? 'Unavailable',
                ),
                _Fact(
                  'Operating system',
                  (data['operating_system'] as Map?)?['name']?.toString() ??
                      'Unavailable',
                ),
                _Fact(
                  'Storage drives',
                  '${(data['storage'] as List?)?.length ?? 0} detected',
                ),
                _Fact(
                  'Network adapters',
                  '${(data['network_adapters'] as List?)?.length ?? 0} detected',
                ),
              ],
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: data == null
                    ? null
                    : () async {
                        final p = await service.exportInventory('json');
                        await Clipboard.setData(ClipboardData(text: p));
                      },
                icon: const Icon(Icons.data_object_rounded),
                label: const Text('Export JSON'),
              ),
              OutlinedButton.icon(
                onPressed: data == null
                    ? null
                    : () => service.exportInventory('txt'),
                icon: const Icon(Icons.text_snippet_outlined),
                label: const Text('Export TXT'),
              ),
              OutlinedButton.icon(
                onPressed: data == null
                    ? null
                    : () => service.exportInventory('pdf'),
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Print PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    width: 210,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.overlay(context, .04),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border(context)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _ExportCard extends StatelessWidget {
  const _ExportCard({
    required this.inventory,
    required this.telemetry,
    required this.plugins,
    required this.onInventory,
    required this.onTelemetry,
    required this.onPlugins,
    required this.onExport,
  });
  final bool inventory, telemetry, plugins;
  final ValueChanged<bool> onInventory, onTelemetry, onPlugins;
  final VoidCallback onExport;
  @override
  Widget build(BuildContext context) => GlassPanel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Export Centre',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose exactly what leaves HardwareMon.',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hardware inventory'),
          value: inventory,
          onChanged: (v) => onInventory(v ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Live telemetry'),
          value: telemetry,
          onChanged: (v) => onTelemetry(v ?? false),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Plugin manifest summary'),
          value: plugins,
          onChanged: (v) => onPlugins(v ?? false),
        ),
        FilledButton.icon(
          onPressed: inventory || telemetry || plugins ? onExport : null,
          icon: const Icon(Icons.archive_outlined),
          label: const Text('Create JSON bundle'),
        ),
      ],
    ),
  );
}

class _RuntimeCard extends StatelessWidget {
  const _RuntimeCard({required this.service});
  final CompanionService service;
  @override
  Widget build(BuildContext context) {
    final portable = service.portableMode;
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Runtime & extensions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              portable?.active == true
                  ? Icons.usb_rounded
                  : Icons.install_desktop_rounded,
            ),
            title: Text(
              portable?.active == true
                  ? 'Portable Mode active'
                  : 'Installed mode',
            ),
            subtitle: Text(portable?.reason ?? 'Detecting runtime…'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.extension_rounded),
            title: Text(
              '${service.plugins.length} isolated plugin manifest(s)',
            ),
            subtitle: const Text(
              'Plugins declare capabilities and are never loaded into the host process.',
            ),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.widgets_outlined),
            title: Text('Desktop widget host'),
            subtitle: Text(
              'Widget capability model is ready; native multi-window hosting remains platform-gated.',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.tealAccent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.tealAccent.withValues(alpha: .2)),
    ),
    child: SelectableText(message),
  );
}
