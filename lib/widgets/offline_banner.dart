import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bandeau « mode hors-ligne » affiché quand les données viennent du cache.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.ageLabel, this.onRetry});
  final String? ageLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(children: [
        const Icon(Icons.wifi_off_rounded, color: Color(0xFFB45309), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ageLabel != null
                ? 'Hors-ligne — données enregistrées $ageLabel'
                : 'Hors-ligne — dernières données enregistrées',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF92400E)),
          ),
        ),
        if (onRetry != null)
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFB45309),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Réessayer',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ),
      ]),
    );
  }
}
