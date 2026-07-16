import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maarif_learn/PageLogin.dart';
import 'package:maarif_learn/theme/app_colors.dart';

/// Onboarding animé — affiché une seule fois, avant le premier login.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static const _seenKey = 'maarif_onboarding_seen';

  static Future<bool> alreadySeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_seenKey) ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<void> markSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_seenKey, true);
    } catch (_) {}
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      '📚',
      'Tous tes cours,\nmême sans internet',
      'PDF, vidéos et quiz du programme officiel malien. Télécharge tes cours au wifi et révise partout, même hors-ligne.',
      Color(0xFF0A2342),
    ),
    (
      '✨',
      'MAARIFA, ton assistante\npersonnelle',
      'Pose tes questions à la voix 🎤, photographie un exercice 📸 et reçois une explication étape par étape, jour et nuit.',
      Color(0xFF4C1D95),
    ),
    (
      '🎓',
      'Prépare ton DEF ou\nton BAC sereinement',
      'Examens blancs notés sur 20 avec les coefficients officiels, défi du jour, classement de classe et prédiction de ton score.',
      Color(0xFF92400E),
    ),
  ];

  Future<void> _finish() async {
    HapticFeedback.lightImpact();
    await OnboardingPage.markSeen();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const Pagelogin(),
      transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        color: slide.$4,
        child: SafeArea(
          child: Column(children: [
            // Passer
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text('Passer',
                    style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) {
                  HapticFeedback.selectionClick();
                  setState(() => _page = i);
                },
                itemBuilder: (_, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          key: ValueKey(i),
                          tween: Tween(begin: 0, end: 1),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutBack,
                          builder: (_, t, child) =>
                              Transform.scale(scale: t.clamp(0.0, 1.2), child: child),
                          child: Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Text(s.$1, style: const TextStyle(fontSize: 64)),
                          ),
                        ),
                        const SizedBox(height: 36),
                        Text(s.$2,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 26, fontWeight: FontWeight.w900,
                                color: Colors.white, height: 1.25)),
                        const SizedBox(height: 16),
                        Text(s.$3,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14.5,
                                color: Colors.white.withValues(alpha: 0.75),
                                height: 1.6)),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Dots + bouton
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 28),
              child: Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final active = i == _page;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 26 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? AppColors.teal : Colors.white30,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () {
                      if (_page < _slides.length - 1) {
                        _controller.nextPage(
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic);
                      } else {
                        _finish();
                      }
                    },
                    child: Text(
                        _page < _slides.length - 1 ? 'Continuer' : 'Commencer 🚀',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
