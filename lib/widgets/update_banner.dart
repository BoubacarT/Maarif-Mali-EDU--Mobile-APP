import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:maarif_learn/config/api_config.dart';
import 'package:maarif_learn/widgets/whats_new_sheet.dart';

/// Bannière « mise à jour disponible » : compare la version locale
/// à GET /app/version. Silencieuse en cas d'erreur réseau.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  String? _latest;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    try {
      final res = await http
          .get(Uri.parse(ApiConfig.url('/app/version')), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final latest = (jsonDecode(res.body) as Map<String, dynamic>)['version']?.toString();
      if (latest != null && _isNewer(latest, WhatsNew.currentVersion) && mounted) {
        setState(() => _latest = latest);
      }
    } catch (_) {}
  }

  static bool _isNewer(String remote, String local) {
    List<int> parse(String v) =>
        v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final r = parse(remote), l = parse(local);
    for (var i = 0; i < 3; i++) {
      final a = i < r.length ? r[i] : 0;
      final b = i < l.length ? l[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_latest == null || _dismissed) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF93C5FD)),
      ),
      child: Row(children: [
        const Icon(Icons.system_update_rounded, color: Color(0xFF1D4ED8), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Une nouvelle version ($_latest) est disponible — demande-la à ton établissement.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E40AF))),
        ),
        GestureDetector(
          onTap: () => setState(() => _dismissed = true),
          child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF1D4ED8)),
        ),
      ]),
    );
  }
}
