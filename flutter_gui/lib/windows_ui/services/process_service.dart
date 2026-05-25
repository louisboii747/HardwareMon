import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/process_info.dart';

class ProcessService {
  static Future<List<ProcessInfo>> fetchProcesses() async {
    final response = await http.get(
      Uri.parse('http://127.0.0.1:8000/processes'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load processes');
    }

    final List data = jsonDecode(response.body);

    return data.map((json) => ProcessInfo.fromJson(json)).toList();
  }

  static Future<void> killProcess(int pid) async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/kill/$pid'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to kill process');
    }
  }
}
