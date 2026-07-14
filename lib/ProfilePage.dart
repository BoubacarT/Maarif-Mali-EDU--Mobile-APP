import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:maarif_learn/config/api_config.dart';
import 'package:maarif_learn/PageLogin.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/biometric_service.dart';
import 'package:maarif_learn/services/profile_service.dart';
import 'package:maarif_learn/theme/app_colors.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  StudentProfile? _profile;
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;
  String? _token;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final token = await AuthStorage.getToken();
    if (token == null) {
      if (mounted) setState(() { _loading = false; _error = 'Session expirée. Reconnectez-vous.'; });
      return;
    }
    _token = token;
    try {
      final results = await Future.wait([
        ProfileService.getProfile(token),
        _fetchStats(token),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as StudentProfile;
        _stats = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<Map<String, dynamic>?> _fetchStats(String token) async {
    try {
      final res = await http.get(Uri.parse(ApiConfig.reportsProgressUrl),
          headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'});
      if (res.statusCode == 200) return (jsonDecode(res.body) as Map)['metrics'] as Map<String, dynamic>?;
    } catch (_) {}
    return null;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Se déconnecter ?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text('Tu devras te reconnecter pour accéder à l\'application.',
            style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuler', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Déconnexion', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await AuthStorage.clear();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Pagelogin()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 3));
    }
    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _load);
    }
    final p = _profile!;
    return _ProfileContent(
      profile: p,
      stats: _stats,
      token: _token,
      onRefresh: _load,
      onLogout: _logout,
    );
  }
}

// ════════════════════════════════════════════════════════════
// CONTENU PRINCIPAL
// ════════════════════════════════════════════════════════════
class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.profile,
    required this.stats,
    required this.token,
    required this.onRefresh,
    required this.onLogout,
  });

  final StudentProfile profile;
  final Map<String, dynamic>? stats;
  final String? token;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  String get _fullName {
    final p = '${profile.prenom ?? ''} ${profile.nom ?? ''}'.trim();
    return p.isNotEmpty ? p : profile.name;
  }

  String get _initials {
    final parts = _fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return _fullName.isNotEmpty ? _fullName[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Hero header ──────────────────────────────────────────────
        SliverToBoxAdapter(child: _ProfileHero(
          name: _fullName,
          initials: _initials,
          email: profile.email,
          level: profile.level?['name']?.toString(),
        )),

        // ── Stats ────────────────────────────────────────────────────
        if (stats != null)
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _StatsBar(stats: stats!),
          )),

        // ── Programme officiel de la série ───────────────────────────
        if (profile.subjects.isNotEmpty) ...[
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: _SectionTitle(label: 'Mon programme officiel', icon: Icons.menu_book_rounded),
          )),
          SliverToBoxAdapter(child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _ProgramCard(profile: profile),
          )),
        ],

        // ── Infos compte ─────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: _SectionTitle(label: 'Informations du compte', icon: Icons.person_rounded),
        )),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _InfoCard(profile: profile, fullName: _fullName),
        )),

        // ── Actions ──────────────────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: _SectionTitle(label: 'Paramètres', icon: Icons.settings_rounded),
        )),

        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: _ActionCard(onLogout: onLogout),
        )),

        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// HERO HEADER
// ════════════════════════════════════════════════════════════
class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.name,
    required this.initials,
    required this.email,
    required this.level,
  });
  final String name, initials, email;
  final String? level;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2342), Color(0xFF0D3266)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            children: [
              // Avatar grand format
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.teal, width: 3),
                      boxShadow: [
                        BoxShadow(color: AppColors.teal.withValues(alpha: 0.35),
                            blurRadius: 24, spreadRadius: 4),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFF1A3D6E),
                      child: Text(initials,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 36, fontWeight: FontWeight.w900, color: AppColors.teal)),
                    ),
                  ),
                  // Badge niveau
                  if (level != null)
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.teal,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text('Élève',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(name,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(email,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: Colors.white54),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              if (level != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.school_rounded, size: 14, color: AppColors.teal),
                    const SizedBox(width: 6),
                    Text(level!,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              const SizedBox(height: 24),
              // Décoration en bas du header
              Container(
                height: 28,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// STATS
// ════════════════════════════════════════════════════════════
class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.stats});
  final Map<String, dynamic> stats;

  double _toDouble(dynamic v) =>
      v == null ? 0.0 : (v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0);

  int _toInt(dynamic v) =>
      v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

  @override
  Widget build(BuildContext context) {
    final completed = _toInt(stats['lessons_completed']);
    final total = _toInt(stats['total_available']);
    final completion = _toDouble(stats['completion_rate']);
    final successRate = _toDouble(stats['success_rate']);
    final answered = _toInt(stats['questions_answered']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.navy.withValues(alpha: 0.07),
              blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.insights_rounded, color: AppColors.teal, size: 18),
          const SizedBox(width: 8),
          Text('Ma progression',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _StatCell(
            value: '$completed / $total',
            label: 'Cours\ncomplétés',
            color: AppColors.teal,
            icon: Icons.check_circle_rounded,
          )),
          _Divider(),
          Expanded(child: _StatCell(
            value: '${completion.toStringAsFixed(0)}%',
            label: 'Taux de\ncomplétion',
            color: const Color(0xFF7C3AED),
            icon: Icons.pie_chart_rounded,
          )),
          _Divider(),
          Expanded(child: _StatCell(
            value: '${successRate.toStringAsFixed(0)}%',
            label: 'Taux de\nréussite',
            color: const Color(0xFFF59E0B),
            icon: Icons.star_rounded,
          )),
        ]),
        if (answered > 0) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.quiz_rounded, size: 16, color: Color(0xFF059669)),
              const SizedBox(width: 8),
              Text('$answered questions répondues aux examens blancs',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF059669))),
            ]),
          ),
        ],
        const SizedBox(height: 12),
        // Barre de progression globale
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Progression globale',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: AppColors.textSecondary)),
            Text('${completion.toStringAsFixed(0)}%',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.teal)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: completion / 100,
              minHeight: 10,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label, required this.color, required this.icon});
  final String value, label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(height: 8),
      Text(value,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.navy),
          textAlign: TextAlign.center),
      const SizedBox(height: 2),
      Text(label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 10, color: AppColors.textSecondary, height: 1.3),
          textAlign: TextAlign.center),
    ]);
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 60, color: Colors.grey.shade100);
  }
}

// ════════════════════════════════════════════════════════════
// INFO CARD
// ════════════════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.profile, required this.fullName});
  final StudentProfile profile;
  final String fullName;

  @override
  Widget build(BuildContext context) {
    final level = profile.level?['name']?.toString();
    final adresse = profile.adresse?.isNotEmpty == true ? profile.adresse! : null;
    final dob = profile.dateNaissance?.isNotEmpty == true ? profile.dateNaissance! : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.navy.withValues(alpha: 0.07),
              blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(children: [
        _InfoRow(icon: Icons.badge_rounded, label: 'Nom complet', value: fullName, iconColor: AppColors.teal),
        _Separator(),
        _InfoRow(icon: Icons.mail_rounded, label: 'Adresse e-mail', value: profile.email, iconColor: const Color(0xFF7C3AED)),
        _Separator(),
        _InfoRow(icon: Icons.school_rounded, label: 'Niveau scolaire', value: level ?? 'Non renseigné', iconColor: const Color(0xFFF59E0B), empty: level == null),
        _Separator(),
        _InfoRow(icon: Icons.location_on_rounded, label: 'Adresse', value: adresse ?? 'Non renseignée', iconColor: const Color(0xFFEF4444), empty: adresse == null),
        _Separator(),
        _InfoRow(icon: Icons.cake_rounded, label: 'Date de naissance', value: dob ?? 'Non renseignée', iconColor: const Color(0xFF059669), empty: dob == null, last: true),
      ]),
    );
  }
}

class _Separator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.empty = false,
    this.last = false,
  });
  final IconData icon;
  final String label, value;
  final Color iconColor;
  final bool empty, last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, last ? 14 : 14),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: empty ? Colors.grey.shade400 : AppColors.textPrimary)),
          ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// ACTIONS CARD
// ════════════════════════════════════════════════════════════
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.navy.withValues(alpha: 0.07),
              blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(children: [
        _ActionRow(
          icon: Icons.notifications_rounded,
          label: 'Notifications',
          sublabel: 'Gérer mes alertes d\'apprentissage',
          iconColor: const Color(0xFF7C3AED),
          onTap: () {},
        ),
        Padding(
          padding: const EdgeInsets.only(left: 68),
          child: Divider(height: 1, color: Colors.grey.shade100),
        ),
        _ActionRow(
          icon: Icons.lock_rounded,
          label: 'Changer le mot de passe',
          sublabel: 'Sécuriser mon compte',
          iconColor: const Color(0xFFF59E0B),
          onTap: () => _showChangePasswordSheet(context),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 68),
          child: Divider(height: 1, color: Colors.grey.shade100),
        ),
        const _BiometricRow(),
        Padding(
          padding: const EdgeInsets.only(left: 68),
          child: Divider(height: 1, color: Colors.grey.shade100),
        ),
        _ActionRow(
          icon: Icons.logout_rounded,
          label: 'Se déconnecter',
          sublabel: 'Quitter l\'application',
          iconColor: Colors.red.shade500,
          textColor: Colors.red.shade600,
          onTap: onLogout,
          last: true,
        ),
      ]),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.iconColor,
    required this.onTap,
    this.textColor,
    this.last = false,
  });
  final IconData icon;
  final String label, sublabel;
  final Color iconColor;
  final Color? textColor;
  final VoidCallback onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: last ? Radius.zero : Radius.zero,
        bottom: last ? const Radius.circular(24) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: textColor ?? AppColors.textPrimary)),
              Text(sublabel,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey.shade300),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// CHANGER MOT DE PASSE
// ════════════════════════════════════════════════════════════
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showCurrent = false, _showNew = false, _showConfirm = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    if (_newCtrl.text.length < 8) {
      setState(() => _error = 'Le mot de passe doit faire au moins 8 caractères.');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      final token = await AuthStorage.getToken();
      final res = await http.post(
        Uri.parse(ApiConfig.url('/user/change-password')),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_password': _currentCtrl.text,
          'password': _newCtrl.text,
          'password_confirmation': _confirmCtrl.text,
        }),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Mot de passe modifié avec succès.',
              style: GoogleFonts.plusJakartaSans()),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        final body = jsonDecode(res.body) as Map?;
        setState(() {
          _submitting = false;
          _error = body?['message']?.toString() ?? 'Erreur lors du changement.';
        });
      }
    } catch (_) {
      if (mounted) setState(() { _submitting = false; _error = 'Erreur réseau.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.lock_rounded, color: Colors.amber.shade700, size: 22)),
            const SizedBox(width: 12),
            Text('Changer le mot de passe',
                style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy)),
          ]),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200)),
              child: Row(children: [
                Icon(Icons.error_outline_rounded, color: Colors.red.shade600, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: GoogleFonts.plusJakartaSans(color: Colors.red.shade700, fontSize: 12))),
              ]),
            ),
          ],
          _PwdField(controller: _currentCtrl, label: 'Mot de passe actuel',
              show: _showCurrent, onToggle: () => setState(() => _showCurrent = !_showCurrent)),
          const SizedBox(height: 12),
          _PwdField(controller: _newCtrl, label: 'Nouveau mot de passe',
              show: _showNew, onToggle: () => setState(() => _showNew = !_showNew)),
          const SizedBox(height: 12),
          _PwdField(controller: _confirmCtrl, label: 'Confirmer le nouveau mot de passe',
              show: _showConfirm, onToggle: () => setState(() => _showConfirm = !_showConfirm)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                disabledBackgroundColor: AppColors.navy.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : Text('Modifier le mot de passe',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _PwdField extends StatelessWidget {
  const _PwdField({required this.controller, required this.label, required this.show, required this.onToggle});
  final TextEditingController controller;
  final String label;
  final bool show;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: !show,
      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, color: AppColors.navy),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.teal, width: 2)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: Colors.grey.shade400, size: 20),
          onPressed: onToggle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SECTION TITLE
// ════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.teal),
      const SizedBox(width: 8),
      Text(label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy)),
    ]);
  }
}

// ════════════════════════════════════════════════════════════
// ERROR VIEW
// ════════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 52, color: Colors.grey.shade300),
          const SizedBox(height: 14),
          Text(error, textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Réessayer'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// PROGRAMME OFFICIEL DE LA SÉRIE (barème Maarif 2025-2026)
// ════════════════════════════════════════════════════════════
class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.profile});
  final StudentProfile profile;

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF12A5B4);
    final h = hex.replaceAll('#', '');
    return Color(int.tryParse('FF$h', radix: 16) ?? 0xFF12A5B4);
  }

  String _fmtCoef(dynamic v) {
    final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    return d == d.roundToDouble()
        ? d.toInt().toString()
        : d.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context) {
    final withCoef =
        profile.subjects.where((s) => s['coefficient'] != null).toList();
    final maxCoef = withCoef.isEmpty
        ? 1.0
        : withCoef
            .map((s) => (s['coefficient'] as num).toDouble())
            .reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(
              profile.level?['name']?.toString() ?? 'Ma classe',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF11284A)),
            ),
          ),
          if (profile.totalCoefficient > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDFAFB),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Total coef ${_fmtCoef(profile.totalCoefficient)}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0C6B76)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text(
          'Coefficients du programme officiel malien — concentre-toi sur les plus élevés !',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 14),
        ...withCoef.map((s) {
          final coef = (s['coefficient'] as num).toDouble();
          final color = _parseColor(s['color']?.toString());
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: Text(
                  s['name']?.toString() ?? '',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: coef / maxCoef,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  'coef ${_fmtCoef(coef)}',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0C6B76)),
                ),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// LIGNE VERROU BIOMÉTRIQUE (Face ID / Empreinte)
// ════════════════════════════════════════════════════════════
class _BiometricRow extends StatefulWidget {
  const _BiometricRow();

  @override
  State<_BiometricRow> createState() => _BiometricRowState();
}

class _BiometricRowState extends State<_BiometricRow> {
  bool _available = false;
  bool _enabled = false;
  String _label = 'Biométrie';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    final label = available ? await BiometricService.label() : 'Biométrie';
    if (mounted) {
      setState(() {
        _available = available;
        _enabled = enabled;
        _label = label;
      });
    }
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      // Vérifier la biométrie avant d'activer (preuve que ça fonctionne)
      final ok = await BiometricService.authenticate(
          reason: 'Confirme ton identité pour activer $_label');
      if (!ok) return;
    }
    await BiometricService.setEnabled(value);
    HapticFeedback.mediumImpact();
    if (mounted) {
      setState(() => _enabled = value);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: value ? const Color(0xFF059669) : AppColors.navy,
        content: Text(
          value
              ? '$_label activé — l\'app sera verrouillée au démarrage.'
              : 'Verrou biométrique désactivé.',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.fingerprint_rounded, color: AppColors.teal, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Connexion $_label',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text('Déverrouiller l\'app sans saisir le mot de passe',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5, color: AppColors.textSecondary)),
          ]),
        ),
        Switch.adaptive(
          value: _enabled,
          activeThumbColor: AppColors.teal,
          onChanged: _toggle,
        ),
      ]),
    );
  }
}
