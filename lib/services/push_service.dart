import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../HomePage.dart';
import '../config/api_config.dart';
import 'auth_storage.dart';

/// Clé de navigation globale (déclarée dans main.dart) permettant au
/// deep-link push de naviguer sans BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Notifications push Firebase (FCM).
///
/// Flux : init au démarrage → demande de permission → récupération du token
/// FCM → enregistrement côté backend (lié au compte connecté). Le backend
/// envoie ensuite les alertes MAARIFA même app fermée.
class PushService {
  static bool _initialized = false;

  /// true si Firebase est initialisé (Crashlytics utilisable).
  static bool get firebaseReady => _initialized;

  /// Initialise Firebase. Sans échec bloquant : si la config est absente
  /// (ex: build web), l'app continue sans push.
  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      await Firebase.initializeApp();
      _initialized = true;
      _wireDeepLinks();
    } catch (_) {
      // Pas de config Firebase sur cette plateforme : on continue sans push.
    }
  }

  /// Taper sur une notification MAARIFA → ouvre directement l'onglet MAARIFA.
  static void _wireDeepLinks() {
    // App en arrière-plan → notification tapée
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);
    // App fermée → lancée depuis la notification
    FirebaseMessaging.instance.getInitialMessage().then((msg) {
      if (msg != null) {
        // Laisse le SplashGate valider la session avant de naviguer
        Future.delayed(const Duration(milliseconds: 1800), () => _handleOpenedMessage(msg));
      }
    });
  }

  static Future<void> _handleOpenedMessage(RemoteMessage message) async {
    // Toutes les notifs actuelles sont des alertes MAARIFA → onglet 3
    if (message.data['recommendation_id'] == null && message.data['type'] == null) return;
    final token = await AuthStorage.getToken();
    if (token == null) return; // pas connecté : on reste sur le login
    final nav = appNavigatorKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Homepage(initialTab: 3)),
      (_) => false,
    );
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
