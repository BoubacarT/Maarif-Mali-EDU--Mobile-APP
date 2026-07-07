import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/theme/app_colors.dart';

/// Titre stylisé « maarifmaliedu » (maarif + maliedu) pour la charte internationale.
class MaarifBrandTitle extends StatelessWidget {
  const MaarifBrandTitle({
    super.key,
    this.size = 32,
    this.alignment = MainAxisAlignment.center,
  });

  final double size;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      height: 1.05,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment,
        children: [
          Text('maarif', style: base.copyWith(color: AppColors.tealLight)),
          Text('maliedu', style: base.copyWith(color: Colors.white)),
        ],
      ),
    );
  }
}

/// Variante sur fond clair (cartes, headers).
class MaarifBrandTitleOnLight extends StatelessWidget {
  const MaarifBrandTitleOnLight({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
      height: 1.1,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('maarif', style: base.copyWith(color: AppColors.teal)),
          Text('maliedu', style: base.copyWith(color: AppColors.navy)),
        ],
      ),
    );
  }
}
