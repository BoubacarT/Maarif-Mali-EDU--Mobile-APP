import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class GoalService {
  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<List<dynamic>> getGoals(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.goalsUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body['data'] ?? [];
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> createGoal(Map<String, dynamic> data, String token) async {
    final res = await http.post(Uri.parse(ApiConfig.goalsUrl), headers: _headers(token), body: jsonEncode(data));
    final body = jsonDecode(res.body);
    if (res.statusCode == 201) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<void> deleteGoal(int id, String token) async {
    final res = await http.delete(Uri.parse(ApiConfig.goalUrl(id)), headers: _headers(token));
    if (res.statusCode != 200 && res.statusCode != 204) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Erreur');
    }
  }

  static Future<List<dynamic>> searchInstitutions(String query, String token) async {
    final url = Uri.parse(ApiConfig.institutionsUrl).replace(queryParameters: {'q': query});
    final res = await http.get(url, headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body['data'] ?? [];
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> getOrientationTest(String token) async {
    final res = await http.get(Uri.parse(ApiConfig.orientationTestsUrl), headers: _headers(token));
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) {
      final list = body['data'] ?? [];
      if (list.isEmpty) throw Exception('Aucun test disponible');
      return list[0];
    }
    throw Exception(body['message'] ?? 'Erreur');
  }

  static Future<Map<String, dynamic>> submitOrientation(int testId, Map<String, int> answers, String token) async {
    final res = await http.post(
      Uri.parse(ApiConfig.orientationTestSubmitUrl(testId)),
      headers: _headers(token),
      body: jsonEncode({'answers': answers}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode == 200) return body;
    throw Exception(body['message'] ?? 'Erreur');
  }
}
