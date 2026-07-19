import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import '../../core/theme/app_colors.dart';
import '../../services/companion_service.dart';
import '../../widgets/glass_panel.dart';

class PluginsPage extends StatefulWidget {
  const PluginsPage({super.key, required this.service});

  final CompanionService service;

  @override
  State<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends State<PluginsPage> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_changed);
    _refresh();
  }

  @override
  void dispose() {
    widget.service.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.service.refreshPlugins();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _configure(PluginDescriptor plugin) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _PluginDetailsDialog(plugin: plugin, service: widget.service),
    );
  }

  Future<void> _install() async {
    const group = XTypeGroup(
      label: 'HardwareMon plugins',
      extensions: ['hmp', 'zip'],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.service.installPluginArchive(await file.readAsBytes());
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plugins = widget.service.plugins;
    final running = plugins
        .where((plugin) => plugin.status == 'running')
        .length;
    final attention = plugins
        .where((plugin) => !plugin.valid || plugin.status == 'unresponsive')
        .length;
    return CustomScrollView(
      key: const PageStorageKey('plugins-page'),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plugin Studio',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Extend HardwareMon through supervised, capability-scoped processes.',
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _install,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Install .hmp'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Refresh plugins',
                    onPressed: _loading ? null : _refresh,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryTile(
                    icon: Icons.extension_rounded,
                    label: 'Discovered',
                    value: '${plugins.length}',
                    color: AppColors.accent,
                  ),
                  _SummaryTile(
                    icon: Icons.play_circle_outline_rounded,
                    label: 'Running',
                    value: '$running',
                    color: Colors.greenAccent,
                  ),
                  _SummaryTile(
                    icon: Icons.shield_outlined,
                    label: 'Capabilities',
                    value: '${widget.service.knownPluginCapabilities.length}',
                    color: Colors.lightBlueAccent,
                  ),
                  _SummaryTile(
                    icon: Icons.warning_amber_rounded,
                    label: 'Needs attention',
                    value: '$attention',
                    color: attention == 0
                        ? Colors.greenAccent
                        : Colors.orangeAccent,
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorBanner(message: _error!, onRetry: _refresh),
              ],
              const SizedBox(height: 20),
              GlassPanel(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.security_rounded,
                      color: Colors.tealAccent,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Trust is explicit',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Plugins remain stopped until every requested capability is approved. Changing permissions stops the process and requires deliberate re-enabling.',
                            style: TextStyle(
                              color: AppColors.textSecondary(context),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        if (plugins.isEmpty && !_loading)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyPlugins(onRefresh: _refresh),
          )
        else
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.crossAxisExtent >= 1050
                  ? 3
                  : constraints.crossAxisExtent >= 680
                  ? 2
                  : 1;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisExtent: 286,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _PluginCard(
                    plugin: plugins[index],
                    onOpen: () => _configure(plugins[index]),
                  ),
                  childCount: plugins.length,
                ),
              );
            },
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }
}

class _PluginCard extends StatelessWidget {
  const _PluginCard({required this.plugin, required this.onOpen});
  final PluginDescriptor plugin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final color = switch (plugin.status) {
      'running' => Colors.greenAccent,
      'unresponsive' || 'invalid' => Colors.orangeAccent,
      'starting' => Colors.lightBlueAccent,
      _ => AppColors.textMuted(context),
    };
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      glowColor: plugin.enabled ? color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.extension_rounded, color: color),
              ),
              const Spacer(),
              if (plugin.official)
                const _Pill(label: 'OFFICIAL', color: Colors.tealAccent),
              const SizedBox(width: 7),
              _Pill(label: plugin.status.toUpperCase(), color: color),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            plugin.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 3),
          Text(
            '${plugin.publisher} · v${plugin.version}',
            style: TextStyle(color: AppColors.textMuted(context), fontSize: 10),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Text(
              plugin.error ?? plugin.description,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: plugin.valid
                    ? AppColors.textSecondary(context)
                    : Colors.orangeAccent,
                height: 1.35,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: [
              for (final capability in plugin.capabilities.take(3))
                _Pill(
                  label: capability,
                  color: plugin.grantedCapabilities.contains(capability)
                      ? Colors.lightBlueAccent
                      : AppColors.textMuted(context),
                ),
            ],
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: plugin.valid ? onOpen : null,
              icon: const Icon(Icons.tune_rounded, size: 17),
              label: Text(
                plugin.approved ? 'Manage plugin' : 'Review permissions',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PluginDetailsDialog extends StatefulWidget {
  const _PluginDetailsDialog({required this.plugin, required this.service});
  final PluginDescriptor plugin;
  final CompanionService service;
  @override
  State<_PluginDetailsDialog> createState() => _PluginDetailsDialogState();
}

class _PluginDetailsDialogState extends State<_PluginDetailsDialog>
    with SingleTickerProviderStateMixin {
  late Set<String> _grants;
  late TabController _tabs;
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>> _logs = const [];

  @override
  void initState() {
    super.initState();
    _grants = widget.plugin.grantedCapabilities.toSet();
    _tabs = TabController(length: 3, vsync: this);
    _loadLogs();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await widget.service.pluginLogs(widget.plugin.id);
      if (mounted) setState(() => _logs = logs);
    } catch (_) {}
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
    title: Row(
      children: [
        const Icon(Icons.extension_rounded),
        const SizedBox(width: 10),
        Expanded(child: Text(widget.plugin.name)),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
    contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
    content: SizedBox(
      width: 680,
      height: 500,
      child: Column(
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Permissions'),
              Tab(text: 'Logs'),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.orangeAccent),
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                ListView(
                  padding: const EdgeInsets.only(top: 18),
                  children: [
                    Text(
                      widget.plugin.description,
                      style: const TextStyle(height: 1.5),
                    ),
                    const SizedBox(height: 18),
                    _DetailRow('Identifier', widget.plugin.id),
                    _DetailRow('Publisher', widget.plugin.publisher),
                    _DetailRow('Version', widget.plugin.version),
                    _DetailRow('Status', widget.plugin.status),
                    _DetailRow(
                      'Process',
                      widget.plugin.pid?.toString() ?? 'Not running',
                    ),
                    _DetailRow(
                      'Crash restarts',
                      '${widget.plugin.restartCount}',
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.only(top: 14),
                  children: [
                    for (final capability in widget.plugin.capabilities)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _grants.contains(capability),
                        onChanged: widget.plugin.enabled
                            ? null
                            : (value) => setState(() {
                                if (value == true) {
                                  _grants.add(capability);
                                } else {
                                  _grants.remove(capability);
                                }
                              }),
                        title: Text(_capabilityTitle(capability)),
                        subtitle: Text(_capabilityDescription(capability)),
                      ),
                    if (widget.plugin.enabled)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          'Disable the plugin before changing its capabilities.',
                          style: TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                  ],
                ),
                _logs.isEmpty
                    ? const Center(child: Text('No plugin logs yet.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 12),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          final log = _logs[_logs.length - index - 1];
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Text(
                              (log['level'] ?? 'info').toString().toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.tealAccent,
                              ),
                            ),
                            title: SelectableText(
                              log['message']?.toString() ?? '',
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    ),
    actions: [
      if (!widget.plugin.official && !widget.plugin.enabled)
        TextButton.icon(
          onPressed: _busy
              ? null
              : () => _run(() => widget.service.removePlugin(widget.plugin.id)),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Remove'),
        ),
      if (widget.plugin.enabled)
        TextButton.icon(
          onPressed: _busy
              ? null
              : () =>
                    _run(() => widget.service.restartPlugin(widget.plugin.id)),
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('Restart'),
        ),
      OutlinedButton(
        onPressed: _busy
            ? null
            : () => _run(
                () => widget.service.setPluginGrants(
                  widget.plugin.id,
                  _grants.toList(),
                ),
              ),
        child: const Text('Save permissions'),
      ),
      FilledButton.icon(
        onPressed:
            _busy ||
                (!widget.plugin.enabled &&
                    _grants.length != widget.plugin.capabilities.length)
            ? null
            : () => _run(
                () => widget.service.setPluginEnabled(
                  widget.plugin.id,
                  !widget.plugin.enabled,
                ),
              ),
        icon: Icon(
          widget.plugin.enabled
              ? Icons.stop_circle_outlined
              : Icons.play_arrow_rounded,
        ),
        label: Text(widget.plugin.enabled ? 'Disable' : 'Enable'),
      ),
    ],
  );
}

String _capabilityTitle(String value) => switch (value) {
  'telemetry.read' => 'Read live telemetry',
  'inventory.read' => 'Read hardware inventory',
  'history.read' => 'Read historical telemetry',
  'events.publish' => 'Publish events',
  'network.listen' => 'Listen on a local port',
  'network.connect' => 'Connect to the network',
  'settings.read' => 'Read non-sensitive settings',
  _ => value,
};
String _capabilityDescription(String value) => switch (value) {
  'telemetry.read' =>
    'Receives filtered CPU, GPU, memory, thermal and storage samples.',
  'inventory.read' =>
    'Can receive the hardware inventory exposed by HardwareMon.',
  'history.read' => 'Can request locally retained telemetry history.',
  'events.publish' => 'Can add attributed plugin events to HardwareMon.',
  'network.listen' => 'May expose a service on this computer or local network.',
  'network.connect' => 'May make outbound network requests.',
  'settings.read' => 'May read explicitly shareable HardwareMon preferences.',
  _ => 'Capability declared by the plugin API.',
};

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label, value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 190,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.overlay(context, .04),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border(context)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textMuted(context),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .22)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w800),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(color: AppColors.textMuted(context)),
          ),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.orangeAccent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: Colors.orangeAccent.withValues(alpha: .25)),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

class _EmptyPlugins extends StatelessWidget {
  const _EmptyPlugins({required this.onRefresh});
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.extension_off_outlined, size: 48),
        const SizedBox(height: 12),
        const Text(
          'No plugins discovered',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Official plugins are installed by the backend on startup.',
          style: TextStyle(color: AppColors.textSecondary(context)),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Scan again'),
        ),
      ],
    ),
  );
}
