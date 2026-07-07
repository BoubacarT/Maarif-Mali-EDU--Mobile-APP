import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class MockExamService {
  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<List<dynamic>> getTemplates(String token) async {
    final res = await http.get(
        Uri.parse(ApiConfig.mockExamTemplatesUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body['data'] ?? [];
    throw Exception(body['message'] ?? 'Erreur chargement modèles');
  }

  static Future<List<dynamic>> getSessions(String token) async {
    final res = await http.get(
        Uri.parse(ApiConfig.mockExamSessionsUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body['data'] ?? [];
    throw Exception(body['message'] ?? 'Erreur chargement sessions');
  }

  /// [subjectScores] : liste de maps {subject, total, correct, wrong, empty}
  static Future<Map<String, dynamic>> submitSession(
    int templateId,
    List<Map<String, dynamic>> subjectScores,
    String examDate,
    String token, {
    double? diplomaGrade,
  }) async {
    final res = await http.post(
      Uri.parse(ApiConfig.mockExamSessionsUrl),
      headers: _headers(token),
      body: jsonEncode({
        'template_id': templateId,
        'subject_scores': subjectScores,
        'exam_date': examDate,
        if (diplomaGrade != null) 'diploma_grade': diplomaGrade,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 201) return body['data'] ?? body;
    throw Exception(body['message'] ?? 'Erreur enregistrement session');
  }

  static Future<Map<String, dynamic>> getSession(int id, String token) async {
    final res = await http.get(
        Uri.parse(ApiConfig.mockExamSessionUrl(id)), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body['data'] ?? body;
    throw Exception(body['message'] ?? 'Erreur');
  }
}
