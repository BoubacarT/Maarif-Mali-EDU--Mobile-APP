import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/mock_exam_service.dart';
import 'package:maarif_learn/theme/app_colors.dart';

const _kAmber = Color(0xFFF59E0B);
const _kAmberDark = Color(0xFFB45309);
const _kAmberLight = Color(0xFFFFFBEB);

double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _toInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

class MockExamPage extends StatefulWidget {
  const MockExamPage({super.key});
  @override
  State<MockExamPage> createState() => _MockExamPageState();
}

class _MockExamPageState extends State<MockExamPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  String? _error;
  String? _token;
  List<dynamic> _templates = [];
  List<dynamic> _sessions = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final token = await AuthStorage.getToken();
    if (token == null) {
      if (mounted) setState(() { _loading = false; _error = 'Session expirée.'; });
      return;
    }
    _token = token;
    try {
      final results = await Future.wait([
        MockExamService.getTemplates(token),
        MockExamService.getSessions(token),
      ]);
      if (mounted) {
        setState(() {
          _templates = results[0];
          _sessions = results[1];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(children: [
        // ── Hero header ─────────────────────────────────────────────────
        _ExamHeroHeader(
          sessionsCount: _sessions.length,
          tabs: _tabs,
        ),
        // ── Contenu ─────────────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _kAmber, strokeWidth: 3))
              : _error != null
                  ? _ErrorView(error: _error!, onRetry: _load)
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _TemplatesTab(templates: _templates, token: _token!, onSubmitted: _load),
                        _SessionsTab(sessions: _sessions),
                      ],
                    ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// HERO HEADER
// ════════════════════════════════════════════════════════════
class _ExamHeroHeader extends StatelessWidget {
  const _ExamHeroHeader({required this.sessionsCount, required this.tabs});
  final int sessionsCount;
  final TabController tabs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF92400E), _kAmberDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Examens Blancs',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('Entraîne-toi comme au vrai BAC',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white60)),
                    ]),
                  ]),
                  const SizedBox(height: 14),
                  // Explication du concept
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(children: [
                      const Icon(Icons.lightbulb_rounded, color: _kAmber, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Fais un examen sur papier → reviens ici pour saisir tes réponses → vois ton score calculé automatiquement.',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white.withValues(alpha: 0.8), height: 1.4),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // Onglets
            TabBar(
              controller: tabs,
              labelColor: _kAmber,
              unselectedLabelColor: Colors.white38,
              indicatorColor: _kAmber,
              indicatorWeight: 3,
              dividerColor: Colors.transparent,
              labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: [
                const Tab(text: 'Examens disponibles'),
                Tab(text: 'Mes résultats ($sessionsCount)'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// ONGLET MODÈLES
// ════════════════════════════════════════════════════════════
class _TemplatesTab extends StatelessWidget {
  const _TemplatesTab({required this.templates, required this.token, required this.onSubmitted});
  final List<dynamic> templates;
  final String token;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    if (templates.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _kAmberLight, shape: BoxShape.circle),
            child: const Icon(Icons.assignment_outlined, size: 44, color: _kAmber),
          ),
          const SizedBox(height: 16),
          Text('Aucun examen disponible pour l\'instant',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.navy)),
          const SizedBox(height: 6),
          Text('Ton professeur n\'a pas encore créé d\'examen.',
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 12)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: templates.length,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, i) {
        final t = templates[i] as Map<String, dynamic>;
        final subjects = (t['subjects'] as List?)?.cast<Map<String, dynamic>>() ?? [];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _ExamCard(
            template: t,
            subjects: subjects,
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => _ExamFormPage(
                    template: t, subjects: subjects, token: token, onSubmitted: onSubmitted),
                transitionsBuilder: (_, anim, __, child) => SlideTransition(
                  position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.template, required this.subjects, required this.onTap});
  final Map<String, dynamic> template;
  final List<Map<String, dynamic>> subjects;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNet = template['scoring_formula'] == 'net';
    final totalQ = subjects.fold<int>(0, (s, sub) => s + ((sub['total_questions'] as int?) ?? 0));
    final durationEst = ((totalQ * 1.5) / 60).ceil(); // estimation ~1.5 min/question

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _kAmber.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(children: [
        // ── Banner top ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF78350F), _kAmberDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Row(children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(template['name'] as String? ?? '',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 4),
                Row(children: [
                  _ExamBadge(label: '$totalQ questions', icon: Icons.quiz_outlined),
                  const SizedBox(width: 8),
                  _ExamBadge(label: '~$durationEst h', icon: Icons.timer_outlined),
                ]),
              ]),
            ),
          ]),
        ),

        // ── Scoring info ──────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isNet ? Colors.orange.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isNet ? Colors.orange.shade200 : Colors.blue.shade200),
          ),
          child: Row(children: [
            Icon(Icons.calculate_rounded,
                size: 18, color: isNet ? Colors.orange.shade700 : Colors.blue.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isNet ? 'Barème avec pénalité (score net)' : 'Barème simple (score brut)',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isNet ? Colors.orange.shade800 : Colors.blue.shade800)),
                Text(isNet
                    ? 'Score = Bonnes − (Mauvaises ÷ 4)'
                    : 'Score = nombre de bonnes réponses uniquement',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: isNet ? Colors.orange.shade700 : Colors.blue.shade700)),
              ]),
            ),
          ]),
        ),

        // ── Matières ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Matières incluses',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...subjects.map((s) {
                final name = s['name'] as String? ?? '';
                final q = (s['total_questions'] as int?) ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: _kAmber, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(name,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.navy)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: _kAmberLight, borderRadius: BorderRadius.circular(8)),
                      child: Text('$q Q',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w700, color: _kAmberDark)),
                    ),
                  ]),
                );
              }),
            ],
          ),
        ),

        // ── Bouton ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_kAmber, _kAmberDark]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: _kAmber.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Saisir mes réponses',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ExamBadge extends StatelessWidget {
  const _ExamBadge({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: Colors.white70),
        const SizedBox(width: 4),
        Text(label,
            style: GoogleFonts.plusJakartaSans(
                fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// FORMULAIRE DE SAISIE — étape par étape
// ════════════════════════════════════════════════════════════
class _ExamFormPage extends StatefulWidget {
  const _ExamFormPage({
    required this.template,
    required this.subjects,
    required this.token,
    required this.onSubmitted,
  });
  final Map<String, dynamic> template;
  final List<Map<String, dynamic>> subjects;
  final String token;
  final VoidCallback onSubmitted;

  @override
  State<_ExamFormPage> createState() => _ExamFormPageState();
}

class _ExamFormPageState extends State<_ExamFormPage> {
  late final List<Map<String, TextEditingController>> _controllers;
  int _step = 0;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _controllers = widget.subjects.map((_) => {
      'correct': TextEditingController(text: '0'),
      'wrong': TextEditingController(text: '0'),
      'empty': TextEditingController(text: '0'),
    }).toList();
  }

  @override
  void dispose() {
    for (final m in _controllers) {
      for (final c in m.values) { c.dispose(); }
    }
    super.dispose();
  }

  int _parse(String key, int index) => int.tryParse(_controllers[index][key]!.text.trim()) ?? 0;

  double _netPreview(int i) => _parse('correct', i) - (_parse('wrong', i) / 4);

  Future<void> _submit() async {
    // Validation
    for (int i = 0; i < widget.subjects.length; i++) {
      final total = (widget.subjects[i]['total_questions'] as int?) ?? 0;
      final sum = _parse('correct', i) + _parse('wrong', i) + _parse('empty', i);
      if (total > 0 && sum > total) {
        setState(() => _error = 'Total dépasse ${widget.subjects[i]['name']} ($total Q).');
        return;
      }
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final subjectScores = List.generate(widget.subjects.length, (i) {
        final subj = widget.subjects[i];
        final total = (subj['total_questions'] as int?) ?? 0;
        final c = _parse('correct', i);
        final w = _parse('wrong', i);
        final e = _parse('empty', i);
        return {'subject': subj['name'], 'total': total > 0 ? total : c + w + e,
                'correct': c, 'wrong': w, 'empty': e};
      });

      final now = DateTime.now();
      final date = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
      final res = await MockExamService.submitSession(
          widget.template['id'] as int, subjectScores, date, widget.token);
      if (mounted) setState(() { _submitting = false; _result = res; });
    } catch (e) {
      if (mounted) setState(() { _submitting = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return _ResultPage(result: _result!, onDone: () {
        widget.onSubmitted();
        Navigator.pop(context);
      });
    }

    final subj = widget.subjects[_step];
    final name = subj['name'] as String? ?? '';
    final total = subj['total_questions'] as int?;
    final isNet = widget.template['scoring_formula'] == 'net';
    final isLast = _step == widget.subjects.length - 1;
    final net = _netPreview(_step);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: _kAmberDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.template['name'] as String? ?? '',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: Column(children: [
        // Progress steps
        Container(
          color: _kAmberDark,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(children: [
            Row(
              children: List.generate(widget.subjects.length, (i) {
                final done = i < _step;
                final current = i == _step;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 6,
                    decoration: BoxDecoration(
                      color: done || current ? _kAmber : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            Text('Matière ${_step + 1} sur ${widget.subjects.length}',
                style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white60)),
          ]),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Subject header
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF78350F), _kAmberDark]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.subject_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(name,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      if (total != null)
                        Text('$total questions au total',
                            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white70)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 20),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                      color: Colors.red.shade50, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200)),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded, color: Colors.red.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: GoogleFonts.plusJakartaSans(color: Colors.red.shade700, fontSize: 12))),
                  ]),
                ),
              ],

              // Instructions
              Text('Combien de réponses as-tu données ?',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy)),
              const SizedBox(height: 4),
              Text('Saisis le nombre pour chaque catégorie',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 20),

              // 3 champs
              Row(children: [
                Expanded(child: _InputField(
                  controller: _controllers[_step]['correct']!,
                  label: 'Bonnes',
                  sublabel: 'Réponses correctes',
                  color: const Color(0xFF059669),
                  icon: Icons.check_circle_rounded,
                  onChange: () => setState(() {}),
                )),
                const SizedBox(width: 10),
                Expanded(child: _InputField(
                  controller: _controllers[_step]['wrong']!,
                  label: 'Mauvaises',
                  sublabel: 'Réponses fausses',
                  color: Colors.red.shade500,
                  icon: Icons.cancel_rounded,
                  onChange: () => setState(() {}),
                )),
                const SizedBox(width: 10),
                Expanded(child: _InputField(
                  controller: _controllers[_step]['empty']!,
                  label: 'Vides',
                  sublabel: 'Non répondues',
                  color: Colors.grey.shade400,
                  icon: Icons.remove_circle_outline_rounded,
                  onChange: () => setState(() {}),
                )),
              ]),
              const SizedBox(height: 16),

              // Preview score
              if (isNet)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: net >= 0 ? const Color(0xFFECFDF5) : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: net >= 0 ? const Color(0xFF6EE7B7) : Colors.red.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.calculate_rounded,
                        color: net >= 0 ? const Color(0xFF059669) : Colors.red.shade500, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Score net estimé pour $name',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, color: AppColors.textSecondary)),
                        Text(net.toStringAsFixed(2),
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 24, fontWeight: FontWeight.w900,
                                color: net >= 0 ? const Color(0xFF059669) : Colors.red.shade500)),
                      ]),
                    ),
                    Text('points', style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 11)),
                  ]),
                ),
            ]),
          ),
        ),

        // Boutons navigation
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(children: [
              if (_step > 0)
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () => setState(() => _step--),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kAmber),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Icon(Icons.arrow_back_rounded, color: _kAmber),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: FilledButton(
                  onPressed: _submitting ? null : () {
                    if (isLast) {
                      _submit();
                    } else {
                      setState(() { _step++; _error = null; });
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _kAmber,
                    disabledBackgroundColor: _kAmber.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(isLast ? 'Calculer mon score' : 'Matière suivante',
                              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 6),
                          Icon(isLast ? Icons.assessment_rounded : Icons.arrow_forward_rounded, size: 18),
                        ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.icon,
    required this.onChange,
  });
  final TextEditingController controller;
  final String label, sublabel;
  final Color color;
  final IconData icon;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 10)],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: (_) => onChange(),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.navy),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color.withValues(alpha: 0.3))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: color, width: 2)),
            filled: true,
            fillColor: color.withValues(alpha: 0.05),
          ),
        ),
        const SizedBox(height: 4),
        Text(sublabel, style: GoogleFonts.plusJakartaSans(
            fontSize: 9, color: Colors.grey.shade400), textAlign: TextAlign.center),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// PAGE RÉSULTATS
// ════════════════════════════════════════════════════════════
class _ResultPage extends StatelessWidget {
  const _ResultPage({required this.result, required this.onDone});
  final Map<String, dynamic> result;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final totalNet = _toDouble(result['total_net']);
    final scores = (result['scores'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
    final best = scores.isEmpty ? null : scores.reduce((a, b) =>
        _toDouble(a['net']) >= _toDouble(b['net']) ? a : b);
    final worst = scores.isEmpty ? null : scores.reduce((a, b) =>
        _toDouble(a['net']) <= _toDouble(b['net']) ? a : b);

    final isPositive = totalNet >= 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPositive
                      ? [const Color(0xFF065F46), const Color(0xFF059669)]
                      : [const Color(0xFF991B1B), const Color(0xFFEF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(children: [
                    Row(children: [
                      IconButton(
                        onPressed: onDone,
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                      ),
                      Expanded(
                        child: Text('Résultats de l\'examen',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                            textAlign: TextAlign.center),
                      ),
                      const SizedBox(width: 48),
                    ]),
                    const SizedBox(height: 24),
                    // Score géant
                    Text(totalNet.toStringAsFixed(2),
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white, height: 1)),
                    Text('points nets au total',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, color: Colors.white70)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(isPositive ? '🎉 Bravo, score positif !' : '📚 Continue à travailler !',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(delegate: SliverChildListDelegate([
              // Meilleure / pire matière
              if (best != null && worst != null) ...[
                Row(children: [
                  Expanded(child: _HighlightBox(
                    icon: Icons.trending_up_rounded,
                    label: 'Meilleure matière',
                    subject: best['subject']?.toString() ?? '',
                    score: _toDouble(best['net']),
                    color: const Color(0xFF059669),
                    bg: const Color(0xFFECFDF5),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _HighlightBox(
                    icon: Icons.trending_down_rounded,
                    label: 'À améliorer',
                    subject: worst['subject']?.toString() ?? '',
                    score: _toDouble(worst['net']),
                    color: Colors.red.shade500,
                    bg: Colors.red.shade50,
                  )),
                ]),
                const SizedBox(height: 20),
              ],

              // Titre detail
              Text('Détail par matière',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy)),
              const SizedBox(height: 12),

              // Cartes matières
              ...scores.map((s) => _SubjectResultCard(score: s)),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: onDone,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Retour aux examens',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              const SizedBox(height: 40),
            ])),
          ),
        ],
      ),
    );
  }
}

class _HighlightBox extends StatelessWidget {
  const _HighlightBox({required this.icon, required this.label, required this.subject,
      required this.score, required this.color, required this.bg});
  final IconData icon;
  final String label, subject;
  final double score;
  final Color color, bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 5),
          Expanded(child: Text(label,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w700, color: color))),
        ]),
        const SizedBox(height: 8),
        Text(subject, style: GoogleFonts.plusJakartaSans(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        Text(score.toStringAsFixed(2),
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      ]),
    );
  }
}

class _SubjectResultCard extends StatelessWidget {
  const _SubjectResultCard({required this.score});
  final Map<String, dynamic> score;

  @override
  Widget build(BuildContext context) {
    final name = score['subject']?.toString() ?? '';
    final net = _toDouble(score['net']);
    final correct = _toInt(score['correct']);
    final wrong = _toInt(score['wrong']);
    final empty = _toInt(score['empty']);
    final total = _toInt(score['total']);
    final rate = _toDouble(score['success_rate'] ?? (total > 0 ? correct / total * 100 : 0));
    final isGood = net >= 0;
    final barColor = isGood ? const Color(0xFF059669) : Colors.red.shade500;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: (isGood ? const Color(0xFF6EE7B7) : Colors.red.shade200)),
        boxShadow: [BoxShadow(
            color: barColor.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name, style: GoogleFonts.plusJakartaSans(
              fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.navy))),
          Text(net.toStringAsFixed(2), style: GoogleFonts.plusJakartaSans(
              fontSize: 24, fontWeight: FontWeight.w900, color: barColor)),
          const SizedBox(width: 4),
          Text('pts', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 10),
        // Stats visuelles
        Row(children: [
          _ResultChip('✓ $correct Bonnes', const Color(0xFF059669), const Color(0xFFECFDF5)),
          const SizedBox(width: 6),
          _ResultChip('✗ $wrong Fausses', Colors.red.shade500, Colors.red.shade50),
          const SizedBox(width: 6),
          _ResultChip('– $empty Vides', Colors.grey.shade500, Colors.grey.shade100),
        ]),
        const SizedBox(height: 10),
        // Barre de réussite
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade100,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text('${rate.toStringAsFixed(0)}%',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700, color: barColor)),
        ]),
      ]),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip(this.label, this.color, this.bg);
  final String label;
  final Color color, bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.plusJakartaSans(
          fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ════════════════════════════════════════════════════════════
// ONGLET MES RÉSULTATS
// ════════════════════════════════════════════════════════════
class _SessionsTab extends StatelessWidget {
  const _SessionsTab({required this.sessions});
  final List<dynamic> sessions;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: _kAmberLight, shape: BoxShape.circle),
              child: const Icon(Icons.history_edu_rounded, size: 44, color: _kAmber),
            ),
            const SizedBox(height: 16),
            Text('Aucun résultat enregistré',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text('Fais un examen blanc puis saisis tes\nréponses pour voir tes résultats ici.',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                textAlign: TextAlign.center),
          ]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: sessions.length,
      itemBuilder: (context, i) {
        final s = sessions[i] as Map<String, dynamic>;
        final template = s['template'] != null ? Map<String, dynamic>.from(s['template'] as Map) : null;
        final totalNet = _toDouble(s['total_net']);
        final date = s['exam_date']?.toString() ?? '';
        final scores = (s['scores'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        final worst = scores.isEmpty ? null : scores.reduce((a, b) =>
            _toDouble(a['net']) <= _toDouble(b['net']) ? a : b);
        final isPos = totalNet >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(
                color: (isPos ? const Color(0xFF059669) : Colors.red).withValues(alpha: 0.08),
                blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _kAmberLight, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.assessment_rounded, color: _kAmber, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(template?['name'] as String? ?? 'Examen',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
                    Text(date, style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(totalNet.toStringAsFixed(2), style: GoogleFonts.plusJakartaSans(
                      fontSize: 26, fontWeight: FontWeight.w900,
                      color: isPos ? const Color(0xFF059669) : Colors.red.shade500)),
                  Text('pts nets', style: GoogleFonts.plusJakartaSans(
                      fontSize: 10, color: AppColors.textSecondary)),
                ]),
              ]),
              if (worst != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.flag_rounded, size: 13, color: Colors.red.shade500),
                    const SizedBox(width: 5),
                    Text('À renforcer : ${worst['subject']} (${_toDouble(worst['net']).toStringAsFixed(1)} pts)',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: Colors.red.shade600, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
              // Scores chips
              if (scores.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 4, children: scores.map((sc) {
                  final n = _toDouble(sc['net']);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: n >= 0 ? const Color(0xFFECFDF5) : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${sc['subject']}: ${n.toStringAsFixed(1)}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: n >= 0 ? const Color(0xFF059669) : Colors.red.shade500)),
                  );
                }).toList()),
              ],
            ]),
          ),
        );
      },
    );
  }
}

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
            style: FilledButton.styleFrom(backgroundColor: _kAmber,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      ),
    );
  }
}
