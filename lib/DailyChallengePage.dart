import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/services/arif_service.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/theme/app_colors.dart';

const _kOrange = Color(0xFFF97316);
const _kOrangeDark = Color(0xFFC2410C);

/// Défi du jour ⚡ : 5 QCM générés par MAARIFA depuis un cours de la classe.
/// XP doublés, une seule tentative par jour.
class DailyChallengePage extends StatefulWidget {
  const DailyChallengePage({super.key});

  @override
  State<DailyChallengePage> createState() => _DailyChallengePageState();
}

class _DailyChallengePageState extends State<DailyChallengePage> {
  bool _loading = true;
  bool _alreadyDone = false;
  String? _error;
  String? _courseTitle;
  String? _subjectName;
  List<Map<String, dynamic>> _questions = [];

  int _current = 0;
  int _correct = 0;
  String? _selected; // lettre choisie pour la question courante
  bool _answered = false;
  bool _finished = false;
  int _xpEarned = 0;
  String _resultMessage = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    try {
      final res = await ArifService.getDailyChallenge(token);
      if (!mounted) return;
      if (res['done'] == true) {
        setState(() { _alreadyDone = true; _loading = false; });
        return;
      }
      final data = Map<String, dynamic>.from(res['data'] as Map);
      setState(() {
        _courseTitle = (data['course'] as Map?)?['title']?.toString();
        _subjectName = (data['course'] as Map?)?['subject']?.toString();
        _questions = ((data['questions'] as List?) ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
        if (_questions.isEmpty) _error = 'Pas de défi disponible aujourd\'hui.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _answer(String letter) {
    if (_answered) return;
    final correctLetter = _questions[_current]['correct']?.toString().substring(0, 1).toUpperCase();
    final good = letter == correctLetter;
    if (good) {
      _correct++;
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() { _selected = letter; _answered = true; });
  }

  Future<void> _next() async {
    if (_current < _questions.length - 1) {
      setState(() { _current++; _selected = null; _answered = false; });
      return;
    }
    // Fin du défi → valider le score
    setState(() => _finished = true);
    HapticFeedback.mediumImpact();
    try {
      final token = await AuthStorage.getToken();
      if (token != null) {
        final res = await ArifService.completeDailyChallenge(_correct, token);
        if (mounted) {
          setState(() {
            _xpEarned = (res['xp_earned'] as num?)?.toInt() ?? 0;
            _resultMessage = res['message']?.toString() ?? '';
          });
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: _kOrangeDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, _finished),
        ),
        title: Text('⚡ Défi du jour',
            style: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kOrange, strokeWidth: 3))
          : _alreadyDone
              ? _centered('🔥', 'Défi déjà relevé !',
                  'Tu as déjà fait ton défi aujourd\'hui.\nReviens demain pour continuer ta série.')
              : _error != null
                  ? _centered('😴', 'Pas de défi aujourd\'hui', _error!)
                  : _finished
                      ? _buildResult()
                      : _buildQuestion(),
    );
  }

  Widget _centered(String emoji, String title, String sub) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            Text(title,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text(sub,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          ]),
        ),
      );

  Widget _buildQuestion() {
    final q = _questions[_current];
    final options = ((q['options'] as List?) ?? []).map((e) => e.toString()).toList();
    final correctLetter = q['correct']?.toString().substring(0, 1).toUpperCase();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Progression
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (_current + (_answered ? 1 : 0)) / _questions.length,
                minHeight: 8,
                backgroundColor: _kOrange.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation(_kOrange),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${_current + 1}/${_questions.length}',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _kOrangeDark)),
        ]),
        const SizedBox(height: 8),
        if (_courseTitle != null)
          Text('${_subjectName ?? ''} · $_courseTitle',
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: AppColors.textSecondary)),
        const SizedBox(height: 18),

        // Question
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kOrangeDark, _kOrange]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(q['question']?.toString() ?? '',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.45)),
        ),
        const SizedBox(height: 18),

        // Options (lettre par position — robuste quel que soit le format IA)
        ...options.asMap().entries.map((entry) {
          final opt = entry.value;
          final letter = String.fromCharCode(65 + entry.key);
          final isSelected = _selected == letter;
          final isCorrect = letter == correctLetter;

          Color bg = Colors.white;
          Color border = Colors.grey.shade200;
          if (_answered && isCorrect) { bg = const Color(0xFFECFDF5); border = const Color(0xFF10B981); }
          else if (_answered && isSelected && !isCorrect) { bg = const Color(0xFFFEF2F2); border = const Color(0xFFEF4444); }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _answer(letter),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 1.5),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Text(opt.replaceFirst(RegExp(r'^[A-Fa-f][\)\.\:\-]\s*'), ''),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13.5, fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A1A2E), height: 1.4)),
                    ),
                    if (_answered && isCorrect)
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    if (_answered && isSelected && !isCorrect)
                      const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 20),
                  ]),
                ),
              ),
            ),
          );
        }),

        // Explication + suivant
        if (_answered) ...[
          if ((q['explanation']?.toString() ?? '').isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6D28D9).withValues(alpha: 0.2)),
              ),
              child: Text('✦ ${q['explanation']}',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5, color: const Color(0xFF4C1D95), height: 1.5)),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kOrange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _next,
              child: Text(
                  _current < _questions.length - 1 ? 'Question suivante →' : 'Voir mon résultat 🏆',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildResult() {
    final pct = _questions.isEmpty ? 0 : (_correct / _questions.length * 100).round();
    final (emoji, title) = switch (_correct) {
      5 => ('🏆', 'Parfait !'),
      4 => ('🔥', 'Excellent !'),
      3 => ('💪', 'Bien joué !'),
      _ => ('📚', 'Continue à réviser !'),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 14),
          Text(title,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.navy)),
          const SizedBox(height: 8),
          Text('$_correct / ${_questions.length} bonnes réponses ($pct%)',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_kOrangeDark, _kOrange]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(
                  color: _kOrange.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: Column(children: [
              Text('+$_xpEarned XP',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('XP doublés du défi ⚡',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70)),
            ]),
          ),
          if (_resultMessage.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(_resultMessage,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text('Retour à l\'accueil',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}
