import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/ArifPage.dart';
import 'package:maarif_learn/CoursePage.dart';
import 'package:maarif_learn/MockExamPage.dart';
import 'package:maarif_learn/PageLogin.dart';
import 'package:maarif_learn/ProfilePage.dart';
import 'package:maarif_learn/DailyChallengePage.dart';
import 'package:maarif_learn/SearchPage.dart';
import 'package:maarif_learn/StudyPlanPage.dart';
import 'package:maarif_learn/services/arif_service.dart';
import 'package:maarif_learn/services/auth_service.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/course_service.dart';
import 'package:maarif_learn/theme/app_colors.dart';
import 'package:maarif_learn/widgets/offline_banner.dart';
import 'package:maarif_learn/widgets/whats_new_sheet.dart';
import 'package:maarif_learn/widgets/exam_countdown_card.dart';
import 'package:maarif_learn/widgets/update_banner.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key, this.initialTab = 0});
  /// Onglet ouvert au démarrage (3 = MAARIFA, utilisé par le deep-link push).
  final int initialTab;
  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> with SingleTickerProviderStateMixin {
  late int _currentIndex = widget.initialTab;
  Map<String, dynamic>? _user;
  bool _userLoading = true;
  List<SubjectItem> _subjects = [];
  bool _subjectsLoading = true;
  String? _subjectsError;
  List<dynamic> _arifRecos = [];
  int _unreadArif = 0;
  bool _offline = false;
  String? _offlineAge;
  late AnimationController _navAnim;

  @override
  void initState() {
    super.initState();
    _navAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _navAnim.forward();
    _loadUser();
    _loadSubjects();
    _loadArifRecos();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) WhatsNew.maybeShow(context);
    });
  }

  @override
  void dispose() {
    _navAnim.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthStorage.getUser();
    if (mounted) setState(() { _user = user; _userLoading = false; });
  }

  Future<void> _loadSubjects() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      if (mounted) setState(() { _subjectsLoading = false; _subjectsError = 'Session expirée.'; });
      return;
    }
    try {
      final list = await CourseService.getSubjects(token);
      if (mounted) {
        setState(() {
          _subjects = list;
          _subjectsLoading = false;
          _subjectsError = null;
          _offline = CourseService.offline;
          _offlineAge = CourseService.offlineAge;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _subjectsLoading = false; _subjectsError = e.toString(); });
    }
  }

  Future<void> _loadArifRecos() async {
    final token = await AuthStorage.getToken();
    if (token == null) return;
    try {
      final list = await ArifService.getRecommendations(token);
      final unread = list.where((r) => r['is_read'] == false).length;
      if (mounted) setState(() { _arifRecos = list.take(3).toList(); _unreadArif = unread; });
    } catch (_) {}
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Pagelogin()), (_) => false);
  }

  void _switchTab(int i) {
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    final name = _userLoading ? '…' : (_user?['name']?.toString() ?? 'Élève');
    final level = _userLoading ? '' : ((_user?['level'] as Map?)?['name']?.toString() ?? '');
    final firstName = name.split(' ').first;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Column(
        children: [
          // ── Header hero ───────────────────────────────────────────────
          _HeroHeader(
            name: firstName,
            level: level,
            subjectsCount: _subjects.length,
            onLogout: _logout,
          ),
          // ── Body tab ──────────────────────────────────────────────────
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              ),
              child: switch (_currentIndex) {
                0 => _SubjectsTab(
                    key: const ValueKey('subjects'),
                    userName: firstName,
                    subjects: _subjects,
                    loading: _subjectsLoading,
                    error: _subjectsError,
                    arifRecos: _arifRecos,
                    onOpenArif: () => _switchTab(3),
                    onRetry: _loadSubjects,
                    onRefresh: () async {
                      await Future.wait([_loadUser(), _loadSubjects(), _loadArifRecos()]);
                    },
                    offline: _offline,
                    offlineAge: _offlineAge,
                    levelName: level,
                    onOpenSubject: (s) => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => Coursepage(subjectId: s.id, subjectName: s.name),
                        transitionsBuilder: (_, anim, __, child) => SlideTransition(
                          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                1 => const StudyPlanPage(key: ValueKey('plan')),
                2 => const MockExamPage(key: ValueKey('exams')),
                3 => const ArifPage(key: ValueKey('arif')),
                _ => const ProfilePage(key: ValueKey('profile')),
              },
            ),
          ),
        ],
      ),
      // ── Bottom nav flottant ────────────────────────────────────────────
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        unreadArif: _unreadArif,
        onTap: _switchTab,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// HERO HEADER
// ════════════════════════════════════════════════════════════
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.name,
    required this.level,
    required this.subjectsCount,
    required this.onLogout,
  });
  final String name;
  final String level;
  final int subjectsCount;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2342), Color(0xFF0D3060)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  // Logo badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/maarif_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.school_rounded, color: AppColors.teal, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('maarifmaliedu',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, color: AppColors.teal, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                      if (level.isNotEmpty)
                        Text(level,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 20),
                    tooltip: 'Déconnexion',
                  ),
                ],
              ),
            ),
            // Greeting
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bonjour, $name 👋',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Continuez votre apprentissage aujourd\'hui',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white60),
                  ),
                  const SizedBox(height: 16),
                  // Quick stats
                  Row(
                    children: [
                      _StatBadge(icon: Icons.menu_book_rounded, label: '$subjectsCount matières', color: AppColors.teal),
                      const SizedBox(width: 10),
                      _StatBadge(icon: Icons.auto_awesome_rounded, label: 'MAARIFA actif', color: const Color(0xFF7C5CFC)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SUBJECTS TAB
// ════════════════════════════════════════════════════════════
class _SubjectsTab extends StatelessWidget {
  const _SubjectsTab({
    super.key,
    required this.userName,
    required this.subjects,
    required this.loading,
    required this.error,
    required this.arifRecos,
    required this.onOpenArif,
    required this.onRetry,
    required this.onOpenSubject,
    required this.onRefresh,
    this.offline = false,
    this.offlineAge,
    this.levelName = '',
  });

  final String userName;
  final List<SubjectItem> subjects;
  final bool loading;
  final String? error;
  final List<dynamic> arifRecos;
  final VoidCallback onOpenArif;
  final VoidCallback onRetry;
  final void Function(SubjectItem) onOpenSubject;
  final Future<void> Function() onRefresh;
  final bool offline;
  final String? offlineAge;
  final String levelName;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await onRefresh();
      },
      child: CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        if (offline)
          SliverToBoxAdapter(child: OfflineBanner(ageLabel: offlineAge, onRetry: onRetry)),

        // Mise à jour disponible ?
        const SliverToBoxAdapter(child: UpdateBanner()),

        // Compte à rebours DEF/BAC
        SliverToBoxAdapter(child: ExamCountdownCard(levelName: levelName)),

        // Défi du jour ⚡
        const SliverToBoxAdapter(child: _DailyChallengeCard()),

        // ARIF recommendation block
        if (arifRecos.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _ArifRecoCard(recos: arifRecos, onOpenArif: onOpenArif),
            ),
          ),

        // Section title
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, arifRecos.isEmpty ? 20 : 16, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Text('Mes matières',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const SearchPage())),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Icon(Icons.search_rounded, size: 18, color: AppColors.navy.withValues(alpha: 0.7)),
                  ),
                ),
                const Spacer(),
                if (!loading && subjects.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${subjects.length}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.teal)),
                  ),
              ],
            ),
          ),
        ),

        if (loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 3)),
          )
        else if (error != null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.cloud_off_rounded, size: 40, color: Colors.orange.shade400),
                    ),
                    const SizedBox(height: 16),
                    Text(error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, height: 1.4)),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réessayer'),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ],
                ),
              ),
            ),
          )
        else if (subjects.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.inbox_outlined, size: 56, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text('Aucune matière disponible',
                      style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, fontSize: 15)),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList.separated(
              itemCount: subjects.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 300 + i * 60),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
                  ),
                  child: _SubjectCard(
                    subject: subjects[i],
                    index: i,
                    onTap: () => onOpenSubject(subjects[i]),
                  ),
                );
              },
            ),
          ),
      ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SUBJECT CARD — design premium
// ════════════════════════════════════════════════════════════
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject, required this.index, required this.onTap});
  final SubjectItem subject;
  final int index;
  final VoidCallback onTap;

  static const _gradients = [
    [Color(0xFF00B4C5), Color(0xFF0077A8)],
    [Color(0xFF7C5CFC), Color(0xFF5B3DE8)],
    [Color(0xFFFF6B6B), Color(0xFFEE4444)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFFF59E0B), Color(0xFFD97706)],
    [Color(0xFF06B6D4), Color(0xFF0891B2)],
  ];

  static const _icons = [
    Icons.functions_rounded,
    Icons.science_rounded,
    Icons.history_edu_rounded,
    Icons.language_rounded,
    Icons.biotech_rounded,
    Icons.public_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final gradColors = _gradients[index % _gradients.length];
    final accent = gradColors[0];
    final iconData = _icons[index % _icons.length];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left accent strip + icon
              Container(
                width: 72,
                height: 88,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(iconData, color: Colors.white, size: 28),
                    const SizedBox(height: 4),
                    Text('${subject.coursesCount}',
                        style: GoogleFonts.plusJakartaSans(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.library_books_outlined, size: 13, color: accent),
                          const SizedBox(width: 5),
                          Text(
                            '${subject.coursesCount} cours disponible${subject.coursesCount > 1 ? 's' : ''}',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Progress bar (decorative)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: 0.0,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text('Commencez maintenant →',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11, fontWeight: FontWeight.w600, color: accent)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: accent),
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
// ARIF RECO CARD
// ════════════════════════════════════════════════════════════
class _ArifRecoCard extends StatelessWidget {
  const _ArifRecoCard({required this.recos, required this.onOpenArif});
  final List<dynamic> recos;
  final VoidCallback onOpenArif;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenArif,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7C5CFC), Color(0xFF4F46E5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7C5CFC).withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('MAARIFA te recommande',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(
                    recos.first['message']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.white70, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.white60),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// FLOATING NAV BAR — design ultra moderne
// ════════════════════════════════════════════════════════════
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.currentIndex,
    required this.unreadArif,
    required this.onTap,
  });
  final int currentIndex;
  final int unreadArif;
  final void Function(int) onTap;

  static const _items = [
    (icon: Icons.menu_book_rounded, outlinedIcon: Icons.menu_book_outlined, label: 'Matières'),
    (icon: Icons.calendar_month_rounded, outlinedIcon: Icons.calendar_month_outlined, label: 'Plan'),
    (icon: Icons.assignment_rounded, outlinedIcon: Icons.assignment_outlined, label: 'Examens'),
    (icon: Icons.auto_awesome_rounded, outlinedIcon: Icons.auto_awesome_outlined, label: 'MAARIFA'),
    (icon: Icons.person_rounded, outlinedIcon: Icons.person_outline_rounded, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, (bottomPad > 0 ? bottomPad : 16)),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final selected = currentIndex == i;
            final isArif = i == 3;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.teal : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected ? item.icon : item.outlinedIcon,
                            color: selected ? Colors.white : Colors.white38,
                            size: 22,
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            child: selected
                                ? Column(children: [
                                    const SizedBox(height: 3),
                                    Text(item.label,
                                        style: GoogleFonts.plusJakartaSans(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                  ])
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                      if (isArif && unreadArif > 0)
                        Positioned(
                          top: -2,
                          right: 8,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                            child: Center(
                              child: Text('$unreadArif',
                                  style: GoogleFonts.plusJakartaSans(
                                      fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// CARTE DÉFI DU JOUR ⚡
// ════════════════════════════════════════════════════════════
class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DailyChallengePage()));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFC2410C), Color(0xFFF97316)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFF97316).withValues(alpha: 0.3),
                blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text('⚡', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Défi du jour',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              Text('5 questions éclair · XP doublés · une chance par jour',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85))),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 26),
        ]),
      ),
    );
  }
}
