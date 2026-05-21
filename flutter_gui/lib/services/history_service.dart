import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/history_point.dart';

class HistoryService {
  static Future<List<HistoryPoint>> fetchHistory() async {
    final response = await http.get(Uri.parse('http://127.0.0.1:5000/history'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load history');
    }

    final List<dynamic> data = jsonDecode(response.body);

    return data.map((json) => HistoryPoint.fromJson(json)).toList();
  }
}
