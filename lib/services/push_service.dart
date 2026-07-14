import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_storage.dart';

/// Notifications push Firebase (FCM).
///
/// Flux : init au démarrage → demande de permission → récupération du token
/// FCM → enregistrement côté backend (lié au compte connecté). Le backend
/// envoie ensuite les alertes MAARIFA même app fermée.
class PushService {
  static bool _initialized = false;

  /// Initialise Firebase. Sans échec bloquant : si la config est absente
  /// (ex: build web), l'app continue sans push.
  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (_) {
      // Pas de config Firebase sur cette plateforme : on continue sans push.
    }
  }

  /// Demande la permission et enregistre le token FCM auprès du backend.
  /// À appeler après connexion (token Sanctum disponible).
  static Future<void> registerToken() async {
    if (!_initialized) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final fcmToken = await messaging.getToken();
      if (fcmToken == null) return;
      await _sendToBackend(fcmToken);

      // Le token FCM peut changer (réinstallation, restauration…)
      messaging.onTokenRefresh.listen(_sendToBackend);
    } catch (_) {}
  }

  static Future<void> _sendToBackend(String fcmToken) async {
    final authToken = await AuthStorage.getToken();
    if (authToken == null) return;
    try {
      await http.post(
        Uri.parse(ApiConfig.url('/user/fcm-token')),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'fcm_token': fcmToken}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  /// Détache le token du compte (à appeler à la déconnexion).
  static Future<void> unregisterToken() async {
    final authToken = await AuthStorage.getToken();
    if (authToken == null) return;
    try {
      await http.delete(
        Uri.parse(ApiConfig.url('/user/fcm-token')),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}
