import 'package:flutter/material.dart';

/// Couleurs dérivées du logo Maarif (turquoise, bleu marine, blanc).
abstract final class AppColors {
  static const Color teal = Color(0xFF00B4C5);
  static const Color tealLight = Color(0xFF4DD4E0);
  static const Color tealDark = Color(0xFF0090A0);

  static const Color navy = Color(0xFF0A2342);
  static const Color navyLight = Color(0xFF1A3A5C);
  static const Color navyMuted = Color(0xFF2D4A6F);

  static const Color surface = Color(0xFFF4F8FB);
  static const Color surfaceCard = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, navyLight, Color(0xFF0D2847)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [teal, tealDark],
  );
}
