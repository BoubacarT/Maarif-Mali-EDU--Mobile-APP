import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/CourseDetailPage.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/course_service.dart';
import 'package:maarif_learn/theme/app_colors.dart';

class Coursepage extends StatefulWidget {
  final int subjectId;
  final String subjectName;

  const Coursepage({super.key, required this.subjectId, required this.subjectName});

  @override
  State<Coursepage> createState() => _CoursepageState();
}

class _CoursepageState extends State<Coursepage> {
  List<CourseItem> _courses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      if (mounted) setState(() { _loading = false; _error = 'Session expirée.'; });
      return;
    }
    try {
      final res = await CourseService.getCoursesBySubject(widget.subjectId, token);
      if (mounted) setState(() { _courses = res.courses; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _openCourse(CourseItem course) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => CourseDetailPage(courseId: course.id),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Header hero avec courbe ──────────────────────────────────
          SliverToBoxAdapter(child: _CoursePageHeader(subjectName: widget.subjectName)),

          // ── Contenu ──────────────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator(color: AppColors.teal, strokeWidth: 3)),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 52, color: Colors.grey.shade300),
                      const SizedBox(height: 14),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary, height: 1.45)),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _loadCourses,
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
          else if (_courses.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 52, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text('Aucun cours disponible pour votre niveau.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else ...[
            // Infos summary bar
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              sliver: SliverToBoxAdapter(
                child: _SummaryBar(courses: _courses),
              ),
            ),
            // List of courses
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              sliver: SliverList.separated(
                itemCount: _courses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(milliseconds: 250 + i * 55),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, child) => Opacity(
                      opacity: t,
                      child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child),
                    ),
                    child: _CourseCard(
                      course: _courses[i],
                      number: i + 1,
                      total: _courses.length,
                      onTap: () => _openCourse(_courses[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// HEADER avec clipPath courbe
// ════════════════════════════════════════════════════════════
class _CoursePageHeader extends StatelessWidget {
  const _CoursePageHeader({required this.subjectName});
  final String subjectName;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipPath(
          clipper: _BottomCurveClipper(),
          child: Container(
            height: 160,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2342), Color(0xFF0D3060)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            // decorative circles
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.teal.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: 20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Back button + title overlay
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Programme de cours',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, color: Colors.white60)),
                    ],
                  ),
                ),
                // Subject icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: AppColors.teal, size: 24),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(size.width / 2, size.height + 10, size.width, size.height - 30);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_) => false;
}

// ════════════════════════════════════════════════════════════
// SUMMARY BAR
// ════════════════════════════════════════════════════════════
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.courses});
  final List<CourseItem> courses;

  @override
  Widget build(BuildContext context) {
    final totalVideos = courses.fold(0, (s, c) => s + c.videosCount);
    final totalExo = courses.fold(0, (s, c) => s + c.exercisesCount);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: AppColors.navy.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(icon: Icons.library_books_rounded, value: '${courses.length}', label: 'Cours', color: AppColors.teal),
          _Divider(),
          _SummaryItem(icon: Icons.play_circle_rounded, value: '$totalVideos', label: 'Vidéos', color: const Color(0xFF7C5CFC)),
          _Divider(),
          _SummaryItem(icon: Icons.edit_note_rounded, value: '$totalExo', label: 'Exercices', color: Colors.orange),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 32, width: 1, color: Colors.grey.shade100);
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// COURSE CARD — design moderne avec badge numéroté
// ════════════════════════════════════════════════════════════
class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.number,
    required this.total,
    required this.onTap,
  });
  final CourseItem course;
  final int number;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Numéro badge
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.teal, Color(0xFF0077A8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.teal.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text('$number',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          course.description ?? course.subject.name,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        // Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _Tag(icon: Icons.description_outlined, label: 'Cours', color: AppColors.teal),
                            if (course.videosCount > 0)
                              _Tag(
                                  icon: Icons.play_circle_outline_rounded,
                                  label: '${course.videosCount} vidéo${course.videosCount > 1 ? 's' : ''}',
                                  color: const Color(0xFF7C5CFC)),
                            if (course.exercisesCount > 0)
                              _Tag(
                                  icon: Icons.edit_outlined,
                                  label: '${course.exercisesCount} exo${course.exercisesCount > 1 ? 's' : ''}',
                                  color: Colors.orange),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.teal),
                  ),
                ],
              ),
            ),
            // Bottom progress bar
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: LinearProgressIndicator(
                value: 0.0,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
                minHeight: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
