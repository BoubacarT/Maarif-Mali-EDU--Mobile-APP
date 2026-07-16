import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/lesson_service.dart';
import 'package:maarif_learn/theme/app_colors.dart';

class LessonProgressPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const LessonProgressPage(
      {super.key, required this.courseId, required this.courseTitle});

  @override
  State<LessonProgressPage> createState() => _LessonProgressPageState();
}

class _LessonProgressPageState extends State<LessonProgressPage> {
  bool _loading = true;
  String? _error;
  String? _token;
  Map<String, dynamic>? _progress;

  // État quiz
  bool _quizActive = false;
  bool _isEvaluation = false;
  bool _isBlocking = true;
  List<dynamic> _questions = [];
  int _qIndex = 0;
  final Map<int, String> _answers = {};
  bool _submitting = false;

  // Résultat
  Map<String, dynamic>? _quizResult;
  bool _showResults = false; // afficher corrections détaillées

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
      final data = await LessonService.getProgress(widget.courseId, token);
      if (mounted) setState(() { _progress = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _startPrerequisite() async {
    setState(() { _loading = true; });
    try {
      final data =
          await LessonService.startPrerequisite(widget.courseId, _token!);
      final questions = data['questions'] as List? ?? [];
      final isBlocking = data['is_blocking'] as bool? ?? true;
      if (mounted) {
        setState(() {
          _loading = false;
          _quizActive = true;
          _isEvaluation = false;
          _isBlocking = isBlocking;
          _questions = questions;
          _qIndex = 0;
          _answers.clear();
          _quizResult = null;
          _showResults = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _skipPrerequisite() async {
    // Non-bloquant : on passe directement à l'étape 2
    setState(() { _quizActive = false; _quizResult = null; });
    await _load();
  }

  Future<void> _startEvaluation() async {
    setState(() { _loading = true; });
    try {
      final data =
          await LessonService.startEvaluation(widget.courseId, _token!);
      final questions = data['questions'] as List? ?? [];
      if (mounted) {
        setState(() {
          _loading = false;
          _quizActive = true;
          _isEvaluation = true;
          _isBlocking = true;
          _questions = questions;
          _qIndex = 0;
          _answers.clear();
          _quizResult = null;
          _showResults = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _submitQuiz() async {
    setState(() { _submitting = true; });
    try {
      final answers = _answers.entries
          .map((e) => {'question_id': e.key, 'answer': e.value})
          .toList();
      Map<String, dynamic> result;
      if (_isEvaluation) {
        result = await LessonService.submitEvaluation(
            widget.courseId, answers, _token!);
      } else {
        result = await LessonService.submitPrerequisite(
            widget.courseId, answers, _token!);
      }
      if (mounted) {
        setState(() {
          _submitting = false;
          _quizActive = false;
          _quizResult = result;
        });
        await _load();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _submitting = false; _error = e.toString(); });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text(widget.courseTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _quizActive
                  ? _QuizView(
                      questions: _questions,
                      index: _qIndex,
                      answers: _answers,
                      submitting: _submitting,
                      isEvaluation: _isEvaluation,
                      isBlocking: _isBlocking,
                      onSelect: (qId, ans) =>
                          setState(() => _answers[qId] = ans),
                      onNext: () {
                        if (_qIndex < _questions.length - 1) {
                          setState(() => _qIndex++);
                        } else {
                          _submitQuiz();
                        }
                      },
                      onPrev: () {
                        if (_qIndex > 0) setState(() => _qIndex--);
                      },
                      onSkip: _isBlocking ? null : _skipPrerequisite,
                    )
                  : _showResults && _quizResult != null
                      ? _CorrectionsView(
                          result: _quizResult!,
                          onClose: () =>
                              setState(() => _showResults = false),
                        )
                      : _ProgressView(
                          progress: _progress!,
                          quizResult: _quizResult,
                          onStartPrerequisite: _startPrerequisite,
                          onStartEvaluation: _startEvaluation,
                          onShowCorrections: _quizResult != null
                              ? () => setState(() => _showResults = true)
                              : null,
                        ),
    );
  }
}

// ─── Vue progression ──────────────────────────────────────────────────────

class _ProgressView extends StatelessWidget {
  const _ProgressView({
    required this.progress,
    required this.quizResult,
    required this.onStartPrerequisite,
    required this.onStartEvaluation,
    this.onShowCorrections,
  });

  final Map<String, dynamic> progress;
  final Map<String, dynamic>? quizResult;
  final VoidCallback onStartPrerequisite;
  final VoidCallback onStartEvaluation;
  final VoidCallback? onShowCorrections;

  @override
  Widget build(BuildContext context) {
    final status = progress['status'] as String? ?? 'not_started';
    final step = progress['current_step'] as int? ?? 1;
    final hasPrereq = progress['has_prerequisite'] as bool? ?? false;
    final prereqScore = (progress['step1_score'] as num?)?.toDouble();
    final evalScore = (progress['step4_score'] as num?)?.toDouble();
    final isBlocking =
        (progress['prerequisite_test'] as Map?)?['is_blocking'] as bool? ??
            true;

    final steps = [
      _Step(1, hasPrereq ? 'Test prérequis' : 'Démarrer',
          hasPrereq ? Icons.quiz_rounded : Icons.play_circle_outline_rounded,
          done: step > 1, locked: false),
      _Step(2, 'Contenu du cours', Icons.auto_stories_rounded,
          done: step > 2,
          locked: hasPrereq && isBlocking && prereqScore == null),
      _Step(3, 'Exercices pratiques', Icons.edit_note_rounded,
          done: step > 3, locked: step < 2),
      _Step(4, 'Évaluation finale', Icons.fact_check_rounded,
          done: status == 'completed', locked: step < 3),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Résultat ARIF
          if (quizResult != null) ...[
            _ArifMessage(
              score: (quizResult!['score'] as num?)?.toDouble() ?? 0,
              message: quizResult!['arif_message'] as String? ?? '',
              blocked: quizResult!['arif_blocked'] as bool? ?? false,
            ),
            const SizedBox(height: 12),
            if (onShowCorrections != null)
              TextButton.icon(
                onPressed: onShowCorrections,
                icon: const Icon(Icons.list_alt_rounded,
                    color: AppColors.teal, size: 18),
                label: Text('Voir les corrections',
                    style: GoogleFonts.plusJakartaSans(
                        color: AppColors.teal, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 8),
          ],

          // Carte statut
          _StatusCard(status: status, step: step),
          const SizedBox(height: 20),

          // Étapes
          Text('Étapes du parcours',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy)),
          const SizedBox(height: 12),
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StepTile(step: s, currentStep: step),
              )),
          const SizedBox(height: 16),

          // Actions
          if (hasPrereq && (step == 1 || step == 0) && prereqScore == null)
            _ActionBtn(
              label: 'Démarrer le test prérequis',
              icon: Icons.quiz_rounded,
              color: AppColors.teal,
              onPressed: onStartPrerequisite,
            ),
          if (step >= 3 && status != 'completed')
            _ActionBtn(
              label: 'Passer l\'évaluation finale',
              icon: Icons.fact_check_rounded,
              color: const Color(0xFF7C3AED),
              onPressed: onStartEvaluation,
            ),

          // Scores
          if (prereqScore != null) ...[
            const SizedBox(height: 8),
            _ScoreRow(label: 'Score prérequis', score: prereqScore),
          ],
          if (evalScore != null) ...[
            const SizedBox(height: 8),
            _ScoreRow(label: 'Score évaluation', score: evalScore),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ─── Message ARIF avec avatar ─────────────────────────────────────────────

class _ArifMessage extends StatelessWidget {
  const _ArifMessage(
      {required this.score, required this.message, required this.blocked});
  final double score;
  final String message;
  final bool blocked;

  @override
  Widget build(BuildContext context) {
    Color bg, border, accent;
    if (blocked || score < 40) {
      bg = Colors.red.shade50;
      border = Colors.red.shade200;
      accent = Colors.red.shade600;
    } else if (score >= 80) {
      bg = Colors.green.shade50;
      border = Colors.green.shade200;
      accent = Colors.green.shade600;
    } else if (score >= 60) {
      bg = Colors.blue.shade50;
      border = Colors.blue.shade200;
      accent = Colors.blue.shade600;
    } else {
      bg = Colors.orange.shade50;
      border = Colors.orange.shade200;
      accent = Colors.orange.shade700;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar ARIF
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Center(
              child: Text('A',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('MAARIFA',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: accent)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${score.toStringAsFixed(0)}/100',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(message,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        height: 1.4,
                        color: accent.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Corrections détaillées ───────────────────────────────────────────────

class _CorrectionsView extends StatelessWidget {
  const _CorrectionsView({required this.result, required this.onClose});
  final Map<String, dynamic> result;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final details =
        (result['results'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final score = (result['score'] as num?)?.toDouble() ?? 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppColors.navy,
          child: Row(children: [
            IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: onClose),
            const SizedBox(width: 4),
            Text('Corrections détaillées',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${score.toStringAsFixed(0)}/100',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white)),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: details.length,
            itemBuilder: (context, i) {
              final d = details[i];
              final isCorrect = d['is_correct'] as bool? ?? false;
              final qText = d['question_text'] as String? ??
                  d['question'] as String? ?? '';
              final submitted = d['submitted_answer'] ??
                  d['submitted_option_id']?.toString() ?? '–';
              final correctAns = d['correct_answer'] ??
                  d['correct_option_text'] ?? '–';
              final explanation = d['explanation'] as String?;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isCorrect
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                      width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? Colors.green.shade600
                                  : Colors.red.shade500,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCorrect
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Q${i + 1}. $qText',
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.3,
                                  color: AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (!isCorrect) ...[
                        _CorrectionRow(
                            label: 'Votre réponse',
                            value: submitted.toString(),
                            color: Colors.red.shade600),
                      ],
                      _CorrectionRow(
                          label: 'Bonne réponse',
                          value: correctAns.toString(),
                          color: Colors.green.shade700),
                      if (explanation != null &&
                          explanation.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.lightbulb_rounded,
                                  size: 15, color: Colors.blue.shade600),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(explanation,
                                    style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: Colors.blue.shade700)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CorrectionRow extends StatelessWidget {
  const _CorrectionRow(
      {required this.label, required this.value, required this.color});
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label : ',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.textSecondary)),
          Expanded(
            child: Text(value,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ],
      ),
    );
  }
}

// ─── Quiz ─────────────────────────────────────────────────────────────────

class _QuizView extends StatelessWidget {
  const _QuizView({
    required this.questions,
    required this.index,
    required this.answers,
    required this.submitting,
    required this.isEvaluation,
    required this.isBlocking,
    required this.onSelect,
    required this.onNext,
    required this.onPrev,
    this.onSkip,
  });

  final List<dynamic> questions;
  final int index;
  final Map<int, String> answers;
  final bool submitting, isEvaluation, isBlocking;
  final void Function(int, String) onSelect;
  final VoidCallback onNext, onPrev;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Center(
          child: Text('Aucune question.',
              style: GoogleFonts.plusJakartaSans()));
    }
    final q = questions[index] as Map<String, dynamic>;
    final qId = q['id'] as int;
    final qText = q['question_text'] as String? ?? q['question'] as String? ?? '';
    final qType = q['question_type'] as String? ?? 'mcq';
    final options = _buildOptions(q, qType);
    final selected = answers[qId];
    final isLast = index == questions.length - 1;
    final accent = isEvaluation ? const Color(0xFF7C3AED) : AppColors.teal;

    return Column(
      children: [
        // Barre de progression
        LinearProgressIndicator(
          value: (index + 1) / questions.length,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(accent),
          minHeight: 4,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${index + 1} / ${questions.length}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                      isEvaluation
                          ? 'Évaluation finale'
                          : 'Test prérequis',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                  const Spacer(),
                  if (!isBlocking && onSkip != null && !isEvaluation)
                    TextButton(
                      onPressed: onSkip,
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary),
                      child: Text('Passer →',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ]),
                const SizedBox(height: 16),
                Text(qText,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 20),
                ...options.map((opt) {
                  final isSel = selected == opt['value'];
                  return GestureDetector(
                    onTap: () => onSelect(qId, opt['value']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSel
                            ? accent.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSel ? accent : Colors.grey.shade200,
                            width: isSel ? 2 : 1),
                        boxShadow: isSel
                            ? [
                                BoxShadow(
                                    color: accent.withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]
                            : [],
                      ),
                      child: Row(children: [
                        Icon(
                          isSel
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                          color: isSel ? accent : Colors.grey.shade400,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(opt['label']!,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: isSel
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSel
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary)),
                        ),
                      ]),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(children: [
              if (index > 0) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrev,
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text('Préc.',
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: selected == null || submitting ? null : onNext,
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(
                          isLast
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: 18),
                  label: Text(
                      isLast ? 'Terminer' : 'Suivant',
                      style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  List<Map<String, String>> _buildOptions(
      Map<String, dynamic> q, String qType) {
    if (qType == 'true_false') {
      return [
        {'value': 'true', 'label': '✓  Vrai'},
        {'value': 'false', 'label': '✗  Faux'},
      ];
    }
    final raw = q['options'];
    if (raw is List) {
      return raw.map((o) {
        if (o is Map) {
          final label = o['text'] as String? ?? o['label'] as String? ?? o.toString();
          final value = o['label'] as String? ?? label;
          return {'value': value, 'label': label};
        }
        return {'value': o.toString(), 'label': o.toString()};
      }).toList();
    }
    return [];
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────

class _Step {
  const _Step(this.number, this.label, this.icon,
      {required this.done, required this.locked});
  final int number;
  final String label;
  final IconData icon;
  final bool done, locked;
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.step, required this.currentStep});
  final _Step step;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final isActive = step.number == currentStep && !step.done;
    final color = step.locked
        ? Colors.grey.shade300
        : step.done
            ? Colors.green.shade600
            : isActive
                ? AppColors.teal
                : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: step.locked
            ? Colors.grey.shade50
            : isActive
                ? AppColors.teal.withValues(alpha: 0.05)
                : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isActive
                ? AppColors.teal.withValues(alpha: 0.4)
                : Colors.grey.shade100,
            width: isActive ? 1.5 : 1),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ]
            : [],
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(
            step.done
                ? Icons.check_circle_rounded
                : step.locked
                    ? Icons.lock_rounded
                    : step.icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(step.label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w500,
                  color: step.locked
                      ? Colors.grey.shade400
                      : AppColors.textPrimary)),
        ),
        if (isActive)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text('En cours',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.teal)),
          ),
        if (step.done)
          const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 20),
      ]),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.step});
  final String status;
  final int step;

  @override
  Widget build(BuildContext context) {
    final labels = {
      'not_started': 'Non commencé',
      'in_progress': 'En cours',
      'completed': 'Terminé ✓',
      'failed': 'Échoué',
      'locked': 'Verrouillé',
    };
    final isCompleted = status == 'completed';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.navy, AppColors.navyLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Statut du parcours',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.65))),
                const SizedBox(height: 4),
                Text(labels[status] ?? status,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ]),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
              color: (isCompleted ? Colors.green : AppColors.teal)
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20)),
          child: Text('Étape $step / 4',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isCompleted ? Colors.greenAccent : AppColors.tealLight)),
        ),
      ]),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.label, required this.score});
  final String label;
  final double score;

  @override
  Widget build(BuildContext context) {
    final pass = score >= 50;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: pass ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: pass ? Colors.green.shade200 : Colors.red.shade200),
      ),
      child: Row(children: [
        Icon(
          pass ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: pass ? Colors.green.shade700 : Colors.red.shade600,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: pass
                      ? Colors.green.shade700
                      : Colors.red.shade600)),
        ),
        Text('${score.toStringAsFixed(0)} / 100',
            style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: pass ? Colors.green.shade700 : Colors.red.shade600)),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onPressed});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 15)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
        ),
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
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 52),
          const SizedBox(height: 14),
          Text(error,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 18),
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
