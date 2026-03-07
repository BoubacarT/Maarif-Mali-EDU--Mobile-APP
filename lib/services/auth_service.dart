import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_storage.dart';

class AuthService {
  /// Connexion au backend Maarif (compte élève).
  /// Retourne { user: { id, name, email, level }, token } et enregistre en local.
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse(ApiConfig.loginUrl),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;
      if (token != null && user != null) {
        await AuthStorage.save(token, user);
      }
      return data;
    } else {
      final body = response.body;
      String message = 'Échec de la connexion';
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        message = (json['message'] ?? json['error'] ?? message).toString();
      } catch (_) {
        if (body.isNotEmpty) message = body;
      }
      throw AuthException(message, response.statusCode);
    }
  }

  /// Déconnexion : supprime token et user du stockage local
  static Future<void> logout() async {
    await AuthStorage.clear();
  }
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;

  AuthException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
