import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/CourseDetailPage.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/study_plan_service.dart';
import 'package:maarif_learn/theme/app_colors.dart';

const _kGreen = Color(0xFF059669);
const _kGreenLight = Color(0xFFD1FAE5);
const _kGreenDark = Color(0xFF047857);

class StudyPlanPage extends StatefulWidget {
  const StudyPlanPage({super.key});
  @override
  State<StudyPlanPage> createState() => _StudyPlanPageState();
}

class _StudyPlanPageState extends State<StudyPlanPage> {
  bool _loading = true;
  String? _error;
  String? _token;
  Map<String, dynamic>? _config;
  List<dynamic> _weekItems = [];

  @override
  void initState() {
    super.initState();
    _load();
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
        StudyPlanService.getConfig(token),
        StudyPlanService.getWeek(token),
      ]);
      if (mounted) {
        setState(() {
          _config = results[0] as Map<String, dynamic>;
          _weekItems = results[1] as List<dynamic>;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _markItem(int itemId, String status) async {
    try {
      await StudyPlanService.updateItemStatus(itemId, status, _token!);
      _load();
    } catch (_) {}
  }

  void _showGenerateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GenerateSheet(token: _token!, onGenerated: _load),
    );
  }

  int get _completedCount => _weekItems.where((i) => (i as Map)['status'] == 'completed').length;
  int get _totalMin => _weekItems.fold(0, (s, i) => s + ((i as Map)['duration_min'] as int? ?? 0));
  int get _completedMin => _weekItems
      .where((i) => (i as Map)['status'] == 'completed')
      .fold(0, (s, i) => s + ((i as Map)['duration_min'] as int? ?? 0));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FB),
        body: Center(child: CircularProgressIndicator(color: _kGreen, strokeWidth: 3)),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off_rounded, size: 52, color: Colors.grey.shade300),
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, height: 1.4)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
                style: FilledButton.styleFrom(backgroundColor: _kGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: RefreshIndicator(
        color: _kGreen,
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            // ── Hero header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _PlanHeroHeader(
                config: _config,
                totalItems: _weekItems.length,
                completedCount: _completedCount,
                totalMin: _totalMin,
                completedMin: _completedMin,
                onGenerate: _showGenerateSheet,
              ),
            ),

            // ── Corps ─────────────────────────────────────────────────────
            if (_weekItems.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyPlan(onGenerate: _showGenerateSheet),
              )
            else ...[
              // Stats rapides
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(child: _StatsRow(
                  completedCount: _completedCount,
                  totalItems: _weekItems.length,
                  completedMin: _completedMin,
                  totalMin: _totalMin,
                  missedCount: _weekItems.where((i) => (i as Map)['status'] == 'missed').length,
                )),
              ),

              // Titre semaine
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(children: [
                    Container(width: 4, height: 20,
                        decoration: BoxDecoration(color: _kGreen, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 10),
                    Text('Programme de la semaine',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy)),
                  ]),
                ),
              ),

              // Jours
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                sliver: SliverToBoxAdapter(child: _WeekView(items: _weekItems, onMark: _markItem)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// HERO HEADER
// ════════════════════════════════════════════════════════════
class _PlanHeroHeader extends StatelessWidget {
  const _PlanHeroHeader({
    required this.config,
    required this.totalItems,
    required this.completedCount,
    required this.totalMin,
    required this.completedMin,
    required this.onGenerate,
  });
  final Map<String, dynamic>? config;
  final int totalItems, completedCount, totalMin, completedMin;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final progress = totalItems == 0 ? 0.0 : completedCount / totalItems;
    final hours = config?['daily_hours'];
    final days = (config?['study_days'] as List?)?.length ?? 0;
    final motivation = totalItems == 0
        ? 'Génère ton plan pour commencer'
        : progress >= 1.0
            ? 'Semaine terminée, bravo ! 🎉'
            : progress >= 0.5
                ? 'Tu es sur la bonne voie 🔥'
                : progress > 0
                    ? 'Bon début, continue ! 🌱'
                    : 'Prêt à démarrer ta semaine ? 💪';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF065F46), _kGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mon Plan d\'Étude',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                      const SizedBox(height: 4),
                      Text(motivation,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: Colors.white70)),
                    ],
                  ),
                ),
                // Bouton générer
                GestureDetector(
                  onTap: onGenerate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text('Générer', style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              // Progression circulaire + infos config
              Row(children: [
                // Anneau de progression
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 6,
                        color: Colors.white12,
                      ),
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        color: Colors.white,
                        backgroundColor: Colors.transparent,
                      ),
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${(progress * 100).round()}%',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text('fait', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white60)),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Config infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(icon: Icons.check_circle_rounded,
                          label: '$completedCount / $totalItems leçons terminées', color: Colors.white),
                      const SizedBox(height: 6),
                      _InfoRow(icon: Icons.schedule_rounded,
                          label: '$completedMin / $totalMin minutes', color: Colors.white70),
                      if (hours != null) ...[
                        const SizedBox(height: 6),
                        _InfoRow(icon: Icons.wb_sunny_rounded,
                            label: '$hours h/jour · $days jours/semaine', color: Colors.white70),
                      ],
                    ],
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
      const SizedBox(width: 7),
      Expanded(child: Text(label, style: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w600, color: color))),
    ]);
  }
}

// ════════════════════════════════════════════════════════════
// STATS ROW
// ════════════════════════════════════════════════════════════
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.completedCount,
    required this.totalItems,
    required this.completedMin,
    required this.totalMin,
    required this.missedCount,
  });
  final int completedCount, totalItems, completedMin, totalMin, missedCount;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCard(
        icon: Icons.check_circle_rounded,
        value: '$completedCount',
        label: 'Terminées',
        color: _kGreen,
        bg: _kGreenLight,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(
        icon: Icons.pending_rounded,
        value: '${totalItems - completedCount - missedCount}',
        label: 'À faire',
        color: AppColors.teal,
        bg: AppColors.teal.withValues(alpha: 0.12),
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(
        icon: Icons.cancel_rounded,
        value: '$missedCount',
        label: 'Manquées',
        color: Colors.red,
        bg: Colors.red.withValues(alpha: 0.1),
      )),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.icon, required this.value, required this.label,
      required this.color, required this.bg});
  final IconData icon;
  final String value, label;
  final Color color, bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy)),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// WEEK VIEW — Groupé par jour
// ════════════════════════════════════════════════════════════
class _WeekView extends StatelessWidget {
  const _WeekView({required this.items, required this.onMark});
  final List<dynamic> items;
  final Future<void> Function(int, String) onMark;

  static const _dayFr = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  static const _monthFr = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> byDay = {};
    for (final item in items) {
      final m = item as Map<String, dynamic>;
      final date = m['planned_date'] as String? ?? 'Autre';
      byDay.putIfAbsent(date, () => []).add(m);
    }
    final sortedDays = byDay.keys.toList()..sort();

    return Column(
      children: sortedDays.map((date) {
        final dayItems = byDay[date]!;
        String dayLabel = date;
        String dayNum = '';
        bool isToday = false;
        try {
          final dt = DateTime.parse(date);
          final now = DateTime.now();
          isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
          dayLabel = _dayFr[dt.weekday - 1];
          dayNum = '${dt.day} ${_monthFr[dt.month - 1]}';
        } catch (_) {}

        final done = dayItems.where((i) => i['status'] == 'completed').length;
        final total = dayItems.length;
        final allDone = done == total && total > 0;
        final totalMinDay = dayItems.fold(0, (s, i) => s + (i['duration_min'] as int? ?? 0));

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: isToday
                ? Border.all(color: _kGreen, width: 2)
                : Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: (isToday ? _kGreen : AppColors.navy).withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // ── Entête du jour ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isToday ? _kGreen.withValues(alpha: 0.06) : Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(children: [
                  // Jour numéro
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: allDone ? _kGreen : (isToday ? _kGreen.withValues(alpha: 0.15) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: allDone
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 22)
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Text(dayNum.split(' ').first,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15, fontWeight: FontWeight.w800,
                                    color: isToday ? _kGreen : AppColors.navy)),
                            Text(dayNum.split(' ').length > 1 ? dayNum.split(' ')[1] : '',
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9, color: isToday ? _kGreen : AppColors.textSecondary)),
                          ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(dayLabel,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 15, fontWeight: FontWeight.w800,
                                color: isToday ? _kGreen : AppColors.navy)),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: _kGreen, borderRadius: BorderRadius.circular(20)),
                            child: Text("Aujourd'hui",
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text('$done/$total leçons · $totalMinDay min',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ),
                  // Mini progress
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                          value: total == 0 ? 0 : done / total,
                          strokeWidth: 4,
                          backgroundColor: Colors.grey.shade200,
                          color: allDone ? _kGreen : AppColors.teal),
                      Text('$done',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: allDone ? _kGreen : AppColors.navy)),
                    ]),
                  ),
                ]),
              ),
              // Barre de progression du jour
              LinearProgressIndicator(
                value: total == 0 ? 0 : done / total,
                backgroundColor: Colors.transparent,
                color: allDone ? _kGreen : AppColors.teal,
                minHeight: 3,
              ),
              // ── Items du jour ────────────────────────────────────────
              ...dayItems.map((item) => _PlanItem(item: item, onMark: onMark)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════════════════════════════════════════
// PLAN ITEM
// ════════════════════════════════════════════════════════════
class _PlanItem extends StatelessWidget {
  const _PlanItem({required this.item, required this.onMark});
  final Map<String, dynamic> item;
  final Future<void> Function(int, String) onMark;

  @override
  Widget build(BuildContext context) {
    final status = item['status'] as String? ?? 'planned';
    final course = item['course'] as Map<String, dynamic>?;
    final courseName = course?['title'] as String? ?? 'Cours';
    final subject = (course?['subject'] as Map?)?['name'] as String? ?? '';
    final duration = item['duration_min'] as int? ?? 0;
    final itemId = item['id'] as int;
    final courseId = course?['id'] as int?;
    final isDone = status == 'completed';
    final isMissed = status == 'missed';
    final isSkipped = status == 'skipped';

    void openCourse() {
      if (courseId == null) return;
      HapticFeedback.lightImpact();
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => CourseDetailPage(courseId: courseId),
      ));
    }

    Color statusColor;
    IconData statusIcon;
    Color bgColor;

    if (isDone) {
      statusColor = _kGreen;
      statusIcon = Icons.check_circle_rounded;
      bgColor = _kGreenLight;
    } else if (isMissed) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel_rounded;
      bgColor = Colors.red.withValues(alpha: 0.08);
    } else if (isSkipped) {
      statusColor = Colors.grey;
      statusIcon = Icons.skip_next_rounded;
      bgColor = Colors.grey.withValues(alpha: 0.08);
    } else {
      statusColor = AppColors.teal;
      statusIcon = Icons.radio_button_unchecked_rounded;
      bgColor = Colors.transparent;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: courseId != null ? openCourse : null,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              // Cercle de statut — tap = marquer terminé
              GestureDetector(
                onTap: status == 'planned'
                    ? () { HapticFeedback.mediumImpact(); onMark(itemId, 'completed'); }
                    : null,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    courseName,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDone || isSkipped ? AppColors.textSecondary : AppColors.navy,
                      decoration: isSkipped ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(children: [
                    if (subject.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(subject,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.teal)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Icon(Icons.timer_outlined, size: 11, color: Colors.grey.shade400),
                    const SizedBox(width: 3),
                    Text('$duration min',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                  ]),
                ]),
              ),
              // Badge « Fait » ou affordance « Étudier »
              if (isDone)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _kGreenLight, borderRadius: BorderRadius.circular(8)),
                  child: Text('✓ Fait',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w800, color: _kGreen)),
                )
              else if (!isSkipped && courseId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Étudier', style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.teal)),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right_rounded, size: 15, color: AppColors.teal),
                  ]),
                ),
              // Menu actions (planned ou missed)
              if (status == 'planned' || status == 'missed')
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade400, size: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (val) => onMark(itemId, val),
                  itemBuilder: (_) => [
                    if (status != 'completed') _menuItem('completed', Icons.check_circle_rounded, _kGreen, 'Marquer terminé'),
                    if (status != 'skipped') _menuItem('skipped', Icons.skip_next_rounded, Colors.grey, 'Passer'),
                    if (status != 'missed') _menuItem('missed', Icons.cancel_rounded, Colors.red, 'Marquer manqué'),
                    if (status == 'missed') _menuItem('planned', Icons.replay_rounded, AppColors.teal, 'Replanifier'),
                  ],
                ),
            ]),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, Color color, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// EMPTY PLAN — illustré et explicatif
// ════════════════════════════════════════════════════════════
class _EmptyPlan extends StatelessWidget {
  const _EmptyPlan({required this.onGenerate});
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // Illustration
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kGreenLight, Color(0xFFA7F3D0)]),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_month_rounded, size: 52, color: _kGreen),
          ),
          const SizedBox(height: 20),
          Text('Aucun plan pour cette semaine',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Génère ton plan personnalisé et l\'IA organisera\ntes cours selon tes disponibilités.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Étapes
          _StepCard(num: '1', icon: Icons.tune_rounded, title: 'Configure', desc: 'Choisis tes heures et tes jours disponibles'),
          const SizedBox(height: 10),
          _StepCard(num: '2', icon: Icons.auto_fix_high_rounded, title: 'Génère', desc: 'L\'IA crée ton planning automatiquement'),
          const SizedBox(height: 10),
          _StepCard(num: '3', icon: Icons.trending_up_rounded, title: 'Progresse', desc: 'Marque tes leçons terminées et suis ta progression'),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onGenerate,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: Text('Générer mon plan d\'étude',
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.num, required this.icon, required this.title, required this.desc});
  final String num, title, desc;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: _kGreenLight, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: _kGreen, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy)),
            Text(desc, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary, height: 1.4)),
          ]),
        ),
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(color: _kGreenLight, shape: BoxShape.circle),
          child: Center(child: Text(num,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w800, color: _kGreen))),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// GENERATE SHEET — redesigné
// ════════════════════════════════════════════════════════════
class _GenerateSheet extends StatefulWidget {
  const _GenerateSheet({required this.token, required this.onGenerated});
  final String token;
  final VoidCallback onGenerated;

  @override
  State<_GenerateSheet> createState() => _GenerateSheetState();
}

class _GenerateSheetState extends State<_GenerateSheet> {
  double _hours = 2;
  final List<String> _allDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Map<String, String> _dayFr = {
    'Mon': 'Lun', 'Tue': 'Mar', 'Wed': 'Mer', 'Thu': 'Jeu',
    'Fri': 'Ven', 'Sat': 'Sam', 'Sun': 'Dim'
  };
  final Set<String> _selectedDays = {'Mon', 'Tue', 'Wed', 'Thu', 'Fri'};
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _generating = false;
  String? _error;

  Future<void> _generate() async {
    if (_selectedDays.isEmpty) {
      setState(() => _error = 'Sélectionnez au moins un jour d\'étude.');
      return;
    }
    setState(() { _generating = true; _error = null; });
    try {
      final date = '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}';
      final res = await StudyPlanService.generate(_hours, _selectedDays.toList(), date, widget.token);
      final created = (res['items_created'] as num?)?.toInt() ?? 0;
      final message = res['message']?.toString();
      if (created == 0) {
        // Rien planifié : on explique pourquoi au lieu de fermer en silence
        if (mounted) {
          setState(() {
            _generating = false;
            _error = message ?? 'Aucune session n\'a pu être planifiée.';
          });
        }
        return;
      }
      widget.onGenerated();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF059669),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Text('✓ $message',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        ));
      }
    } catch (e) {
      if (mounted) setState(() { _generating = false; _error = e.toString().replaceFirst('Exception: ', ''); });
    }
  }

  String _formatDate(DateTime d) {
    const months = ['jan', 'fév', 'mar', 'avr', 'mai', 'jun', 'jul', 'aoû', 'sep', 'oct', 'nov', 'déc'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            // Header
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _kGreenLight, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.auto_fix_high_rounded, color: _kGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Générer mon plan',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
                  Text('L\'IA adapte le planning à tes disponibilités',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
                ]),
              ),
            ]),
            const SizedBox(height: 24),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
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

            // Section heures
            _SectionLabel(label: 'Heures d\'étude par jour', icon: Icons.schedule_rounded),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _kGreenLight, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('${_hours.toStringAsFixed(1)}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 36, fontWeight: FontWeight.w900, color: _kGreenDark)),
                  Text(' h / jour',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kGreen, fontWeight: FontWeight.w600)),
                ]),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _kGreen,
                    thumbColor: _kGreenDark,
                    inactiveTrackColor: Colors.white,
                    overlayColor: _kGreen.withValues(alpha: 0.2),
                  ),
                  child: Slider(value: _hours, min: 0.5, max: 8, divisions: 15,
                      onChanged: (v) => setState(() => _hours = v)),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('30 min', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _kGreen)),
                  Text('8 h', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: _kGreen)),
                ]),
              ]),
            ),
            const SizedBox(height: 20),

            // Section jours
            _SectionLabel(label: 'Jours d\'étude', icon: Icons.calendar_today_rounded),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _allDays.map((d) {
                final sel = _selectedDays.contains(d);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (sel) { _selectedDays.remove(d); } else { _selectedDays.add(d); }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 50,
                    decoration: BoxDecoration(
                      color: sel ? _kGreen : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: sel ? [BoxShadow(
                          color: _kGreen.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))] : [],
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(_dayFr[d]!,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w800,
                              color: sel ? Colors.white : AppColors.textSecondary)),
                      if (sel) ...[
                        const SizedBox(height: 4),
                        Container(width: 4, height: 4,
                            decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle)),
                      ],
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Section date fin
            _SectionLabel(label: 'Date de fin', icon: Icons.event_rounded),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate,
                  firstDate: DateTime.now().add(const Duration(days: 7)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  builder: (_, child) => Theme(
                    data: ThemeData(colorScheme: const ColorScheme.light(primary: _kGreen)),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _endDate = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_month_rounded, color: _kGreen, size: 20),
                  const SizedBox(width: 12),
                  Text(_formatDate(_endDate),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.navy)),
                  const Spacer(),
                  Text('Modifier', style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _kGreen)),
                ]),
              ),
            ),
            const SizedBox(height: 24),

            // Bouton générer
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _generating ? null : _generate,
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  disabledBackgroundColor: _kGreen.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _generating
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text('✦  Générer le plan maintenant',
                        style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: _kGreen),
      const SizedBox(width: 7),
      Text(label, style: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy)),
    ]);
  }
}
