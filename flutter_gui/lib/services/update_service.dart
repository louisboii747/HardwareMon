import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const bool isDevelopmentBuild = true;
  static const String currentVersion = '18.0.0-dev';

  static Future<Map<String, dynamic>> checkForUpdates() async {
    final response = await http.get(
      Uri.parse(
        'https://api.github.com/repos/louisboii747/HardwareMon/releases/latest',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to check for updates');
    }

    final data = jsonDecode(response.body);

    final latestVersion = (data['tag_name'] as String).replaceFirst('v', '');

    return {
      'current': currentVersion,
      'latest': latestVersion,
      'updateAvailable': !isDevelopmentBuild && latestVersion != currentVersion,
      'developmentBuild': isDevelopmentBuild,
      'htmlUrl': data['html_url'],
    };
  }

  static Future<String> downloadLatestRelease() async {
    final response = await http.get(
      Uri.parse(
        'https://api.github.com/repos/louisboii747/HardwareMon/releases/latest',
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch latest release');
    }

    final data = jsonDecode(response.body);

    String? downloadUrl;
    String? fileName;

    for (final asset in data['assets']) {
      final name = asset['name'] as String;

      if (Platform.isWindows && name.endsWith('.exe')) {
        downloadUrl = asset['browser_download_url'];
        fileName = name;
        break;
      }

      if (Platform.isLinux && name.endsWith('.deb')) {
        downloadUrl = asset['browser_download_url'];
        fileName = name;
        break;
      }

      if (Platform.isLinux && name.endsWith('.rpm')) {
        downloadUrl = asset['browser_download_url'];
        fileName = name;
        break;
      }
    }

    if (downloadUrl == null || fileName == null) {
      throw Exception('No compatible update found');
    }

    final downloadResponse = await http.get(Uri.parse(downloadUrl));

    if (downloadResponse.statusCode != 200) {
      throw Exception('Failed to download update');
    }

    final tempDir = await getTemporaryDirectory();

    final file = File('${tempDir.path}/$fileName');

    await file.writeAsBytes(downloadResponse.bodyBytes);

    return file.path;
  }
}
