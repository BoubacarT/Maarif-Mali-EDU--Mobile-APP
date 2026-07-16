import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:maarif_learn/theme/app_colors.dart';

/// Écran « Nouveautés » affiché une seule fois après chaque mise à jour.
///
/// À chaque nouvelle version : incrémenter [currentVersion] et mettre à jour
/// la liste [_features].
class WhatsNew {
  static const currentVersion = '1.3.0';
  static const _prefsKey = 'maarif_seen_version';

  static const _features = [
    ('🎤', 'Parle à MAARIFA', 'Pose tes questions à la voix et active la lecture à voix haute des réponses.'),
    ('📸', 'Photo d\'exercice', 'Photographie un exercice de ton cahier — MAARIFA l\'explique étape par étape.'),
    ('⚡', 'Défi du jour', '5 questions éclair chaque jour, XP doublés — garde ta série 🔥 !'),
    ('📤', 'Partage ton bulletin', 'Partage tes résultats d\'examen blanc sur WhatsApp en une image.'),
    ('🎨', 'Nouveau look', 'Icône officielle, écran de démarrage et présentation à la première ouverture.'),
  ];

  /// Affiche la feuille si cette version n'a pas encore été vue.
  static Future<void> maybeShow(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_prefsKey) == currentVersion) return;
      await prefs.setString(_prefsKey, currentVersion);
      if (!context.mounted) return;
      HapticFeedback.lightImpact();
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _WhatsNewSheet(),
      );
    } catch (_) {}
  }
}

class _WhatsNewSheet extends StatelessWidget {
  const _WhatsNewSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 44, height: 4,
          decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 14),
        Text('Quoi de neuf ?',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
        Text('Version ${WhatsNew.currentVersion}',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: WhatsNew._features.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              final (emoji, title, desc) = WhatsNew._features[i];
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy)),
                    const SizedBox(height: 2),
                    Text(desc,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: AppColors.textSecondary, height: 1.4)),
                  ]),
                ),
              ]);
            },
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('C\'est parti !',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
            ),
          ),
        ),
      ]),
    );
  }
}
