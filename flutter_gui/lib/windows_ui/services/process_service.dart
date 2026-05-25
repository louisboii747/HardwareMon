import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_gui/windows_ui/core/backend_config.dart';

import '../models/process_info.dart';

class ProcessService {
  static final String baseUrl = BackendConfig.baseUrl;

  static Future<List<ProcessInfo>> fetchProcesses() async {
    final response = await http.get(Uri.parse('$baseUrl/processes'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load processes');
    }

    final List data = jsonDecode(response.body);

    return data.map((json) => ProcessInfo.fromJson(json)).toList();
  }

  static Future<void> killProcess(int pid) async {
    final response = await http.post(Uri.parse('$baseUrl/kill/$pid'));

    if (response.statusCode != 200) {
      throw Exception('Failed to kill process');
    }
  }
}
