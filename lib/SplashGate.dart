import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:maarif_learn/HomePage.dart';
import 'package:maarif_learn/OnboardingPage.dart';
import 'package:maarif_learn/PageLogin.dart';
import 'package:maarif_learn/config/api_config.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/biometric_service.dart';
import 'package:maarif_learn/services/push_service.dart';
import 'package:maarif_learn/theme/app_colors.dart';

/// Porte d'entrée de l'application :
/// 1. Session enregistrée + token valide → accueil direct (avec verrou
///    biométrique si l'élève l'a activé).
/// 2. Pas de session / token expiré → écran de connexion.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _biometricBlocked = false;
  String _bioLabel = 'Biométrie';

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Petite pause pour laisser le logo s'afficher proprement
    await Future.delayed(const Duration(milliseconds: 350));

    final token = await AuthStorage.getToken();
    if (token == null || token.isEmpty) {
      // Première ouverture : onboarding avant le login
      if (!await OnboardingPage.alreadySeen()) {
        if (mounted) {
          Navigator.of(context).pushReplacement(PageRouteBuilder(
            pageBuilder: (_, __, ___) => const OnboardingPage(),
            transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            transitionDuration: const Duration(milliseconds: 350),
          ));
        }
        return;
      }
      _goLogin();
      return;
    }

    // ── Vérifier la validité du token (rapide, tolérant au hors-ligne) ──
    bool valid = true; // en cas de coupure réseau, on laisse passer
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.userUrl),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 401 || res.statusCode == 403) {
        valid = false;
      } else if (res.statusCode == 200) {
        // Rafraîchir les infos utilisateur en cache
        try {
          final user = jsonDecode(res.body) as Map<String, dynamic>;
          await AuthStorage.save(token, user);
        } catch (_) {}
      }
    } catch (_) {
      // Hors-ligne : on garde la session locale
    }

    if (!valid) {
      await AuthStorage.clear();
      _goLogin();
      return;
    }

    // ── Verrou biométrique si activé ──
    if (await BiometricService.isEnabled() && await BiometricService.isAvailable()) {
      _bioLabel = await BiometricService.label();
      final ok = await BiometricService.authenticate(
          reason: 'Déverrouille ton espace MaarifMaliEdu');
      if (!ok) {
        if (mounted) setState(() => _biometricBlocked = true);
        return;
      }
    }

    _goHome();
  }

  Future<void> _retryBiometric() async {
    setState(() => _biometricBlocked = false);
    final ok = await BiometricService.authenticate(
        reason: 'Déverrouille ton espace MaarifMaliEdu');
    if (ok) {
      _goHome();
    } else if (mounted) {
      setState(() => _biometricBlocked = true);
    }
  }

  Future<void> _logoutToLogin() async {
    await AuthStorage.clear();
    await BiometricService.setEnabled(false);
    _goLogin();
  }

  void _goHome() {
    if (!mounted) return;
    // Enregistre le token push en arrière-plan (non bloquant)
    PushService.registerToken();
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const Homepage(),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  void _goLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const Pagelogin(),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 350),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 40,
                          offset: const Offset(0, 16)),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/images/maarif_logo.png',
                        width: 110, height: 110, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 22),
                Text('MaarifMaliEdu',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                Text('Écoles Maarif de Türkiye · Mali',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 40),

                if (_biometricBlocked) ...[
                  Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.85), size: 34),
                  const SizedBox(height: 12),
                  Text('Session verrouillée',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _retryBiometric,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.fingerprint_rounded, size: 20),
                    label: Text('Déverrouiller avec $_bioLabel',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _logoutToLogin,
                    child: Text('Se connecter avec un autre compte',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5, color: Colors.white.withValues(alpha: 0.6))),
                  ),
                ] else
                  const SizedBox(
                    width: 26, height: 26,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
