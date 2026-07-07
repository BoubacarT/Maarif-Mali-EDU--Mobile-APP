import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/goal_service.dart';
import 'package:maarif_learn/theme/app_colors.dart';

const _pink = Color(0xFFEC4899);
const _pinkLight = Color(0xFFFDF2F8);

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  bool _loading = true;
  String? _error;
  String? _token;
  List<dynamic> _goals = [];

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
      final goals = await GoalService.getGoals(token);
      if (mounted) setState(() { _goals = goals; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _deleteGoal(int id) async {
    try {
      await GoalService.deleteGoal(id, _token!);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _showAddGoal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddGoalSheet(token: _token!, onAdded: _load),
    );
  }

  void _showOrientationTest() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => _OrientationTestPage(token: _token!),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Mes objectifs',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.compass_calibration_rounded),
            tooltip: 'Test d\'orientation',
            onPressed: _showOrientationTest,
          ),
        ],
      ),
      floatingActionButton: _token == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              onPressed: _showAddGoal,
              icon: const Icon(Icons.add_rounded),
              label: Text('Ajouter', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  color: _pink,
                  onRefresh: _load,
                  child: _goals.isEmpty
                      ? _EmptyState(onAdd: _showAddGoal, onTest: _showOrientationTest)
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _goals.length,
                          itemBuilder: (context, i) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _GoalTile(
                                goal: _goals[i] as Map<String, dynamic>,
                                rank: i + 1,
                                onDelete: () => _deleteGoal(_goals[i]['id'] as int),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, required this.rank, required this.onDelete});
  final Map<String, dynamic> goal;
  final int rank;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final program = goal['program_name'] as String? ?? '';
    final institution = (goal['institution'] as Map<String, dynamic>?)?['name'] as String? ?? '';
    final requiredScore = (goal['required_score'] as num?)?.toDouble();
    final currentScore = (goal['current_score'] as num?)?.toDouble() ?? 0;
    final date = goal['target_date'] as String? ?? '';
    final progress = requiredScore != null && requiredScore > 0
        ? (currentScore / requiredScore).clamp(0.0, 1.0)
        : 0.0;
    final reached = requiredScore != null && currentScore >= requiredScore;
    final rankLabels = ['1er choix', '2e choix', '3e choix', '${rank}e choix'];
    final rankLabel = rank <= 3 ? rankLabels[rank - 1] : rankLabels[3];
    final barColor = reached
        ? Colors.green.shade600
        : (progress >= 0.7 ? Colors.orange.shade600 : Colors.red.shade500);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: reached ? Colors.green.shade200 : Colors.grey.shade100),
        boxShadow: [BoxShadow(color: AppColors.navy.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Badge rang
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: _pink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(rankLabel,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w800, color: _pink)),
              ),
              const SizedBox(width: 8),
              if (reached)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('Objectif atteint ✓',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
                ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('Supprimer ?', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    content: Text('Cet objectif sera supprimé.', style: GoogleFonts.plusJakartaSans()),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                      ElevatedButton(
                        onPressed: () { Navigator.pop(context); onDelete(); },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text(program,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            if (institution.isNotEmpty)
              Text(institution,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            // Barre score actuel vs requis
            if (requiredScore != null) ...[
              Row(children: [
                Text('Score actuel',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppColors.textSecondary)),
                const Spacer(),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                          text: currentScore.toStringAsFixed(0),
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w900, color: barColor)),
                      TextSpan(
                          text: ' / ${requiredScore.toStringAsFixed(0)}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
              if (!reached)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      'Encore ${(requiredScore - currentScore).toStringAsFixed(0)} points à gagner',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 11, color: AppColors.textSecondary)),
                ),
            ],
            if (date.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.event_rounded, size: 13, color: _pink),
                  const SizedBox(width: 4),
                  Text('Date cible : $date',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: AppColors.textSecondary)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.onTest});
  final VoidCallback onAdd;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('Définissez vos objectifs',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text('Choisissez votre établissement cible et votre filière.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text('Ajouter un objectif',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _pink, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onTest,
              icon: const Icon(Icons.compass_calibration_rounded, color: _pink),
              label: Text('Faire le test d\'orientation',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: _pink)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _pink),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddGoalSheet extends StatefulWidget {
  const _AddGoalSheet({required this.token, required this.onAdded});
  final String token;
  final VoidCallback onAdded;

  @override
  State<_AddGoalSheet> createState() => _AddGoalSheetState();
}

class _AddGoalSheetState extends State<_AddGoalSheet> {
  final _programCtrl = TextEditingController();
  final _scoreCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<dynamic> _institutions = [];
  Map<String, dynamic>? _selectedInstitution;
  DateTime? _targetDate;
  bool _saving = false;
  String? _error;
  bool _searching = false;

  @override
  void dispose() {
    _programCtrl.dispose();
    _scoreCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) return;
    setState(() { _searching = true; });
    try {
      final list = await GoalService.searchInstitutions(query, widget.token);
      if (mounted) setState(() { _institutions = list; _searching = false; });
    } catch (_) {
      if (mounted) setState(() { _searching = false; });
    }
  }

  Future<void> _save() async {
    if (_programCtrl.text.isEmpty) {
      setState(() => _error = 'Indiquez la filière.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final data = <String, dynamic>{
        'program_name': _programCtrl.text.trim(),
        if (_selectedInstitution != null) 'target_institution_id': _selectedInstitution!['id'],
        if (_scoreCtrl.text.isNotEmpty) 'required_score': double.tryParse(_scoreCtrl.text),
        if (_targetDate != null)
          'target_date': '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2,'0')}-${_targetDate!.day.toString().padLeft(2,'0')}',
      };
      await GoalService.createGoal(data, widget.token);
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            ),
            const SizedBox(height: 16),
            Text('Nouvel objectif',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 16),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: GoogleFonts.plusJakartaSans(color: Colors.red.shade700, fontSize: 13)),
              ),
            TextField(
              controller: _searchCtrl,
              onChanged: _search,
              decoration: InputDecoration(
                labelText: 'Rechercher un établissement',
                prefixIcon: _searching
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                    : const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _pink, width: 2)),
                filled: true, fillColor: Colors.white,
              ),
            ),
            if (_institutions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  children: _institutions.take(5).map((inst) {
                    final m = inst as Map<String, dynamic>;
                    final sel = _selectedInstitution?['id'] == m['id'];
                    return ListTile(
                      dense: true,
                      selected: sel,
                      selectedTileColor: _pinkLight,
                      title: Text(m['name'] as String? ?? '',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(m['city'] as String? ?? '',
                          style: GoogleFonts.plusJakartaSans(fontSize: 11)),
                      trailing: sel ? const Icon(Icons.check_circle_rounded, color: _pink, size: 18) : null,
                      onTap: () => setState(() {
                        _selectedInstitution = m;
                        _institutions = [];
                        _searchCtrl.text = m['name'] as String? ?? '';
                      }),
                    );
                  }).toList(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _programCtrl,
              decoration: InputDecoration(
                labelText: 'Filière / programme *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _pink, width: 2)),
                filled: true, fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _scoreCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Score requis (0-100, optionnel)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _pink, width: 2)),
                filled: true, fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _targetDate == null
                        ? 'Date cible (optionnel)'
                        : 'Date cible : ${_targetDate!.day}/${_targetDate!.month}/${_targetDate!.year}',
                    style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 180)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 1825)),
                      builder: (_, child) => Theme(
                        data: ThemeData(colorScheme: const ColorScheme.light(primary: _pink)),
                        child: child!,
                      ),
                    );
                    if (picked != null) setState(() => _targetDate = picked);
                  },
                  icon: const Icon(Icons.event_rounded, color: _pink),
                  label: Text('Choisir', style: GoogleFonts.plusJakartaSans(color: _pink, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _pink, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Enregistrer',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrientationTestPage extends StatefulWidget {
  const _OrientationTestPage({required this.token});
  final String token;

  @override
  State<_OrientationTestPage> createState() => _OrientationTestPageState();
}

class _OrientationTestPageState extends State<_OrientationTestPage> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _test;
  int _index = 0;
  final Map<String, int> _answers = {};
  bool _submitting = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final t = await GoalService.getOrientationTest(widget.token);
      if (mounted) setState(() { _test = t; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; });
    try {
      final res = await GoalService.submitOrientation(_test!['id'] as int, _answers, widget.token);
      if (mounted) setState(() { _result = res; _submitting = false; });
    } catch (e) {
      if (mounted) setState(() { _submitting = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Text('Test d\'orientation',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : _result != null
                  ? _ResultView(result: _result!)
                  : _TestView(
                      test: _test!,
                      index: _index,
                      answers: _answers,
                      submitting: _submitting,
                      onAnswer: (qId, score) => setState(() => _answers[qId] = score),
                      onNext: () {
                        final questions = (_test!['questions'] as List?) ?? [];
                        if (_index < questions.length - 1) {
                          setState(() => _index++);
                        } else {
                          _submit();
                        }
                      },
                      onPrev: () { if (_index > 0) setState(() => _index--); },
                    ),
    );
  }
}

class _TestView extends StatelessWidget {
  const _TestView({
    required this.test,
    required this.index,
    required this.answers,
    required this.submitting,
    required this.onAnswer,
    required this.onNext,
    required this.onPrev,
  });
  final Map<String, dynamic> test;
  final int index;
  final Map<String, int> answers;
  final bool submitting;
  final void Function(String, int) onAnswer;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  @override
  Widget build(BuildContext context) {
    final questions = (test['questions'] as List?) ?? [];
    if (questions.isEmpty) return Center(child: Text('Aucune question.', style: GoogleFonts.plusJakartaSans()));
    final q = questions[index] as Map<String, dynamic>;
    final qId = q['id']?.toString() ?? index.toString();
    final qText = q['text'] as String? ?? '';
    final options = (q['options'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final selected = answers[qId];
    final isLast = index == questions.length - 1;

    return Column(
      children: [
        LinearProgressIndicator(
          value: (index + 1) / questions.length,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(_pink),
          minHeight: 4,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _pinkLight, borderRadius: BorderRadius.circular(20)),
                  child: Text('${index + 1} / ${questions.length}',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, fontWeight: FontWeight.w700, color: _pink)),
                ),
                const SizedBox(height: 16),
                Text(qText,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.4)),
                const SizedBox(height: 20),
                ...options.map((opt) {
                  final score = opt['score'] as int? ?? 0;
                  final label = opt['text'] as String? ?? '';
                  final isSel = selected == score;
                  return GestureDetector(
                    onTap: () => onAnswer(qId, score),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSel ? _pinkLight : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: isSel ? _pink : Colors.grey.shade200, width: isSel ? 2 : 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isSel ? _pink : Colors.grey.shade400, size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(label,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500))),
                        ],
                      ),
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
            child: Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPrev,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text('Précédent', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                if (index > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: selected == null || submitting ? null : onNext,
                    icon: submitting
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(isLast ? Icons.check_rounded : Icons.arrow_forward_rounded),
                    label: Text(isLast ? 'Voir mon profil' : 'Suivant',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _pink, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        disabledBackgroundColor: Colors.grey.shade200),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final profile = result['top_profile'] as Map<String, dynamic>? ?? {};
    final name = profile['name'] as String? ?? '';
    final description = profile['description'] as String? ?? '';
    final score = (result['score'] as num?)?.toDouble() ?? 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: _pinkLight, shape: BoxShape.circle),
              child: const Icon(Icons.compass_calibration_rounded, color: _pink, size: 48),
            ),
            const SizedBox(height: 20),
            Text('Votre profil',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: AppColors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 8),
            Text(name,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 12),
            Text(description,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 15, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: _pinkLight, borderRadius: BorderRadius.circular(20)),
              child: Text('Score : ${score.toStringAsFixed(0)} points',
                  style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700, color: _pink)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _pink, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Retour à mes objectifs',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
            ),
          ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(backgroundColor: _pink, foregroundColor: Colors.white),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
