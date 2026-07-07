import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class LessonService {
  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> getProgress(int courseId, String token) async {
    final res = await http.get(Uri.parse(ApiConfig.lessonProgressUrl(courseId)), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> startPrerequisite(int courseId, String token) async {
    final res = await http.post(Uri.parse(ApiConfig.lessonPrerequisiteStartUrl(courseId)), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> submitPrerequisite(
      int courseId, List<Map<String, dynamic>> answers, String token) async {
    final res = await http.post(
      Uri.parse(ApiConfig.lessonPrerequisiteSubmitUrl(courseId)),
      headers: _headers(token),
      body: jsonEncode({'answers': answers}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> startEvaluation(int courseId, String token) async {
    final res = await http.post(Uri.parse(ApiConfig.lessonEvaluationStartUrl(courseId)), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> submitEvaluation(
      int courseId, List<Map<String, dynamic>> answers, String token) async {
    final res = await http.post(
      Uri.parse(ApiConfig.lessonEvaluationSubmitUrl(courseId)),
      headers: _headers(token),
      body: jsonEncode({'answers': answers}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }
}
