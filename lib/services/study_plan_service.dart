import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class StudyPlanService {
  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> getConfig(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.studyPlanUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<List<dynamic>> getWeek(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.studyPlanWeekUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body['data'] ?? [];
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> generate(
      double dailyHours, List<String> studyDays, String endDate, String token) async {
    final res = await http.post(
      Uri.parse(ApiConfig.studyPlanGenerateUrl),
      headers: _headers(token),
      body: jsonEncode({'daily_hours': dailyHours, 'study_days': studyDays, 'end_date': endDate}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<void> updateItemStatus(int itemId, String status, String token) async {
    final res = await http.put(
      Uri.parse(ApiConfig.studyPlanItemUrl(itemId)),
      headers: _headers(token),
      body: jsonEncode({'status': status}),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Erreur');
    }
  }
}
