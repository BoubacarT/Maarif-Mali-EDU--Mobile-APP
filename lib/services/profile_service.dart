import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:maarif_learn/config/api_config.dart';

class ProfileService {
  static Future<StudentProfile> getProfile(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.userUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return StudentProfile.fromJson(json);
    }

    if (response.statusCode == 401) {
      throw ProfileException('Session expiree. Reconnectez-vous.', 401);
    }

    if (response.statusCode == 403) {
      throw ProfileException('Acces non autorise.', 403);
    }

    String message = 'Impossible de charger le profil';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      message = (body['message'] ?? message).toString();
    } catch (_) {}
    throw ProfileException(message, response.statusCode);
  }
}

class StudentProfile {
  final int id;
  final String name;
  final String email;
  final String? nom;
  final String? prenom;
  final String? adresse;
  final String? dateNaissance;
  final Map<String, dynamic>? level;

  /// Matières de la série avec coefficients officiels (barème Maarif 2025-2026)
  final List<Map<String, dynamic>> subjects;
  final double totalCoefficient;

  StudentProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.nom,
    required this.prenom,
    required this.adresse,
    required this.dateNaissance,
    required this.level,
    this.subjects = const [],
    this.totalCoefficient = 0,
  });

  static StudentProfile fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] as int,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      nom: json['nom']?.toString(),
      prenom: json['prenom']?.toString(),
      adresse: json['adresse']?.toString(),
      dateNaissance: json['date_naissance']?.toString(),
      level: json['level'] as Map<String, dynamic>?,
      subjects: (json['subjects'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      totalCoefficient: (json['total_coefficient'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ProfileException implements Exception {
  final String message;
  final int? statusCode;

  ProfileException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}
