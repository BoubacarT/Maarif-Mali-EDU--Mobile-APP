import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/services/arif_service.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/theme/app_colors.dart';

// Palette MAARIFA
const _kViolet     = Color(0xFF6D28D9);
const _kVioletDark = Color(0xFF4C1D95);
const _kVioletLight= Color(0xFFF5F3FF);
const _kGold       = Color(0xFFF59E0B);

class ArifPage extends StatefulWidget {
  const ArifPage({super.key});
  @override
  State<ArifPage> createState() => _ArifPageState();
}

class _ArifPageState extends State<ArifPage> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _token;
  bool _loadingRec = true;
  List<dynamic> _recommendations = [];
  Map<String, dynamic>? _aiStats;
  Map<String, dynamic>? _gamification;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    setState(() { _token = token; });
    // Générer les alertes intelligentes à chaque ouverture
    ArifService.generateAlerts(token);
    await Future.wait([_loadRecommendations(), _loadStats(), _loadGamification()]);
  }

  Future<void> _loadRecommendations() async {
    if (_token == null) return;
    setState(() => _loadingRec = true);
    try {
      final recs = await ArifService.getRecommendations(_token!);
      if (mounted) setState(() { _recommendations = recs; _loadingRec = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingRec = false);
    }
  }

  Future<void> _loadStats() async {
    if (_token == null) return;
    try {
      final stats = await ArifService.getStats(_token!);
      if (mounted) setState(() => _aiStats = stats);
    } catch (_) {}
  }

  Future<void> _loadGamification() async {
    if (_token == null) return;
    try {
      final g = await ArifService.getGamification(_token!);
      if (mounted) setState(() => _gamification = g);
    } catch (_) {}
  }

  Future<void> _markRead(int id) async {
    await ArifService.markRead(id, _token!);
    await _loadRecommendations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Column(children: [
        _MaarifaHeader(
          stats: _aiStats,
          gamification: _gamification,
          tabs: _tabs,
          recCount: _recommendations.length,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _token == null
                  ? const Center(child: CircularProgressIndicator(color: _kViolet))
                  : _ChatTab(token: _token!, onStatsRefresh: _loadStats),
              _loadingRec
                  ? const Center(child: CircularProgressIndicator(color: _kViolet))
                  : _RecommendationsTab(
                      recommendations: _recommendations,
                      onMarkRead: _markRead,
                      onRefresh: _loadRecommendations,
                    ),
              _GamificationTab(gamification: _gamification, token: _token, onRefresh: _loadGamification),
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
class _MaarifaHeader extends StatelessWidget {
  const _MaarifaHeader({required this.stats, required this.gamification, required this.tabs, required this.recCount});
  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? gamification;
  final TabController tabs;
  final int recCount;

  @override
  Widget build(BuildContext context) {
    final remaining = stats?['messages_remaining'] as int? ?? 30;
    final limit     = stats?['messages_limit'] as int? ?? 30;
    final used      = stats?['messages_today'] as int? ?? 0;
    final xp        = gamification?['xp_points'] as int? ?? 0;
    final level     = gamification?['level'] as int? ?? 1;
    final levelName = gamification?['level_name'] as String? ?? 'Débutant';
    final xpNext    = gamification?['xp_next_level'] as int? ?? 100;
    final xpProgress = xpNext > 0 ? (xp / xpNext).clamp(0.0, 1.0) : 0.0;
    final msgProgress = limit > 0 ? used / limit : 0.0;
    final streak    = gamification?['streak_days'] as int? ?? 0;

    return Container(
      color: const Color(0xFF1A0A3C),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(children: [
              // ── Ligne 1 : logo + titre + badges ────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kGold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('✨', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('MAARIFA',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 18, fontWeight: FontWeight.w900,
                            color: Colors.white, letterSpacing: 1)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: _kGold, borderRadius: BorderRadius.circular(5)),
                      child: Text('AI',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                    ),
                  ]),
                  Text('Intelligence Pédagogique · Maarif Turkiye',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 9, color: Colors.white38)),
                ]),
                const Spacer(),
                // Badge XP + streak
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _kGold.withValues(alpha: 0.4)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('⭐', style: TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                      Text('Niv.$level · $xp XP',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, fontWeight: FontWeight.w800, color: _kGold)),
                      if (streak > 0) ...[
                        const SizedBox(width: 6),
                        Text('🔥$streak',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: Colors.orange.shade300)),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 4),
                  // Compteur messages restants
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$remaining msg restants',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9, fontWeight: FontWeight.w600,
                        color: remaining <= 5 ? Colors.redAccent : Colors.white54,
                      ),
                    ),
                  ),
                ]),
              ]),

              const SizedBox(height: 10),

              // ── Ligne 2 : XP bar + messages bar ────────────────
              Row(children: [
                // XP progress
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(levelName,
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 8, color: Colors.white38, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: xpProgress,
                        minHeight: 3,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 10),
                // Messages used
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$used / $limit messages',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 8, color: Colors.white38, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: msgProgress,
                        minHeight: 3,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            msgProgress > 0.8 ? Colors.redAccent : Colors.white38),
                      ),
                    ),
                  ]),
                ),
              ]),

              const SizedBox(height: 12),
            ]),
          ),
          // ── Onglets ─────────────────────────────────────────
          TabBar(
            controller: tabs,
            labelColor: _kGold,
            unselectedLabelColor: Colors.white38,
            indicatorColor: _kGold,
            indicatorWeight: 2.5,
            dividerColor: Colors.transparent,
            labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 12),
            tabs: [
              const Tab(text: 'Chat IA'),
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Alertes'),
                  if (recCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: _kGold, borderRadius: BorderRadius.circular(10)),
                      child: Text('$recCount',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ],
                ]),
              ),
              const Tab(text: '🏆 XP'),
            ],
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// CHAT TAB
// ════════════════════════════════════════════════════════════
class _ChatTab extends StatefulWidget {
  const _ChatTab({required this.token, required this.onStatsRefresh});
  final String token;
  final VoidCallback onStatsRefresh;
  @override
  State<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<_ChatTab> {
  final _ctrl         = TextEditingController();
  final _scrollCtrl   = ScrollController();
  final _focusNode    = FocusNode();
  final List<_Msg>    _messages = [];
  int?  _conversationId;
  bool  _sending      = false;
  bool  _initializing = true;

  static const _suggestions = [
    ('📚', 'Résumer un cours'),
    ('📊', 'Mon niveau actuel'),
    ('🎯', 'Préparer le BAC'),
    ('⚠️', 'Mes matières faibles'),
    ('📅', 'Mon plan de révision'),
    ('✅', 'Conseil du jour'),
  ];

  @override
  void initState() {
    super.initState();
    _initConversation();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _initConversation() async {
    try {
      final conv = await ArifService.createConversation('general', widget.token);
      final data = conv['data'] as Map<String, dynamic>? ?? conv;
      final convId = data['id'] as int?;

      final history = (data['messages'] as List<dynamic>?) ?? [];
      final historicMsgs = history.map((m) {
        final role    = m['role']    as String? ?? 'user';
        final content = m['content'] as String? ?? '';
        return _Msg(text: content, isAi: role == 'assistant');
      }).toList();

      if (mounted) {
        setState(() {
          _conversationId = convId;
          _initializing   = false;
          if (historicMsgs.isEmpty) {
            _messages.add(const _Msg(
              text: 'Bonjour ! Je suis **MAARIFA**, ton assistante pédagogique. Je connais ton niveau, tes cours et tes résultats.\n\nPose-moi n\'importe quelle question ! 🌟',
              isAi: true,
            ));
          } else {
            _messages.addAll(historicMsgs);
          }
        });
        if (historicMsgs.isNotEmpty) _scrollDown();
      }
    } catch (_) {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _ctrl.text.trim();
    if (text.isEmpty || _conversationId == null || _sending) return;
    _ctrl.clear();
    _focusNode.unfocus();

    setState(() {
      _messages.add(_Msg(text: text, isAi: false));
      _sending = true;
    });
    _scrollDown();

    try {
      final res   = await ArifService.sendMessage(_conversationId!, text, widget.token);
      final reply = res['reply'] as String? ?? '…';
      if (mounted) {
        setState(() {
          _messages.add(_Msg(text: reply, isAi: true));
          _sending = false;
        });
        _scrollDown();
        widget.onStatsRefresh();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages.add(const _Msg(
              text: 'Erreur de connexion. Vérifie ta connexion internet.',
              isAi: true, isError: true));
          _sending = false;
        });
        _scrollDown();
      }
    }
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Center(child: _TypingDots());
    }

    return Column(children: [
      // ── Zone messages ──────────────────────────────────────
      Expanded(
        child: Container(
          color: const Color(0xFFF0EEFF),
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (_, i) {
              if (_sending && i == _messages.length) {
                return const _TypingBubble();
              }
              return _BubbleTile(msg: _messages[i]);
            },
          ),
        ),
      ),

      // ── Suggestions (toujours visibles) ───────────────────
      if (!_sending)
        Container(
          color: const Color(0xFFF0EEFF),
          height: 42,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
            scrollDirection: Axis.horizontal,
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final (emoji, label) = _suggestions[i];
              return GestureDetector(
                onTap: () => _send(label),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kViolet.withValues(alpha: 0.2)),
                    boxShadow: [BoxShadow(
                      color: _kViolet.withValues(alpha: 0.06),
                      blurRadius: 6, offset: const Offset(0, 2),
                    )],
                  ),
                  child: Text('$emoji $label',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w600, color: _kViolet)),
                ),
              );
            },
          ),
        ),

      // ── Barre d'entrée ────────────────────────────────────
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _kViolet.withValues(alpha: 0.08), width: 1)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 110),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  maxLines: null,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: const Color(0xFF1A1A2E)),
                  decoration: InputDecoration(
                    hintText: 'Pose ta question…',
                    hintStyle: GoogleFonts.plusJakartaSans(
                        color: const Color(0xFFC4B5FD), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF8F7FF),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: _kViolet.withValues(alpha: 0.15)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: _kViolet.withValues(alpha: 0.15)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: _kViolet, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _sending ? Colors.grey.shade300 : _kViolet,
                  shape: BoxShape.circle,
                  boxShadow: _sending ? [] : [
                    BoxShadow(color: _kViolet.withValues(alpha: 0.35),
                        blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: _sending ? Colors.grey.shade500 : Colors.white,
                  size: 18,
                ),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════
// MODÈLE MESSAGE
// ════════════════════════════════════════════════════════════
class _Msg {
  const _Msg({required this.text, required this.isAi, this.isError = false});
  final String text;
  final bool isAi, isError;
}

// ════════════════════════════════════════════════════════════
// BULLE DE CHAT — style iMessage/WhatsApp
// ════════════════════════════════════════════════════════════
class _BubbleTile extends StatelessWidget {
  const _BubbleTile({required this.msg});
  final _Msg msg;

  List<TextSpan> _parseText(String text, Color base) {
    final spans = <TextSpan>[];
    final reg   = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in reg.allMatches(text)) {
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(
          text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w800)));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isAi = msg.isAi;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          // Avatar MAARIFA
          if (isAi) ...[
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(
                color: _kViolet,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('✦', style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Bulle
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAi
                    ? (msg.isError ? Colors.red.shade50 : Colors.white)
                    : _kViolet,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(18),
                  topRight:    const Radius.circular(18),
                  bottomLeft:  Radius.circular(isAi ? 4 : 18),
                  bottomRight: Radius.circular(isAi ? 18 : 4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isAi ? Colors.black : _kViolet).withValues(alpha: 0.07),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        height: 1.5,
                        color: isAi
                            ? (msg.isError ? Colors.red.shade700 : const Color(0xFF1A1A2E))
                            : Colors.white,
                      ),
                      children: _parseText(msg.text, Colors.white),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Heure + double check
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      _timeNow(),
                      style: TextStyle(
                        fontSize: 9,
                        color: isAi
                            ? Colors.grey.shade400
                            : Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    if (!isAi) ...[
                      const SizedBox(width: 3),
                      Icon(Icons.done_all_rounded,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.6)),
                    ],
                  ]),
                ],
              ),
            ),
          ),

          if (!isAi) const SizedBox(width: 6),
        ],
      ),
    );
  }

  String _timeNow() {
    final now = DateTime.now();
    final h   = now.hour.toString().padLeft(2, '0');
    final m   = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ════════════════════════════════════════════════════════════
// ANIMATION FRAPPE (3 points)
// ════════════════════════════════════════════════════════════
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (int i = 0; i < 3; i++) ...[
        AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final phase = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
            final bounce = phase < 0.5
                ? phase * 2
                : (1 - phase) * 2;
            return Transform.translate(
              offset: Offset(0, -4 * bounce),
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: _kViolet.withValues(alpha: 0.4 + 0.6 * bounce),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        ),
        if (i < 2) const SizedBox(width: 4),
      ],
    ]);
  }
}

// Bulle MAARIFA avec animation de frappe
class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(color: _kViolet, shape: BoxShape.circle),
            child: const Center(
              child: Text('✦', style: TextStyle(color: Colors.white, fontSize: 13)),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18), topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4), bottomRight: Radius.circular(18),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: const _TypingDots(),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// ONGLET NOTIFICATIONS
// ════════════════════════════════════════════════════════════
class _RecommendationsTab extends StatelessWidget {
  const _RecommendationsTab({
    required this.recommendations,
    required this.onMarkRead,
    required this.onRefresh,
  });
  final List<dynamic>             recommendations;
  final Future<void> Function(int) onMarkRead;
  final Future<void> Function()   onRefresh;

  @override
  Widget build(BuildContext context) {
    if (recommendations.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _kVioletLight,
              shape: BoxShape.circle,
              border: Border.all(color: _kViolet.withValues(alpha: 0.2)),
            ),
            child: const Icon(Icons.notifications_none_rounded, size: 44, color: _kViolet),
          ),
          const SizedBox(height: 16),
          Text('Aucune notification pour l\'instant',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.navy)),
          const SizedBox(height: 6),
          Text('MAARIFA t\'alertera dès qu\'elle\nidentifie quelque chose d\'important.',
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center),
        ]),
      );
    }

    return RefreshIndicator(
      color: _kViolet,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        itemCount: recommendations.length,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemBuilder: (_, i) {
          final rec = recommendations[i] as Map<String, dynamic>;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _RecCard(rec: rec, onMarkRead: () => onMarkRead(rec['id'] as int)),
          );
        },
      ),
    );
  }
}

class _RecCard extends StatelessWidget {
  const _RecCard({required this.rec, required this.onMarkRead});
  final Map<String, dynamic> rec;
  final VoidCallback onMarkRead;

  @override
  Widget build(BuildContext context) {
    final type    = rec['type'] as String? ?? '';
    final message = rec['message'] as String? ?? '';
    final isRead  = rec['is_read'] as bool? ?? false;

    final (icon, color, bg, label) = switch (type) {
      'study_reminder' => (Icons.schedule_rounded,      AppColors.teal,          const Color(0xFFECFDF5), 'Rappel'),
      'weak_topic'     => (Icons.trending_down_rounded, const Color(0xFFF59E0B), const Color(0xFFFFFBEB), 'Point faible'),
      'goal_progress'  => (Icons.flag_rounded,           const Color(0xFFEC4899), const Color(0xFFFDF2F8), 'Objectif'),
      'streak'         => (Icons.local_fire_department_rounded, Colors.deepOrange, const Color(0xFFFFF7ED), 'Streak'),
      _                => (Icons.auto_awesome_rounded,   _kViolet,                _kVioletLight,           'MAARIFA'),
    };

    return Container(
      decoration: BoxDecoration(
        color: isRead ? Colors.white : bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isRead ? Colors.grey.shade100 : color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: isRead ? 0.04 : 0.1),
              blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(label,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                ),
                if (!isRead) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                ],
              ]),
              const SizedBox(height: 8),
              Text(message,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, height: 1.4,
                      fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                      color: AppColors.textPrimary)),
              if (!isRead) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onMarkRead,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: color.withValues(alpha: 0.8)),
                    const SizedBox(width: 4),
                    Text('Marquer comme lu',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: color.withValues(alpha: 0.8))),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}


// ════════════════════════════════════════════════════════════
// ONGLET GAMIFICATION
// ════════════════════════════════════════════════════════════
class _GamificationTab extends StatefulWidget {
  const _GamificationTab({required this.gamification, required this.token, required this.onRefresh});
  final Map<String, dynamic>? gamification;
  final String? token;
  final VoidCallback onRefresh;
  @override
  State<_GamificationTab> createState() => _GamificationTabState();
}

class _GamificationTabState extends State<_GamificationTab> {
  Map<String, dynamic>? _bac;
  bool _loadingBac = false;

  Future<void> _predictBac() async {
    if (widget.token == null) return;
    setState(() => _loadingBac = true);
    try {
      final result = await ArifService.predictBac(widget.token!);
      if (mounted) setState(() { _bac = result; _loadingBac = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingBac = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.gamification;
    if (g == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const _MaarifaLoadingIndicator(),
          const SizedBox(height: 12),
          Text('Chargement…', style: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 13)),
        ]),
      );
    }

    final xp        = g['xp_points'] as int? ?? 0;
    final level     = g['level'] as int? ?? 1;
    final levelName = g['level_name'] as String? ?? 'Débutant';
    final xpNext    = g['xp_next_level'] as int? ?? 100;
    final streak    = g['streak_days'] as int? ?? 0;
    final badges    = (g['badges'] as List<dynamic>?) ?? [];
    final progress  = xpNext > 0 ? (xp / xpNext).clamp(0.0, 1.0) : 0.0;

    return RefreshIndicator(
      color: _kViolet,
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 80),
        children: [
          // ── Carte niveau ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2D1B69), _kVioletDark, _kViolet],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: _kViolet.withValues(alpha: 0.4),
                    blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Niveau $level', style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white60)),
                  Text(levelName, style: GoogleFonts.plusJakartaSans(
                      fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white,
                      letterSpacing: 0.5)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _kGold,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: _kGold.withValues(alpha: 0.5),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(children: [
                    Text('$xp', style: GoogleFonts.plusJakartaSans(
                        fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text('XP', style: GoogleFonts.plusJakartaSans(
                        fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white70)),
                  ]),
                ),
              ]),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('$xp XP', style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: Colors.white54)),
                Text('$xpNext XP pour niveau ${level + 1}', style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: Colors.white54)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
                ),
              ),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('🔥', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 6),
                Text('$streak jours consécutifs', style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.orange.shade200)),
              ]),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Badges ─────────────────────────────────────────────────
          Text('Badges obtenus', style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 12),

          if (badges.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Row(children: [
                const Text('🎖️', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Continue à apprendre !', style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A1A2E))),
                  Text('Envoie ton premier message à MAARIFA\npour débloquer ton premier badge.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500, height: 1.4)),
                ])),
              ]),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
              ),
              itemCount: badges.length,
              itemBuilder: (_, i) {
                final b = badges[i] as Map<String, dynamic>;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kViolet.withValues(alpha: 0.2)),
                    boxShadow: [BoxShadow(color: _kViolet.withValues(alpha: 0.06),
                        blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b['icon'] as String? ?? '🎖️', style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 6),
                    Text(b['label'] as String? ?? '', style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, fontWeight: FontWeight.w800, color: _kViolet)),
                  ]),
                );
              },
            ),

          const SizedBox(height: 24),

          // ── Prédiction BAC ─────────────────────────────────────────
          Text('Prédiction BAC', style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1A1A2E))),
          const SizedBox(height: 12),

          if (_bac == null)
            GestureDetector(
              onTap: _loadingBac ? null : _predictBac,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.teal.withValues(alpha: 0.1), const Color(0xFF00B4C5).withValues(alpha: 0.05)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.teal, Color(0xFF0083A3)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Calculer mon score BAC', style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.navy)),
                    Text('Basé sur tes cours et examens blancs', style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: Colors.grey.shade500)),
                  ])),
                  if (_loadingBac)
                    const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 2))
                  else
                    const Icon(Icons.chevron_right_rounded, color: AppColors.teal),
                ]),
              ),
            )
          else
            _BacPredictionCard(bac: _bac!),
        ],
      ),
    );
  }
}

class _BacPredictionCard extends StatelessWidget {
  const _BacPredictionCard({required this.bac});
  final Map<String, dynamic> bac;

  @override
  Widget build(BuildContext context) {
    final predicted = (bac['predicted_score'] as num?)?.toDouble() ?? 0.0;
    final mention   = bac['mention'] as String? ?? '';
    final onTrack   = bac['on_track'] as bool? ?? false;
    final advice    = bac['advice'] as List<dynamic>? ?? [];

    final Color scoreColor = predicted >= 14
        ? Colors.green.shade600
        : predicted >= 10
            ? Colors.orange.shade600
            : Colors.red.shade600;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Score BAC prédit', style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: Colors.grey.shade500)),
            Text('${predicted.toStringAsFixed(1)}/20',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 36, fontWeight: FontWeight.w900, color: scoreColor)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
            ),
            child: Column(children: [
              Text(onTrack ? '✅' : '⚠️', style: const TextStyle(fontSize: 20)),
              Text(mention, style: GoogleFonts.plusJakartaSans(
                  fontSize: 10, fontWeight: FontWeight.w800, color: scoreColor)),
            ]),
          ),
        ]),
        if (advice.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF0F0F5)),
          const SizedBox(height: 12),
          Text('Conseils MAARIFA', style: GoogleFonts.plusJakartaSans(
              fontSize: 12, fontWeight: FontWeight.w700, color: _kViolet)),
          const SizedBox(height: 8),
          ...advice.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('→ ', style: TextStyle(color: _kViolet, fontWeight: FontWeight.bold)),
              Expanded(child: Text(a.toString(), style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: Colors.grey.shade700, height: 1.4))),
            ]),
          )),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════
// LOADING INDICATOR MAARIFA (étoile animée)
// ════════════════════════════════════════════════════════════
class _MaarifaLoadingIndicator extends StatefulWidget {
  const _MaarifaLoadingIndicator();
  final double size = 40;
  @override
  State<_MaarifaLoadingIndicator> createState() => _MaarifaLoadingIndicatorState();
}

class _MaarifaLoadingIndicatorState extends State<_MaarifaLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Opacity(
        opacity: _pulse.value,
        child: Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_kGold, _kViolet],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: _kViolet.withValues(alpha: 0.3 * _pulse.value),
                  blurRadius: 12, spreadRadius: 2),
            ],
          ),
          child: Icon(Icons.auto_awesome_rounded,
              color: Colors.white, size: widget.size * 0.5),
        ),
      ),
    );
  }
}
