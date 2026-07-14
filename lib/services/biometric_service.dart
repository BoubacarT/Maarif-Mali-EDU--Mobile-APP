import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Verrou biométrique (Face ID / Touch ID / empreinte digitale).
///
/// L'élève active l'option depuis son profil : au prochain démarrage,
/// l'app demande la biométrie avant d'ouvrir la session enregistrée.
class BiometricService {
  static const _keyEnabled = 'maarif_biometric_enabled';
  static final _auth = LocalAuthentication();

  /// L'appareil possède-t-il une biométrie utilisable ?
  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  /// Libellé adapté à l'appareil (Face ID, Touch ID, Empreinte…)
  static Future<String> label() async {
    try {
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return 'Face ID';
      if (types.contains(BiometricType.fingerprint)) return 'Empreinte digitale';
      return 'Biométrie';
    } catch (_) {
      return 'Biométrie';
    }
  }

  /// L'utilisateur a-t-il activé le verrou biométrique ?
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  /// Lance l'authentification biométrique. Retourne true si validée.
  static Future<bool> authenticate({String reason = 'Déverrouille MaarifMaliEdu'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // autorise le code de l'appareil en secours
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
