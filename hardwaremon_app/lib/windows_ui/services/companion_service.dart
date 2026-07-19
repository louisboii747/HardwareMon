import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/backend_config.dart';

typedef LiveSnapshotProvider = Map<String, Object?> Function();

class PortableModeInfo {
  final bool active;
  final String dataDirectory;
  final String reason;

  const PortableModeInfo({
    required this.active,
    required this.dataDirectory,
    required this.reason,
  });
}

class PluginDescriptor {
  final String id;
  final String name;
  final String version;
  final bool enabled;
  final List<String> capabilities;
  final List<String> grantedCapabilities;
  final String publisher;
  final String description;
  final String status;
  final bool official;
  final bool valid;
  final bool approved;
  final int? pid;
  final int restartCount;
  final String? error;

  const PluginDescriptor({
    required this.id,
    required this.name,
    required this.version,
    required this.enabled,
    required this.capabilities,
    this.grantedCapabilities = const [],
    this.publisher = 'Unknown publisher',
    this.description = '',
    this.status = 'stopped',
    this.official = false,
    this.valid = true,
    this.approved = false,
    this.pid,
    this.restartCount = 0,
    this.error,
  });

  factory PluginDescriptor.fromJson(Map<String, dynamic> json) =>
      PluginDescriptor(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unnamed plugin',
        version: json['version']?.toString() ?? '0.0.0',
        enabled: json['enabled'] == true,
        capabilities: (json['capabilities'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        grantedCapabilities: (json['granted_capabilities'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        publisher: json['publisher']?.toString() ?? 'Unknown publisher',
        description: json['description']?.toString() ?? '',
        status: json['status']?.toString() ?? 'stopped',
        official: json['official'] == true,
        valid: json['valid'] != false,
        approved: json['approved'] == true,
        pid: (json['pid'] as num?)?.toInt(),
        restartCount: (json['restart_count'] as num?)?.toInt() ?? 0,
        error: json['error']?.toString(),
      );
}

class CompanionService extends ChangeNotifier {
  CompanionService({required this.snapshotProvider});

  final LiveSnapshotProvider snapshotProvider;
  HttpServer? _server;
  String? _token;
  String? _lanAddress;
  Map<String, dynamic>? inventory;
  PortableModeInfo? portableMode;
  List<PluginDescriptor> plugins = const [];
  List<String> knownPluginCapabilities = const [];
  final Set<String> connectedViewers = {};
  bool _disposed = false;

  bool get dashboardRunning => _server != null;
  int? get dashboardPort => _server?.port;
  String? get pairingToken => _token;

  Future<void> initialise() async {
    portableMode = await detectPortableMode();
    await refreshPlugins();
    await refreshInventory();
    _notifySafely();
  }

  Future<void> refreshInventory() async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/inventory'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Inventory request failed (${response.statusCode})');
    }
    inventory = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    _notifySafely();
  }

  Future<PortableModeInfo> detectPortableMode() async {
    final executable = File(Platform.resolvedExecutable);
    final directory = executable.parent;
    final explicit = Platform.environment['HARDWAREMON_PORTABLE'] == '1';
    final marker = File(
      '${directory.path}${Platform.pathSeparator}portable.flag',
    );
    final active = explicit || await marker.exists();
    final normal = await getApplicationSupportDirectory();
    return PortableModeInfo(
      active: active,
      dataDirectory: active
          ? '${directory.path}${Platform.pathSeparator}HardwareMonData'
          : normal.path,
      reason: explicit
          ? 'Enabled by HARDWAREMON_PORTABLE'
          : active
          ? 'portable.flag found beside HardwareMon'
          : 'Installed data directories are in use',
    );
  }

  Future<void> refreshPlugins() async {
    final response = await http
        .get(Uri.parse('${BackendConfig.baseUrl}/plugins'))
        .timeout(const Duration(seconds: 8));
    _ensureSuccess(response, 'Plugin discovery');
    final payload = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    knownPluginCapabilities =
        (payload['known_capabilities'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false);
    plugins = (payload['plugins'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (value) =>
              PluginDescriptor.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false);
    _notifySafely();
  }

  Future<void> setPluginGrants(String pluginId, List<String> grants) async {
    final response = await http.put(
      Uri.parse('${BackendConfig.baseUrl}/plugins/$pluginId/grants'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'capabilities': grants}),
    );
    _ensureSuccess(response, 'Update plugin permissions');
    await refreshPlugins();
  }

  Future<void> setPluginEnabled(String pluginId, bool enabled) async {
    final response = await http.put(
      Uri.parse('${BackendConfig.baseUrl}/plugins/$pluginId/enabled'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'enabled': enabled}),
    );
    _ensureSuccess(response, enabled ? 'Enable plugin' : 'Disable plugin');
    await refreshPlugins();
  }

  Future<void> restartPlugin(String pluginId) async {
    final response = await http.post(
      Uri.parse('${BackendConfig.baseUrl}/plugins/$pluginId/restart'),
    );
    _ensureSuccess(response, 'Restart plugin');
    await refreshPlugins();
  }

  Future<void> installPluginArchive(List<int> bytes) async {
    if (bytes.isEmpty || bytes.length > 25 * 1024 * 1024) {
      throw StateError('Plugin packages must be between 1 byte and 25 MB');
    }
    final response = await http.post(
      Uri.parse('${BackendConfig.baseUrl}/plugins/install'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'content_base64': base64Encode(bytes)}),
    );
    _ensureSuccess(response, 'Install plugin');
    await refreshPlugins();
  }

  Future<void> removePlugin(String pluginId) async {
    final response = await http.delete(
      Uri.parse('${BackendConfig.baseUrl}/plugins/$pluginId'),
    );
    _ensureSuccess(response, 'Remove plugin');
    await refreshPlugins();
  }

  Future<List<Map<String, dynamic>>> pluginLogs(String pluginId) async {
    final response = await http.get(
      Uri.parse('${BackendConfig.baseUrl}/plugins/$pluginId'),
    );
    _ensureSuccess(response, 'Plugin logs');
    final payload = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    return (payload['logs'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
  }

  void _ensureSuccess(http.Response response, String operation) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    var detail = response.body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        detail = decoded['detail'].toString();
      }
    } on FormatException {
      // Keep the response body as the most useful failure detail.
    }
    throw StateError('$operation failed: $detail');
  }

  Future<String> exportInventory(String format) async {
    final data = inventory ?? const <String, dynamic>{};
    final directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final extension = format == 'txt'
        ? 'txt'
        : format == 'pdf'
        ? 'pdf'
        : 'json';
    final file = File(
      '${directory.path}${Platform.pathSeparator}hardwaremon-inventory-$stamp.$extension',
    );
    if (format == 'pdf') {
      final document = pw.Document();
      document.addPage(
        pw.MultiPage(
          build: (_) => [
            pw.Header(level: 0, text: 'HardwareMon Hardware Inventory'),
            pw.Text('Generated ${DateTime.now()}'),
            pw.SizedBox(height: 16),
            for (final entry in data.entries) ...[
              pw.Header(level: 1, text: entry.key.replaceAll('_', ' ')),
              pw.Text(const JsonEncoder.withIndent('  ').convert(entry.value)),
            ],
          ],
        ),
      );
      await file.writeAsBytes(await document.save(), flush: true);
      return file.path;
    }
    final contents = format == 'txt'
        ? _inventoryText(data)
        : const JsonEncoder.withIndent('  ').convert(data);
    await file.writeAsString(contents, flush: true);
    return file.path;
  }

  Future<String> exportBundle({
    required bool includeInventory,
    required bool includeTelemetry,
    required bool includePlugins,
  }) async {
    final package = await PackageInfo.fromPlatform();
    final payload = <String, Object?>{
      'schema': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'hardwaremon_version': package.version,
      if (includeInventory) 'inventory': inventory,
      if (includeTelemetry) 'telemetry': snapshotProvider(),
      if (includePlugins)
        'plugins': [
          for (final plugin in plugins)
            {
              'id': plugin.id,
              'name': plugin.name,
              'version': plugin.version,
              'capabilities': plugin.capabilities,
            },
        ],
    };
    final directory =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}hardwaremon-export-${DateTime.now().millisecondsSinceEpoch}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );
    return file.path;
  }

  Future<String> startDashboard({String? password}) async {
    if (_server != null) return dashboardUrl();
    _token = password?.trim().isNotEmpty == true
        ? password!.trim()
        : _randomToken();
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
    _lanAddress = await _preferredLanAddress();
    unawaited(_serve(_server!));
    _notifySafely();
    return dashboardUrl();
  }

  String dashboardUrl({String? host}) {
    final address = host ?? _lanAddress ?? '127.0.0.1';
    return 'http://$address:${_server?.port ?? 0}/?token=$_token';
  }

  Future<void> stopDashboard() async {
    final server = _server;
    _server = null;
    _lanAddress = null;
    connectedViewers.clear();
    await server?.close(force: true);
    _notifySafely();
  }

  @override
  void dispose() {
    _disposed = true;
    final server = _server;
    _server = null;
    server?.close(force: true);
    connectedViewers.clear();
    super.dispose();
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      final supplied =
          request.uri.queryParameters['token'] ??
          request.headers.value('x-hardwaremon-token');
      if (supplied != _token) {
        request.response.statusCode = HttpStatus.unauthorized;
        request.response.write('HardwareMon pairing token required');
        await request.response.close();
        continue;
      }
      connectedViewers.add(
        request.connectionInfo?.remoteAddress.address ?? 'LAN',
      );
      if (request.uri.path == '/api/live') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(snapshotProvider()));
      } else {
        request.response.headers.contentType = ContentType.html;
        request.response.write(_dashboardHtml);
      }
      await request.response.close();
      _notifySafely();
    }
  }

  Future<String?> _preferredLanAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && !address.isLinkLocal) return address.address;
      }
    }
    return null;
  }

  String _randomToken() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(
      10,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
  }

  void _notifySafely() {
    if (!_disposed) notifyListeners();
  }

  String _inventoryText(Map<String, dynamic> data) {
    final buffer = StringBuffer('HardwareMon Hardware Inventory\n');
    buffer.writeln('Generated: ${DateTime.now()}');
    for (final entry in data.entries) {
      buffer.writeln('\n${entry.key.toUpperCase()}');
      buffer.writeln(const JsonEncoder.withIndent('  ').convert(entry.value));
    }
    return buffer.toString();
  }
}

const _dashboardHtml = r'''<!doctype html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1">
<title>HardwareMon Live</title><style>
body{margin:0;background:#090d15;color:#f5f7fb;font:15px system-ui;padding:24px}
main{max-width:900px;margin:auto}.brand{color:#55d6be;letter-spacing:.14em}
#grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px}
.card{background:#121a27;border:1px solid #273247;border-radius:18px;padding:18px}
.value{font-size:30px;font-weight:750;margin-top:8px}.muted{color:#91a0b7}
</style></head><body><main><div class="brand">HARDWAREMON · LAN LIVE</div>
<h1>Your system, nearby.</h1><p class="muted">Private live telemetry from this PC. No cloud connection.</p>
<div id="grid"></div></main><script>
const token=new URLSearchParams(location.search).get('token');
async function tick(){const r=await fetch('/api/live?token='+encodeURIComponent(token));
if(!r.ok)return;const d=await r.json();document.querySelector('#grid').innerHTML=
Object.entries(d).map(([k,v])=>`<div class="card"><div class="muted">${k.replaceAll('_',' ')}</div><div class="value">${v??'—'}</div></div>`).join('')}
tick();setInterval(tick,1500)</script></body></html>''';
