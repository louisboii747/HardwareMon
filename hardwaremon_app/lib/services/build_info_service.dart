import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../windows_ui/core/backend_config.dart';

const _compiledFlutterVersion = String.fromEnvironment(
  'HARDWAREMON_FLUTTER_VERSION',
  defaultValue: '',
);

class RuntimeBuildInfo {
  final String buildType;
  final String platform;
  final String flutterVersion;
  final String backendVersion;

  const RuntimeBuildInfo({
    required this.buildType,
    required this.platform,
    required this.flutterVersion,
    required this.backendVersion,
  });
}

class BuildInfoService {
  Future<RuntimeBuildInfo> load() async {
    var backendVersion = 'Unavailable';
    try {
      final response = await http
          .get(Uri.parse(BackendConfig.baseUrl))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload is Map) {
          backendVersion =
              payload['version']?.toString().trim().isNotEmpty == true
              ? payload['version'].toString()
              : payload['backend']?.toString() ?? 'Available';
        }
      }
    } catch (_) {
      // The About panel remains useful while the local backend reconnects.
    }

    return RuntimeBuildInfo(
      buildType: kReleaseMode
          ? 'Release'
          : kProfileMode
          ? 'Profile'
          : 'Debug',
      platform: Platform.isWindows
          ? 'Windows'
          : Platform.isLinux
          ? 'Linux'
          : Platform.operatingSystem,
      flutterVersion: _compiledFlutterVersion.trim().isEmpty
          ? 'Not embedded'
          : _compiledFlutterVersion.trim(),
      backendVersion: backendVersion,
    );
  }
}
