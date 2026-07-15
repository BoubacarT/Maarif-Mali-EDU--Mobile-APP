import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/theme/app_colors.dart';

/// Carte « J-X avant le DEF/BAC » sur l'accueil.
///
/// L'examen visé est déduit du niveau : 7e-9e → DEF, lycée → BAC.
/// Dates estimées (début juin DEF, mi-juin BAC) de la fin de l'année
/// scolaire en cours — ajustables ici chaque année si besoin.
class ExamCountdownCard extends StatelessWidget {
  const ExamCountdownCard({super.key, required this.levelName});
  final String levelName;

  static (String, DateTime)? examFor(String level, DateTime now) {
    if (level.isEmpty) return null;
    final l = level.toLowerCase();
    final isCollege = l.contains('7e') || l.contains('8e') || l.contains('9e') || l.contains('coll');
    // Année scolaire : à partir de juillet on vise juin de l'année suivante
    final year = now.month >= 7 ? now.year + 1 : now.year;
    return isCollege
        ? ('DEF', DateTime(year, 6, 1))
        : ('BAC', DateTime(year, 6, 15));
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final exam = examFor(levelName, now);
    if (exam == null) return const SizedBox.shrink();
    final (name, date) = exam;
    final days = date.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0 || days > 400) return const SizedBox.shrink();

    // Progression de l'année scolaire (octobre → juin ≈ 270 jours)
    final progress = (1 - days / 270).clamp(0.0, 1.0);
    final urgent = days <= 60;
    final color = urgent ? const Color(0xFFEF4444) : AppColors.teal;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A2342), Color(0xFF14417B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0A2342).withValues(alpha: 0.25),
              blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(children: [
        // J-X
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('J-$days',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
          const SizedBox(height: 2),
          Text('avant le $name',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white70)),
        ]),
        const SizedBox(width: 18),
        // Barre de progression de l'année
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                urgent
                    ? '🔥 Dernière ligne droite, accroche-toi !'
                    : '🎯 Chaque révision compte. Tu avances !',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85))),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 5),
            Text('${(progress * 100).round()}% de l\'année scolaire parcourue',
                style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.white54)),
          ]),
        ),
      ]),
    );
  }
}
