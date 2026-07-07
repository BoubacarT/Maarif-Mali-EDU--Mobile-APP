import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ReportService {
  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> getCompletion(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.reportsCompletionUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> getMockExams(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.reportsMockExamsUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> getProgress(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.reportsProgressUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> getGoals(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.reportsGoalsUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }
}
