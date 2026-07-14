import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class ArifService {
  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<List<dynamic>> getRecommendations(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.arifRecommendationsUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body['data'] ?? [];
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<void> markRead(int id, String token) async {
    await http.post(Uri.parse(ApiConfig.arifMarkReadUrl(id)), headers: _headers(token));
  }

  static Future<Map<String, dynamic>> createConversation(String contextType, String token,
      {int? contextId, bool fresh = false}) async {
    final res = await http.post(
      Uri.parse(ApiConfig.arifConversationsUrl),
      headers: _headers(token),
      body: jsonEncode({
        'context_type': contextType,
        if (contextId != null) 'context_id': contextId,
        if (fresh) 'fresh': true,
      }),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200 || res.statusCode == 201) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> sendMessage(int conversationId, String message, String token) async {
    final res = await http.post(
      Uri.parse(ApiConfig.arifConversationMessagesUrl(conversationId)),
      headers: _headers(token),
      body: jsonEncode({'content': message}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<void> generateAlerts(String token) async {
    try {
      await http.post(Uri.parse(ApiConfig.url('/ai/alerts/generate')), headers: _headers(token));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getStats(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.arifStatsUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur stats');
  }

  static Future<Map<String, dynamic>> getGamification(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.arifGamificationUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur gamification');
  }

  static Future<Map<String, dynamic>> predictBac(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.arifPredictBacUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur prédiction BAC');
  }

  static Future<String> summarizeCourse(int courseId, String token) async {
    final res = await http.post(Uri.parse(ApiConfig.courseSummarizeUrl(courseId)), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body['summary'] ?? '';
    throw Exception(body['message'] ?? 'Erreur résumé');
  }

  static Future<List<dynamic>> getCourseFlashcards(int courseId, String token, {int count = 8}) async {
    final res = await http.post(
      Uri.parse(ApiConfig.courseFlashcardsUrl(courseId)),
      headers: _headers(token),
      body: jsonEncode({'count': count}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body['flashcards'] ?? [];
    throw Exception(body['message'] ?? 'Erreur flashcards');
  }

  static Future<List<dynamic>> getCourseExercise(int courseId, String token, {String difficulty = 'moyen'}) async {
    final res = await http.post(
      Uri.parse(ApiConfig.courseExerciseUrl(courseId)),
      headers: _headers(token),
      body: jsonEncode({'difficulty': difficulty}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body['questions'] ?? [];
    throw Exception(body['message'] ?? 'Erreur exercice');
  }
}
