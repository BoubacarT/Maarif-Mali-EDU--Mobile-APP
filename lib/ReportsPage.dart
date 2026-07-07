import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/report_service.dart';
import 'package:maarif_learn/theme/app_colors.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _completion;
  Map<String, dynamic>? _mockExams;
  Map<String, dynamic>? _progress;
  Map<String, dynamic>? _goals;

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
    try {
      final results = await Future.wait([
        ReportService.getCompletion(token),
        ReportService.getMockExams(token),
        ReportService.getProgress(token),
        ReportService.getGoals(token),
      ]);
      if (mounted) {
        setState(() {
          _completion = results[0];
          _mockExams = results[1];
          _progress = results[2];
          _goals = results[3];
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Mes rapports',
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: AppColors.teal,
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: Column(children: [
                      _CompletionCard(data: _completion!),
                      const SizedBox(height: 16),
                      _MockExamCard(data: _mockExams!),
                      const SizedBox(height: 16),
                      _ProgressCard(data: _progress!),
                      const SizedBox(height: 16),
                      _GoalsCard(data: _goals!),
                    ]),
                  ),
                ),
    );
  }
}

// ─── Rapport 1 : Complétion ───────────────────────────────────────────────

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final total = data['total_courses'] as int? ?? 0;
    final completed = data['completed_courses'] as int? ?? 0;
    final inProgress = data['in_progress_courses'] as int? ?? 0;
    final questionsAnswered = data['questions_answered'] as int? ?? 0;
    final rate = total > 0 ? completed / total : 0.0;

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
            icon: Icons.auto_stories_rounded,
            color: AppColors.teal,
            label: 'Progression des cours'),
        const SizedBox(height: 16),
        Row(children: [
          // Cercle de progression
          _CircularProgress(value: rate, color: AppColors.teal, size: 90),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricRow(
                    icon: Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    label: 'Terminés',
                    value: '$completed / $total'),
                const SizedBox(height: 8),
                _MetricRow(
                    icon: Icons.play_circle_rounded,
                    color: Colors.blue.shade600,
                    label: 'En cours',
                    value: inProgress.toString()),
                const SizedBox(height: 8),
                _MetricRow(
                    icon: Icons.quiz_rounded,
                    color: const Color(0xFF7C3AED),
                    label: 'Questions répondues',
                    value: questionsAnswered.toString()),
              ],
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── Rapport 2 : Examens blancs ───────────────────────────────────────────

class _MockExamCard extends StatelessWidget {
  const _MockExamCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final sessions = data['total_sessions'] as int? ?? 0;
    final avg = (data['average_net'] as num?)?.toDouble();
    final best = (data['best_net'] as num?)?.toDouble();
    final questionsAnswered = data['questions_answered'] as int? ?? 0;
    final evolution =
        (data['evolution'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
            icon: Icons.description_rounded,
            color: const Color(0xFFF59E0B),
            label: 'Examens blancs'),
        const SizedBox(height: 14),
        Row(children: [
          _BigStat(
              value: sessions.toString(),
              label: 'Sessions',
              color: const Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          if (avg != null)
            _BigStat(
                value: avg.toStringAsFixed(1),
                label: 'Moy. nette',
                color: Colors.blue.shade600),
          const SizedBox(width: 12),
          if (best != null)
            _BigStat(
                value: best.toStringAsFixed(1),
                label: 'Meilleur',
                color: Colors.green.shade600),
        ]),
        if (questionsAnswered > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(Icons.edit_note_rounded,
                  size: 16, color: Colors.amber.shade800),
              const SizedBox(width: 8),
              Text('$questionsAnswered questions traitées au total',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade800)),
            ]),
          ),
        ],
        // Mini évolution
        if (evolution.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Évolution (dernières sessions)',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _MiniBarChart(
              data: evolution
                  .map((e) => (e['net_score'] as num?)?.toDouble() ?? 0)
                  .toList(),
              color: const Color(0xFFF59E0B)),
        ],
      ]),
    );
  }
}

// ─── Rapport 3 : Résultats par matière ───────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final subjects =
        (data['by_subject'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
            icon: Icons.bar_chart_rounded,
            color: const Color(0xFF7C3AED),
            label: 'Résultats par matière'),
        const SizedBox(height: 14),
        if (subjects.isEmpty)
          Text('Aucune donnée disponible.',
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSecondary, fontSize: 13))
        else
          ...subjects.map((s) {
            final name = s['subject'] as String? ?? '';
            final avg = (s['average_score'] as num?)?.toDouble() ?? 0;
            final completed = s['completed'] as int? ?? 0;
            final total = s['total'] as int? ?? 0;
            final rate = (avg / 100).clamp(0.0, 1.0);
            Color barColor;
            if (avg >= 80) {
              barColor = Colors.green.shade600;
            } else if (avg >= 60) {
              barColor = Colors.blue.shade600;
            } else if (avg >= 40) {
              barColor = Colors.orange.shade600;
            } else {
              barColor = Colors.red.shade500;
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(name,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary))),
                    Text('$completed/$total cours',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: barColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${avg.toStringAsFixed(0)}%',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: barColor)),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: rate,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  ),
                ],
              ),
            );
          }),
      ]),
    );
  }
}

// ─── Rapport 4 : Objectifs ────────────────────────────────────────────────

class _GoalsCard extends StatelessWidget {
  const _GoalsCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final total = data['total_goals'] as int? ?? 0;
    final onTrack = data['on_track'] as int? ?? 0;
    final goals =
        (data['goals'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardHeader(
            icon: Icons.flag_rounded,
            color: const Color(0xFFEC4899),
            label: 'Mes objectifs'),
        const SizedBox(height: 14),
        Row(children: [
          _BigStat(value: total.toString(), label: 'Objectifs', color: const Color(0xFFEC4899)),
          const SizedBox(width: 12),
          _BigStat(value: onTrack.toString(), label: 'En bonne voie', color: Colors.green.shade600),
        ]),
        if (goals.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...goals.map((g) {
            final name = g['institution_name'] as String? ?? g['field'] as String? ?? '';
            final current = (g['current_score'] as num?)?.toDouble() ?? 0;
            final required_ = (g['required_score'] as num?)?.toDouble() ?? 100;
            final gap = required_ - current;
            final progress = (current / required_).clamp(0.0, 1.0);
            final color = gap <= 0 ? Colors.green.shade600 : (gap <= 10 ? Colors.orange.shade600 : Colors.red.shade500);
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade100)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(name,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  if (gap <= 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('Objectif atteint ✓',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
                    ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                      '${current.toStringAsFixed(0)} / ${required_.toStringAsFixed(0)}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ]),
                if (gap > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Écart : ${gap.toStringAsFixed(0)} points',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ),
              ]),
            );
          }),
        ],
      ]),
    );
  }
}

// ─── Widgets réutilisables ────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: child,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader(
      {required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.navy)),
    ]);
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow(
      {required this.icon,
      required this.color,
      required this.label,
      required this.value});
  final IconData icon;
  final Color color;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Expanded(
          child: Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.textSecondary))),
      Text(value,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]);
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat(
      {required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _CircularProgress extends StatelessWidget {
  const _CircularProgress(
      {required this.value, required this.color, required this.size});
  final double value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CircularPainter(value: value, color: color),
        child: Center(
          child: Text('${(value * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
        ),
      ),
    );
  }
}

class _CircularPainter extends CustomPainter {
  const _CircularPainter({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;
    final bgPaint = Paint()
      ..color = Colors.grey.shade100
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularPainter old) =>
      old.value != value || old.color != color;
}

class _MiniBarChart extends StatelessWidget {
  const _MiniBarChart({required this.data, required this.color});
  final List<double> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();
    final max_ = data.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 50,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.asMap().entries.map((entry) {
          final pct = max_ > 0 ? entry.value / max_ : 0.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: 40 * pct + 4,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.7 + 0.3 * pct),
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
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
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(error,
              textAlign: TextAlign.center,
              style:
                  GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Réessayer'),
          ),
        ]),
      ),
    );
  }
}
