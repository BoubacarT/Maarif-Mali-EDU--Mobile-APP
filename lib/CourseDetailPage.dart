import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maarif_learn/LessonProgressPage.dart';
import 'package:maarif_learn/config/api_config.dart';
import 'package:maarif_learn/theme/app_colors.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/arif_service.dart';
import 'package:maarif_learn/services/course_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:maarif_learn/widgets/web_video_player.dart';
import 'package:maarif_learn/widgets/video_thumbnail.dart';
import 'package:maarif_learn/widgets/offline_banner.dart';
import 'package:maarif_learn/services/download_service.dart';
import 'dart:io' show File;

class CourseDetailPage extends StatefulWidget {
  final int courseId;

  const CourseDetailPage({super.key, required this.courseId});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CourseDetail? _course;
  bool _loading = true;
  String? _error;
  bool _offline = false;
  String? _offlineAge;
  String? _token;
  bool _compactHeader = false;

  final Map<int, int> _selectedOptionByQuestionId = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      if (mounted) setState(() { _loading = false; _error = 'Session expirée.'; });
      return;
    }
    try {
      final course = await CourseService.getCourseDetail(widget.courseId, token);
      if (mounted) {
        setState(() {
          _course = course;
          _token = token;
          _loading = false;
          _error = null;
          _offline = CourseService.offline;
          _offlineAge = CourseService.offlineAge;
        });
      }
    } on CourseException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _showMaarifaSheet(CourseDetail course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MaarifaCourseSheet(courseId: course.id, courseTitle: course.title, token: _token ?? ''),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("Chargement...", style: TextStyle(fontSize: 15)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }
    if (_error != null || _course == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          backgroundColor: AppColors.navy,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("Erreur", style: TextStyle(fontSize: 15)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.grey.shade600),
                const SizedBox(height: 16),
                Text(_error ?? 'Cours non trouvé.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () { _loading = true; _loadCourse(); },
                  icon: const Icon(Icons.refresh),
                  label: const Text("Réessayer"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final course = _course!;
    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6D28D9),
        icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
        label: Text('MAARIFA', style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12)),
        onPressed: () => _showMaarifaSheet(course),
        elevation: 6,
      ),
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          course.subject.name,
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          if (!kIsWeb) _DownloadButton(course: course, token: _token ?? ''),
          IconButton(
            tooltip: 'Parcours adaptatif',
            icon: const Icon(Icons.route_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => LessonProgressPage(
                    courseId: course.id,
                    courseTitle: course.title,
                  ),
                  transitionsBuilder: (_, anim, __, child) =>
                      FadeTransition(opacity: anim, child: child),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_offline)
            OfflineBanner(ageLabel: _offlineAge, onRetry: () { setState(() => _loading = true); _loadCourse(); }),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            height: _compactHeader ? 0 : null,
            child: _compactHeader
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildHeaderPill(
                                  icon: Icons.menu_book_rounded,
                                  label: "Cours",
                                ),
                                _buildHeaderPill(
                                  icon: Icons.play_circle_fill_rounded,
                                  label: "${course.videos.length} vidéo(s)",
                                ),
                                _buildHeaderPill(
                                  icon: Icons.assignment_rounded,
                                  label: "${course.exercises.length} exercice(s)",
                                ),
                                _buildHeaderPill(
                                  icon: Icons.quiz_rounded,
                                  label: "${course.quiz?.questions.length ?? 0} quiz",
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Material(
                        color: Colors.white,
                        child: TabBar(
                          controller: _tabController,
                          labelColor: AppColors.teal,
                          unselectedLabelColor: Colors.grey,
                          dividerColor: Colors.grey.shade200,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: UnderlineTabIndicator(
                            borderSide: const BorderSide(
                              color: AppColors.teal,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          tabs: const [
                            Tab(icon: Icon(Icons.book), text: "Cours"),
                            Tab(icon: Icon(Icons.play_circle), text: "Vidéos"),
                            Tab(icon: Icon(Icons.description), text: "Exercices"),
                            Tab(icon: Icon(Icons.quiz), text: "Quiz"),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCoursContent(course),
                _buildVideosContent(course.videos),
                _buildExercicesContent(course.exercises),
                _buildQuizContent(course.quiz),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoursContent(CourseDetail course) {
    final hasDescription = course.description != null && course.description!.isNotEmpty;
    final hasFile = course.contentFileUrl != null && course.contentFileUrl!.isNotEmpty;
    final hasExtractedText = (course.documentContentStatus == 'ready') &&
        (course.documentContentText != null && course.documentContentText!.trim().isNotEmpty);

    if (hasExtractedText) {
      return NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          _maybeToggleCompactHeader(notification, 0);
          return false;
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildReadingSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDescription) ...[
                  _buildReadingSectionTitle("Description"),
                  _buildReadingTextBlock(course.description!),
                  const SizedBox(height: 18),
                ],
                _buildReadingSectionTitle("Contenu du cours"),
                const SizedBox(height: 8),
                _buildBookPager(course.documentContentText!),
              ],
            ),
          ),
        ),
      );
    }

    if (!hasFile) {
      return NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          _maybeToggleCompactHeader(notification, 0);
          return false;
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _buildReadingSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDescription) ...[
                  _buildReadingSectionTitle("Description"),
                  _buildReadingTextBlock(course.description!),
                ] else
                  const Text(
                    "Aucun contenu supplémentaire pour ce cours.",
                    style: TextStyle(color: Colors.grey),
                  ),
                if (course.documentContentStatus == 'failed' &&
                    course.documentContentError != null &&
                    course.documentContentError!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Erreur d'extraction du document: ${course.documentContentError}",
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final fileUri = _resolveCourseFileUri(course.contentFileUrl!);
    if (fileUri == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            "Le fichier du cours est invalide.",
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Lecteur PDF inline (Syncfusion — fonctionne sur web et mobile)
    return Column(
      children: [
        if (hasDescription)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: _buildReadingSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReadingSectionTitle("Description"),
                  const SizedBox(height: 8),
                  _buildReadingTextBlock(course.description!),
                ],
              ),
            ),
          ),
        Expanded(child: _buildPdfViewer(fileUri)),
      ],
    );

  }

  Uri? _resolveCourseFileUri(String rawUrl) {
    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null) return null;
    if (parsed.hasScheme) {
      // Remplacer localhost par l'hôte réel de l'API
      return _replaceLocalhostWithApiHost(parsed);
    }
    final normalizedPath = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return Uri.tryParse('${ApiConfig.baseUrl}$normalizedPath');
  }

  Uri _replaceLocalhostWithApiHost(Uri uri) {
    if (!_isLocalHost(uri.host)) return uri;
    final apiUri = Uri.tryParse(ApiConfig.baseUrl);
    if (apiUri == null || apiUri.host.isEmpty) return uri;
    return uri.replace(scheme: apiUri.scheme, host: apiUri.host,
        port: apiUri.hasPort ? apiUri.port : null);
  }

  Map<String, String> _buildWebHeaders([Uri? uri]) {
    final headers = <String, String>{
      'Accept': '*/*',
    };
    if (_shouldAttachAuthHeader(uri) && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  bool _shouldAttachAuthHeader(Uri? uri) {
    if (uri == null) return true;
    if (!uri.hasScheme) return true;

    final apiUri = Uri.tryParse(ApiConfig.baseUrl);
    if (apiUri == null) return true;

    final sameHost = uri.host.toLowerCase() == apiUri.host.toLowerCase();
    final samePort = (uri.hasPort ? uri.port : _defaultPort(uri.scheme)) ==
        (apiUri.hasPort ? apiUri.port : _defaultPort(apiUri.scheme));
    return sameHost && samePort;
  }

  int _defaultPort(String scheme) {
    if (scheme == 'https') return 443;
    if (scheme == 'http') return 80;
    return -1;
  }

  String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  String _normalizeDocumentText(String input) {
    final withUnixNewLines = input.replaceAll('\r\n', '\n');
    return withUnixNewLines.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }

  Widget _buildReadingSurface({required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 760),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildReadingSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: Color(0xFF3E3427),
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildReadingTextBlock(String text) {
    return SelectableText(
      _normalizeDocumentText(_decodeHtmlEntities(text)),
      style: const TextStyle(
        fontSize: 16,
        height: 1.82,
        color: Color(0xFF2F2A24),
      ),
      textAlign: TextAlign.justify,
    );
  }

  Widget _buildBookPager(String text) {
    return _BookPager(text: _normalizeDocumentText(_decodeHtmlEntities(text)));
  }

  Widget _buildSolutionCard(String solution) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.teal.withValues(alpha: 0.08),
            AppColors.navy.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_rounded, color: AppColors.teal, size: 16),
              SizedBox(width: 6),
              Text(
                "Solution guidée",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildReadingTextBlock(solution),
        ],
      ),
    );
  }

  Widget _buildHeaderPill({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 36, color: AppColors.teal),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionBadge({
    required IconData icon,
    required String label,
    Color? background,
    Color? foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background ?? AppColors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foreground ?? AppColors.teal),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground ?? AppColors.teal,
            ),
          ),
        ],
      ),
    );
  }

  String _exerciseDisplayTitle(ExerciseItem exercise, int index) {
    final fallback = "Exercice ${index + 1}";
    final raw = exercise.question.trim();
    if (raw.isEmpty) return fallback;

    final candidate = _normalizeDocumentText(_decodeHtmlEntities(raw));
    final looksLikeFileName = RegExp(
      r'^[^\s]+\.(pdf|doc|docx|txt|rtf|odt)$',
      caseSensitive: false,
    ).hasMatch(candidate);
    final looksLikePathOrUrl = candidate.contains('/storage/') || candidate.startsWith('http');

    if (looksLikeFileName || looksLikePathOrUrl) return fallback;
    return candidate;
  }

  void _maybeToggleCompactHeader(UserScrollNotification notification, int tabIndex) {
    if (_tabController.index != tabIndex) return;
    if (notification.direction == ScrollDirection.reverse && !_compactHeader) {
      setState(() => _compactHeader = true);
    } else if (notification.direction == ScrollDirection.forward && _compactHeader) {
      setState(() => _compactHeader = false);
    }
  }

  Widget _buildVideosContent(List<VideoItem> videos) {
    if (videos.isEmpty) {
      return _buildEmptyState(
        icon: Icons.videocam_off_rounded,
        title: "Aucune vidéo pour ce cours",
        subtitle: "Les contenus vidéo seront disponibles prochainement.",
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: videos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final v = videos[index];
        final uri = _resolveVideoUri(v);
        return _buildVideoCard(video: v, index: index, uri: uri);
      },
    );
  }

  String? _extractYouTubeId(VideoItem video) {
    final candidates = [video.videoUrl, video.embedUrl, video.videoFileUrl];
    for (final raw in candidates) {
      if (raw == null || raw.trim().isEmpty) continue;
      final url = raw.trim();
      // youtu.be/ID
      final shortMatch = RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})').firstMatch(url);
      if (shortMatch != null) return shortMatch.group(1);
      // youtube.com/watch?v=ID  or /embed/ID
      final longMatch = RegExp(r'(?:v=|/embed/|/v/)([a-zA-Z0-9_-]{11})').firstMatch(url);
      if (longMatch != null) return longMatch.group(1);
    }
    return null;
  }

  Widget _buildVideoCard({
    required VideoItem video,
    required int index,
    required Uri? uri,
  }) {
    final ytId = _extractYouTubeId(video);
    final hasSource = uri != null || ytId != null;
    final isYoutube = ytId != null;

    void onPlay() {
      if (ytId != null) { _openYouTube(ytId); }
      else if (uri != null) { _openVideoInApp(video); }
    }

    return GestureDetector(
      onTap: hasSource ? onPlay : null,
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
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // ── Miniature gauche 16:9 ─────────────────────────────
            SizedBox(
              width: 130,
              height: 90,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background — vraie preview vidéo ou miniature YouTube
                  if (isYoutube)
                    Image.network(
                      'https://img.youtube.com/vi/$ytId/mqdefault.jpg',
                      fit: BoxFit.cover,
                      width: 130,
                      height: 90,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFF1A1A2E),
                        child: const Center(
                          child: Icon(Icons.smart_display_rounded, color: Colors.white24, size: 28),
                        ),
                      ),
                    )
                  else if (uri != null)
                    VideoThumbnailWidget(
                      videoUrl: uri.toString(),
                      width: 130,
                      height: 90,
                    )
                  else
                    Container(
                      color: const Color(0xFF0A2342),
                      child: const Center(
                        child: Icon(Icons.videocam_off_rounded, color: Colors.white24, size: 24),
                      ),
                    ),
                  // Dark overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
                      ),
                    ),
                  ),
                  // Play button
                  if (hasSource)
                    Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isYoutube ? const Color(0xFFFF0000) : AppColors.teal,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isYoutube ? Colors.red : AppColors.teal).withValues(alpha: 0.45),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                      ),
                    ),
                  // Duration badge bottom-right
                  if (video.duration != null && video.duration!.trim().isNotEmpty)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(video.duration!,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
            // ── Infos droite ───────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge numéro + source
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Vidéo ${index + 1}',
                              style: const TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.teal)),
                        ),
                        if (isYoutube) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.smart_display_rounded, size: 9, color: Colors.red),
                                SizedBox(width: 3),
                                Text('YouTube',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Titre
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.25),
                    ),
                    if (video.description != null && video.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        video.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                    if (!hasSource) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 12, color: Colors.red.shade400),
                          const SizedBox(width: 4),
                          Text('Indisponible',
                              style: TextStyle(fontSize: 10, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openYouTube(String videoId) {
    final uri = Uri.parse('https://www.youtube.com/watch?v=$videoId');
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildExercicesContent(List<ExerciseItem> exercises) {
    if (exercises.isEmpty) {
      return _buildEmptyState(
        icon: Icons.assignment_outlined,
        title: "Aucun exercice pour ce cours",
        subtitle: "Continuez avec les leçons et revenez ici pour pratiquer.",
      );
    }
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        _maybeToggleCompactHeader(notification, 2);
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: exercises.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final e = exercises[index];
          final exerciseTitle = _exerciseDisplayTitle(e, index);
          return Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              collapsedShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center_rounded, color: AppColors.teal, size: 18),
              ),
              title: Text(
                exerciseTitle,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSectionBadge(
                      icon: Icons.tag_rounded,
                      label: "Exercice ${index + 1}",
                    ),
                    if (e.difficulty != null && e.difficulty!.trim().isNotEmpty)
                      _buildSectionBadge(
                        icon: Icons.flag_rounded,
                        label: e.difficulty!.trim(),
                        background: AppColors.navy.withValues(alpha: 0.08),
                        foreground: AppColors.navy,
                      ),
                  ],
                ),
              ),
              children: [
                _buildExerciseReadingBody(e),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExerciseReadingBody(ExerciseItem e) {
    final hasExtractedText = (e.documentContentStatus == 'ready') &&
        (e.documentContentText != null && e.documentContentText!.trim().isNotEmpty);
    final hasFile = e.contentFileUrl != null && e.contentFileUrl!.trim().isNotEmpty;
    final hasSolution = e.solution != null && e.solution!.trim().isNotEmpty;

    if (hasExtractedText) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: _buildReadingSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReadingSectionTitle("Énoncé / contenu"),
              const SizedBox(height: 8),
              _buildBookPager(e.documentContentText!),
              if (hasSolution) ...[
                const SizedBox(height: 16),
                _buildSolutionCard(e.solution!),
              ],
            ],
          ),
        ),
      );
    }

    if (hasFile) {
      final fileUri = _resolveCourseFileUri(e.contentFileUrl!);
      if (fileUri == null) {
        return Padding(
          padding: EdgeInsets.all(12),
          child: _buildSectionBadge(
            icon: Icons.error_outline_rounded,
            label: "Le fichier de l'exercice est invalide.",
            background: Colors.red.withValues(alpha: 0.1),
            foreground: Colors.red.shade700,
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_rounded, size: 16, color: AppColors.navy),
                const SizedBox(width: 6),
                const Text(
                  "Support de l'exercice",
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildPdfViewerFixed(fileUri, height: 460),
            if (hasSolution) ...[
              const SizedBox(height: 16),
              _buildSolutionCard(e.solution!),
            ],
          ],
        ),
      );
    }

    if ((e.documentContentStatus == 'failed' ||
            e.documentContentStatus == 'unreadable' ||
            e.documentContentStatus == 'missing') &&
        e.documentContentError != null &&
        e.documentContentError!.trim().isNotEmpty) {
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
        ),
        child: Text(
          "Erreur d'extraction du document: ${e.documentContentError}",
          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
        ),
      );
    }

    if (hasSolution) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: _buildSolutionCard(e.solution!),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: _buildSectionBadge(
        icon: Icons.info_outline_rounded,
        label: "Aucun détail supplémentaire pour cet exercice.",
        background: Colors.grey.shade100,
        foreground: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildQuizContent(QuizDetail? quiz) {
    if (quiz == null || quiz.questions.isEmpty) {
      return _buildEmptyState(
        icon: Icons.quiz_outlined,
        title: "Aucun quiz pour ce cours",
        subtitle: "Le quiz apparaîtra dès que l'enseignant l'ajoute.",
      );
    }

    final totalQuestions = quiz.questions.length;
    final answeredCount = quiz.questions
        .where((q) => _selectedOptionByQuestionId[q.id] != null)
        .length;
    final correctCount = _correctAnswersCount(quiz.questions);
    final progress = totalQuestions == 0 ? 0.0 : answeredCount / totalQuestions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.teal.withValues(alpha: 0.12),
                AppColors.navy.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Progression du quiz",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.navy.withValues(alpha: 0.08),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.teal),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSectionBadge(
                    icon: Icons.assignment_turned_in_rounded,
                    label: "$answeredCount / $totalQuestions répondues",
                  ),
                  _buildSectionBadge(
                    icon: Icons.emoji_events_rounded,
                    label: "$correctCount bonne(s) réponse(s)",
                    background: Colors.green.withValues(alpha: 0.14),
                    foreground: Colors.green.shade800,
                  ),
                ],
              ),
            ],
          ),
        ),
        for (int index = 0; index < quiz.questions.length; index++)
          _buildQuizQuestionCard(quiz.questions[index], index),
      ],
    );
  }

  Widget _buildQuizQuestionCard(QuizQuestion q, int index) {
    final selectedOptionId = _selectedOptionByQuestionId[q.id];
    final answered = selectedOptionId != null;
    final correctOptionId = q.options
        .where((o) => o.isCorrect)
        .map((o) => o.id)
        .cast<int?>()
        .firstWhere((id) => id != null, orElse: () => null);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSectionBadge(
                  icon: Icons.help_outline_rounded,
                  label: "Question ${index + 1}",
                  background: AppColors.navy.withValues(alpha: 0.08),
                  foreground: AppColors.navy,
                ),
                if (answered)
                  _buildSectionBadge(
                    icon: selectedOptionId == correctOptionId
                        ? Icons.check_circle
                        : Icons.cancel,
                    label: selectedOptionId == correctOptionId
                        ? "Bonne réponse"
                        : "À corriger",
                    background: (selectedOptionId == correctOptionId
                            ? Colors.green
                            : Colors.red)
                        .withValues(alpha: 0.12),
                    foreground: selectedOptionId == correctOptionId
                        ? Colors.green.shade800
                        : Colors.red.shade700,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              q.text,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            for (final opt in q.options)
              _buildQuizOptionTile(
                question: q,
                option: opt,
                answered: answered,
                selectedOptionId: selectedOptionId,
                correctOptionId: correctOptionId,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizOptionTile({
    required QuizQuestion question,
    required QuizOption option,
    required bool answered,
    required int? selectedOptionId,
    required int? correctOptionId,
  }) {
    final isSelected = selectedOptionId == option.id;
    final isCorrect = option.isCorrect;

    Color background = Colors.white;
    Color border = Colors.grey.shade300;
    Color textColor = Colors.black87;
    IconData icon = Icons.radio_button_unchecked;
    Color iconColor = Colors.grey;

    if (answered) {
      if (isSelected && isCorrect) {
        background = Colors.green.shade50;
        border = Colors.green.shade300;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        iconColor = Colors.green;
      } else if (isSelected && !isCorrect) {
        background = Colors.red.shade50;
        border = Colors.red.shade200;
        textColor = Colors.red.shade800;
        icon = Icons.cancel;
        iconColor = Colors.red;
      } else if (!isSelected && isCorrect && correctOptionId == option.id) {
        background = Colors.green.shade50;
        border = Colors.green.shade200;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle_outline;
        iconColor = Colors.green.shade400;
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: answered
            ? null
            : () {
                if (option.isCorrect) {
                  HapticFeedback.mediumImpact();
                } else {
                  HapticFeedback.heavyImpact();
                }
                setState(() {
                  _selectedOptionByQuestionId[question.id] = option.id;
                });
              },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 19, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  option.text,
                  style: TextStyle(
                    fontSize: 13,
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _correctAnswersCount(List<QuizQuestion> questions) {
    int correct = 0;
    for (final q in questions) {
      final selected = _selectedOptionByQuestionId[q.id];
      if (selected == null) continue;
      QuizOption? picked;
      for (final option in q.options) {
        if (option.id == selected) {
          picked = option;
          break;
        }
      }
      if (picked?.isCorrect == true) {
        correct += 1;
      }
    }
    return correct;
  }

  Uri? _resolveVideoUri(VideoItem video) {
    final candidates = <String?>[
      video.videoFileUrl,
      video.videoUrl,
      video.embedUrl,
    ];
    for (final raw in candidates) {
      if (raw == null || raw.trim().isEmpty) continue;
      final rawValue = raw.trim();
      final parsed = Uri.tryParse(rawValue);
      if (parsed == null) continue;
      if (parsed.hasScheme) return _normalizeAbsoluteMediaUri(parsed);
      final normalizedPath = rawValue.startsWith('/') ? rawValue : '/$rawValue';
      final baseOrigins = _candidateBaseOrigins();
      for (final origin in baseOrigins) {
        final absolute = Uri.tryParse('$origin$normalizedPath');
        if (absolute != null) return _normalizeAbsoluteMediaUri(absolute);
      }
    }
    return null;
  }

  Uri _normalizeAbsoluteMediaUri(Uri uri) {
    if (!uri.hasScheme || uri.host.isEmpty) return uri;
    if (!_isLocalHost(uri.host)) return uri;

    final apiUri = Uri.tryParse(ApiConfig.baseUrl);
    if (apiUri == null || apiUri.host.isEmpty) return uri;

    return Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
      path: uri.path,
      query: uri.query,
      fragment: uri.fragment,
    );
  }

  bool _isLocalHost(String host) {
    final h = host.toLowerCase();
    return h == 'localhost' || h == '127.0.0.1' || h == '::1';
  }

  List<String> _candidateBaseOrigins() {
    final origins = <String>[];

    final courseFileUrl = _course?.contentFileUrl;
    if (courseFileUrl != null && courseFileUrl.trim().isNotEmpty) {
      final courseUri = Uri.tryParse(courseFileUrl.trim());
      if (courseUri != null && courseUri.hasScheme && courseUri.host.isNotEmpty) {
        origins.add('${courseUri.scheme}://${courseUri.host}${courseUri.hasPort ? ':${courseUri.port}' : ''}');
      }
    }

    final apiUri = Uri.tryParse(ApiConfig.baseUrl);
    if (apiUri != null && apiUri.hasScheme && apiUri.host.isNotEmpty) {
      final apiOrigin = '${apiUri.scheme}://${apiUri.host}${apiUri.hasPort ? ':${apiUri.port}' : ''}';
      if (!origins.contains(apiOrigin)) {
        origins.add(apiOrigin);
      }
    }

    return origins;
  }

  void _openVideoInApp(VideoItem video) {
    final uri = _resolveVideoUri(video);
    if (uri == null) return;

    if (_isHlsStream(uri) && kIsWeb) {
      _openVideoOnBrowser(uri);
      return;
    }

    if (_isDirectVideoFile(uri)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VideoPlayerPage(
            title: video.title,
            uri: uri,
            headers: _buildWebHeaders(uri),
            shouldResolveWithAuthOnWeb: false,
          ),
        ),
      );
      return;
    }

    // Autres formats (embed) — ouvrir dans le navigateur
    if (kIsWeb) {
      _openVideoOnBrowser(uri);
      return;
    }

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) => NavigationDecision.navigate,
        ),
      )
      ..loadRequest(
        uri,
        headers: _buildWebHeaders(uri),
      );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.navy,
            title: Text(
              video.title,
              style: const TextStyle(fontSize: 15),
            ),
          ),
          body: WebViewWidget(controller: controller),
        ),
      ),
    );
  }

  /// Lecteur PDF inline — design impressionnant avec toolbar
  Widget _buildPdfViewer(Uri fileUri) {
    return _PdfViewerWidget(uri: fileUri, headers: _buildWebHeaders(fileUri));
  }

  /// Lecteur PDF inline pour les exercices (hauteur fixe)
  Widget _buildPdfViewerFixed(Uri fileUri, {double height = 480}) {
    return SizedBox(
      height: height,
      child: _PdfViewerWidget(uri: fileUri, headers: _buildWebHeaders(fileUri), compact: true),
    );
  }

  Future<void> _openVideoOnBrowser(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (launched || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Impossible d'ouvrir la vidéo dans le navigateur."),
      ),
    );
  }

  bool _isDirectVideoFile(Uri uri) {
    final path = uri.path.toLowerCase();
    if (path.contains('/api/videos/') && path.endsWith('/stream')) {
      return true;
    }
    return path.endsWith('.mp4') ||
        path.endsWith('.m3u8') ||
        path.endsWith('.mov') ||
        path.endsWith('.webm') ||
        path.endsWith('.mkv');
  }

  bool _isHlsStream(Uri uri) {
    return uri.path.toLowerCase().endsWith('.m3u8');
  }
}

class _BookPager extends StatefulWidget {
  final String text;

  const _BookPager({required this.text});

  @override
  State<_BookPager> createState() => _BookPagerState();
}

class _BookPagerState extends State<_BookPager> {
  static const int _maxCharsPerPage = 900;
  late final List<String> _pages = _splitIntoPages(widget.text);
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final pageHeight = MediaQuery.of(context).size.height * 0.74;

    return Column(
      children: [
        SizedBox(
          height: pageHeight.clamp(380.0, 760.0),
          child: PageView.builder(
            itemCount: _pages.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Container(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5DFD0)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _pages[index],
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.85,
                      color: Color(0xFF2F2A24),
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "Page ${_currentPage + 1} / ${_pages.length}  •  Glisser horizontalement",
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6D6355),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  List<String> _splitIntoPages(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) return const ["Aucun contenu."];

    final paragraphs = cleaned.split('\n\n');
    final pages = <String>[];
    final buffer = StringBuffer();
    int currentCount = 0;

    for (final rawParagraph in paragraphs) {
      final paragraph = rawParagraph.trim();
      if (paragraph.isEmpty) continue;
      final extra = paragraph.length + (currentCount == 0 ? 0 : 2);

      if (currentCount > 0 && currentCount + extra > _maxCharsPerPage) {
        pages.add(buffer.toString().trim());
        buffer.clear();
        currentCount = 0;
      }

      if (currentCount > 0) {
        buffer.write('\n\n');
      }
      buffer.write(paragraph);
      currentCount += extra;
    }

    if (buffer.isNotEmpty) {
      pages.add(buffer.toString().trim());
    }

    return pages.isEmpty ? const ["Aucun contenu."] : pages;
  }
}

class _VideoPlayerPage extends StatefulWidget {
  final String title;
  final Uri uri;
  final Map<String, String> headers;
  final bool shouldResolveWithAuthOnWeb;

  const _VideoPlayerPage({
    required this.title,
    required this.uri,
    required this.headers,
    required this.shouldResolveWithAuthOnWeb,
  });

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  // Mobile: video_player controller
  VideoPlayerController? _controller;
  bool _showControls = true;
  String? _mobileError;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _initMobilePlayer();
  }

  Future<void> _initMobilePlayer() async {
    try {
      // Version téléchargée hors-ligne prioritaire
      final local = await DownloadService.localFile(widget.uri.toString());
      final c = local != null
          ? VideoPlayerController.file(local)
          : VideoPlayerController.networkUrl(widget.uri, httpHeaders: widget.headers);
      await c.initialize();
      await c.play();
      if (mounted) setState(() => _controller = c);
    } catch (e) {
      if (mounted) setState(() => _mobileError = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            tooltip: 'Ouvrir dans le navigateur',
            onPressed: () => launchUrl(widget.uri, mode: LaunchMode.externalApplication),
          ),
        ],
      ),
      body: kIsWeb ? _buildWebPlayer() : _buildMobilePlayer(),
    );
  }

  // ── WEB: HTML5 native video element ──────────────────────────────────────
  Widget _buildWebPlayer() {
    return WebVideoPlayer(videoUrl: widget.uri.toString(), title: widget.title);
  }

  // ── MOBILE: video_player ─────────────────────────────────────────────────
  Widget _buildMobilePlayer() {
    if (_mobileError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text(_mobileError!, style: const TextStyle(color: Colors.white60, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => launchUrl(widget.uri, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Ouvrir'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
              ),
            ],
          ),
        ),
      );
    }
    final c = _controller;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    }
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
          if (_showControls) ...[
            Container(color: Colors.black38),
            IconButton(
              iconSize: 64,
              icon: Icon(c.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Colors.white),
              onPressed: () => setState(() { c.value.isPlaying ? c.pause() : c.play(); }),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  VideoProgressIndicator(c, allowScrubbing: true,
                      colors: VideoProgressColors(
                          playedColor: AppColors.teal,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── PDF Viewer impressionnant avec toolbar ─────────────────────────────────
class _PdfViewerWidget extends StatefulWidget {
  final Uri uri;
  final Map<String, String> headers;
  final bool compact;

  const _PdfViewerWidget({
    required this.uri,
    required this.headers,
    this.compact = false,
  });

  @override
  State<_PdfViewerWidget> createState() => _PdfViewerWidgetState();
}

class _PdfViewerWidgetState extends State<_PdfViewerWidget> {
  final PdfViewerController _pdfController = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;
  bool _loaded = false;
  double _zoom = 1.0;
  File? _localFile; // version téléchargée hors-ligne, si disponible
  bool _localChecked = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _localChecked = true;
    } else {
      DownloadService.localFile(widget.uri.toString()).then((f) {
        if (mounted) setState(() { _localFile = f; _localChecked = true; });
      });
    }
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toolbar ────────────────────────────────────────────────────────
        if (!widget.compact)
          Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, Color(0xFF0D2E55)],
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Page counter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 14, color: AppColors.teal),
                      const SizedBox(width: 6),
                      Text(
                        _loaded ? '$_currentPage / $_totalPages' : '...',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Prev / Next page
                _ToolbarBtn(
                  icon: Icons.chevron_left_rounded,
                  onTap: _currentPage > 1 ? () {
                    _pdfController.previousPage();
                    setState(() => _currentPage--);
                  } : null,
                ),
                _ToolbarBtn(
                  icon: Icons.chevron_right_rounded,
                  onTap: _currentPage < _totalPages ? () {
                    _pdfController.nextPage();
                    setState(() => _currentPage++);
                  } : null,
                ),
                const Spacer(),
                // Zoom out / in
                _ToolbarBtn(
                  icon: Icons.zoom_out_rounded,
                  onTap: _zoom > 0.5 ? () {
                    setState(() => _zoom = (_zoom - 0.25).clamp(0.5, 4.0));
                    _pdfController.zoomLevel = _zoom;
                  } : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    '${(_zoom * 100).round()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                _ToolbarBtn(
                  icon: Icons.zoom_in_rounded,
                  onTap: _zoom < 4.0 ? () {
                    setState(() => _zoom = (_zoom + 0.25).clamp(0.5, 4.0));
                    _pdfController.zoomLevel = _zoom;
                  } : null,
                ),
                const SizedBox(width: 4),
                // Download / open
                _ToolbarBtn(
                  icon: Icons.open_in_new_rounded,
                  color: AppColors.teal,
                  onTap: () => launchUrl(widget.uri, mode: LaunchMode.externalApplication),
                ),
              ],
            ),
          ),
        // ── PDF Content ────────────────────────────────────────────────────
        Expanded(
          child: Container(
            decoration: widget.compact
                ? null
                : BoxDecoration(
                    border: Border(
                      left: BorderSide(color: AppColors.teal.withValues(alpha: 0.3), width: 2),
                      right: BorderSide(color: AppColors.teal.withValues(alpha: 0.3), width: 2),
                      bottom: BorderSide(color: AppColors.teal.withValues(alpha: 0.3), width: 2),
                    ),
                  ),
            child: Stack(
              children: [
                if (!_localChecked)
                  const SizedBox.shrink()
                else if (_localFile != null)
                  // Version téléchargée : lecture 100 % hors-ligne
                  SfPdfViewer.file(
                    _localFile!,
                    controller: _pdfController,
                    enableDoubleTapZooming: true,
                    enableTextSelection: true,
                    canShowScrollHead: !widget.compact,
                    canShowScrollStatus: !widget.compact,
                    canShowPaginationDialog: false,
                    pageLayoutMode: PdfPageLayoutMode.continuous,
                    onDocumentLoaded: (d) {
                      if (mounted) {
                        setState(() {
                          _totalPages = d.document.pages.count;
                          _loaded = true;
                        });
                      }
                    },
                    onPageChanged: (d) {
                      if (mounted) setState(() => _currentPage = d.newPageNumber);
                    },
                  )
                else
                SfPdfViewer.network(
                  widget.uri.toString(),
                  headers: widget.headers,
                  controller: _pdfController,
                  enableDoubleTapZooming: true,
                  enableTextSelection: true,
                  canShowScrollHead: !widget.compact,
                  canShowScrollStatus: !widget.compact,
                  canShowPaginationDialog: false,
                  pageLayoutMode: PdfPageLayoutMode.continuous,
                  onDocumentLoaded: (d) {
                    if (mounted) {
                      setState(() {
                        _totalPages = d.document.pages.count;
                        _loaded = true;
                      });
                    }
                  },
                  onPageChanged: (d) {
                    if (mounted) setState(() => _currentPage = d.newPageNumber);
                  },
                ),
                if (!_loaded)
                  Container(
                    color: const Color(0xFFF8FAFF),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: AppColors.teal, strokeWidth: 3),
                          SizedBox(height: 16),
                          Text('Chargement du document...', style: TextStyle(color: AppColors.navy, fontSize: 14)),
                        ],
                      ),
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

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _ToolbarBtn({required this.icon, this.onTap, this.color = Colors.white70});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: onTap != null ? Colors.white10 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: onTap != null ? color : Colors.white24),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// MAARIFA COURSE SHEET — Résumé · Flashcards · Exercices
// ════════════════════════════════════════════════════════════
const _kV  = Color(0xFF6D28D9);
const _kVD = Color(0xFF4C1D95);
const _kG  = Color(0xFFF59E0B);

class _MaarifaCourseSheet extends StatefulWidget {
  const _MaarifaCourseSheet({required this.courseId, required this.courseTitle, required this.token});
  final int courseId;
  final String courseTitle;
  final String token;
  @override
  State<_MaarifaCourseSheet> createState() => _MaarifaCourseSheetState();
}

class _MaarifaCourseSheetState extends State<_MaarifaCourseSheet> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _summary;
  List<dynamic> _flashcards = [];
  List<dynamic> _questions = [];
  bool _loadingSummary = false, _loadingCards = false, _loadingEx = false;
  int _cardIndex = 0;
  bool _cardFlipped = false;
  final Map<int, String> _answers = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _getSummary() async {
    setState(() => _loadingSummary = true);
    try {
      final s = await ArifService.summarizeCourse(widget.courseId, widget.token);
      if (mounted) setState(() { _summary = s; _loadingSummary = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _getFlashcards() async {
    setState(() => _loadingCards = true);
    try {
      final cards = await ArifService.getCourseFlashcards(widget.courseId, widget.token);
      if (mounted) setState(() { _flashcards = cards; _loadingCards = false; _cardIndex = 0; _cardFlipped = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCards = false);
    }
  }

  Future<void> _getExercise(String diff) async {
    setState(() => _loadingEx = true);
    try {
      final qs = await ArifService.getCourseExercise(widget.courseId, widget.token, difficulty: diff);
      if (mounted) setState(() { _questions = qs; _loadingEx = false; _answers.clear(); });
    } catch (_) {
      if (mounted) setState(() => _loadingEx = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF4F7FB),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2D1B69), _kVD, _kV]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.auto_awesome_rounded, color: _kG, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('MAARIFA', style: GoogleFonts.plusJakartaSans(
                    fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
                Text(widget.courseTitle, style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: Colors.white54), maxLines: 1, overflow: TextOverflow.ellipsis),
              ])),
            ]),
          ),
          // Tabs
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: TabBar(
              controller: _tabs,
              labelColor: _kV,
              unselectedLabelColor: Colors.grey,
              indicator: BoxDecoration(color: const Color(0xFFF5F3FF), borderRadius: BorderRadius.circular(12)),
              dividerColor: Colors.transparent,
              labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 12),
              tabs: const [Tab(text: '📝 Résumé'), Tab(text: '🗂️ Flashcards'), Tab(text: '✍️ Exercice')],
            ),
          ),
          const SizedBox(height: 8),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _SummaryTab(summary: _summary, loading: _loadingSummary, onGenerate: _getSummary),
                _FlashcardsTab(
                  cards: _flashcards, loading: _loadingCards, cardIndex: _cardIndex, flipped: _cardFlipped,
                  onGenerate: _getFlashcards,
                  onPrev: () => setState(() { _cardIndex = (_cardIndex - 1).clamp(0, _flashcards.length - 1); _cardFlipped = false; }),
                  onNext: () => setState(() { _cardIndex = (_cardIndex + 1).clamp(0, _flashcards.length - 1); _cardFlipped = false; }),
                  onFlip: () => setState(() => _cardFlipped = !_cardFlipped),
                ),
                _ExerciceTab(questions: _questions, loading: _loadingEx, answers: _answers,
                    onGenerate: _getExercise,
                    onAnswer: (qi, opt) => setState(() => _answers[qi] = opt)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Summary tab ──────────────────────────────────────────────
class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.summary, required this.loading, required this.onGenerate});
  final String? summary;
  final bool loading;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: _kV));

    if (summary == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.summarize_rounded, size: 48, color: _kV),
          const SizedBox(height: 12),
          Text('Générer un résumé IA', style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 6),
          Text('MAARIFA va créer un résumé\npédagogique de ce cours.',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey, height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onGenerate,
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Générer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kV, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ]),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Text(summary!, style: GoogleFonts.plusJakartaSans(fontSize: 13, height: 1.7, color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: onGenerate,
          icon: const Icon(Icons.refresh_rounded, size: 16, color: _kV),
          label: Text('Régénérer', style: GoogleFonts.plusJakartaSans(color: _kV, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Flashcards tab ───────────────────────────────────────────
class _FlashcardsTab extends StatelessWidget {
  const _FlashcardsTab({
    required this.cards, required this.loading, required this.cardIndex,
    required this.flipped, required this.onGenerate,
    required this.onPrev, required this.onNext, required this.onFlip,
  });
  final List<dynamic> cards;
  final bool loading, flipped;
  final int cardIndex;
  final VoidCallback onGenerate, onPrev, onNext, onFlip;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: _kV),
          const SizedBox(height: 16),
          Text('MAARIFA prépare tes flashcards…',
              style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: Colors.grey.shade500)),
        ]),
      );
    }

    if (cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_kV.withValues(alpha: 0.12), _kG.withValues(alpha: 0.10)]),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.style_rounded, size: 40, color: _kV),
            ),
            const SizedBox(height: 18),
            Text('Cartes mémoire', style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.navy)),
            const SizedBox(height: 8),
            Text('MAARIFA génère 8 cartes recto-verso\npour réviser l\'essentiel de ce cours.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: Colors.grey.shade500, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () { HapticFeedback.lightImpact(); onGenerate(); },
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text('Générer les cartes',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
              style: FilledButton.styleFrom(
                backgroundColor: _kV, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ]),
        ),
      );
    }

    final card       = cards[cardIndex] as Map<String, dynamic>;
    final question   = card['question'] as String? ?? '';
    final answer     = card['answer'] as String? ?? '';
    final difficulty = card['difficulty'] as String? ?? '';

    final diffColor = difficulty == 'facile'
        ? const Color(0xFF10B981) : difficulty == 'difficile' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final isLast = cardIndex == cards.length - 1;

    return Column(children: [
      // ── Barre de progression segmentée ────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
        child: Row(children: List.generate(cards.length, (i) {
          final active = i <= cardIndex;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 5,
              margin: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 4),
              decoration: BoxDecoration(
                color: active ? _kV : _kV.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          );
        })),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(children: [
            Icon(Icons.style_rounded, size: 15, color: _kV.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text('Carte ${cardIndex + 1} sur ${cards.length}',
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w700)),
          ]),
          if (difficulty.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: diffColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(difficulty[0].toUpperCase() + difficulty.substring(1),
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, fontWeight: FontWeight.w800, color: diffColor)),
            ),
        ]),
      ),

      // ── Carte 3D avec retournement ────────────────────────────
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
          child: _FlipCard(
            key: ValueKey(cardIndex),
            flipped: flipped,
            onTap: () { HapticFeedback.selectionClick(); onFlip(); },
            front: _CardFace(
              badge: 'QUESTION',
              badgeIcon: Icons.help_outline_rounded,
              badgeColor: _kV,
              text: question,
              textColor: AppColors.navy,
              dark: false,
              hint: 'Touche la carte pour révéler la réponse',
            ),
            back: _CardFace(
              badge: 'RÉPONSE',
              badgeIcon: Icons.lightbulb_rounded,
              badgeColor: _kG,
              text: answer,
              textColor: Colors.white,
              dark: true,
              hint: 'Touche pour revoir la question',
            ),
          ),
        ),
      ),

      // ── Navigation ────────────────────────────────────────────
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: Row(children: [
          _NavCircleButton(
            icon: Icons.arrow_back_rounded,
            enabled: cardIndex > 0,
            onTap: () { HapticFeedback.lightImpact(); onPrev(); },
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); onFlip(); },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: _kV.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kV.withValues(alpha: 0.18)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.flip_rounded, size: 17, color: _kV),
                  const SizedBox(width: 8),
                  Text('Retourner', style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5, fontWeight: FontWeight.w800, color: _kV)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 14),
          isLast
              ? _NavCircleButton(
                  icon: Icons.refresh_rounded,
                  enabled: true,
                  filled: true,
                  onTap: () { HapticFeedback.mediumImpact(); onGenerate(); },
                )
              : _NavCircleButton(
                  icon: Icons.arrow_forward_rounded,
                  enabled: true,
                  filled: true,
                  onTap: () { HapticFeedback.lightImpact(); onNext(); },
                ),
        ]),
      ),
    ]);
  }
}

// ── Bouton rond de navigation flashcards ──────────────────────
class _NavCircleButton extends StatelessWidget {
  const _NavCircleButton({
    required this.icon, required this.enabled, required this.onTap, this.filled = false,
  });
  final IconData icon;
  final bool enabled, filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: !enabled
              ? Colors.grey.shade100
              : filled ? _kV : Colors.white,
          shape: BoxShape.circle,
          border: filled || !enabled ? null : Border.all(color: _kV.withValues(alpha: 0.3)),
          boxShadow: filled && enabled
              ? [BoxShadow(color: _kV.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))]
              : null,
        ),
        child: Icon(icon, size: 20,
            color: !enabled ? Colors.grey.shade300 : filled ? Colors.white : _kV),
      ),
    );
  }
}

// ── Face d'une flashcard ──────────────────────────────────────
class _CardFace extends StatelessWidget {
  const _CardFace({
    required this.badge, required this.badgeIcon, required this.badgeColor,
    required this.text, required this.textColor, required this.dark, required this.hint,
  });
  final String badge, text, hint;
  final IconData badgeIcon;
  final Color badgeColor, textColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: dark
            ? const LinearGradient(colors: [Color(0xFF2D1B69), _kVD, _kV],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(colors: [Colors.white, Color(0xFFFBFAFF)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(26),
        border: dark ? null : Border.all(color: _kV.withValues(alpha: 0.10)),
        boxShadow: [BoxShadow(
            color: (dark ? _kV : Colors.black).withValues(alpha: dark ? 0.35 : 0.07),
            blurRadius: 28, offset: const Offset(0, 12))],
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: dark ? Colors.white.withValues(alpha: 0.14) : badgeColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(badgeIcon, size: 15, color: dark ? _kG : badgeColor),
            const SizedBox(width: 6),
            Text(badge, style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5, fontWeight: FontWeight.w900,
                letterSpacing: 1, color: dark ? Colors.white : badgeColor)),
          ]),
        ),
        const Spacer(),
        // Texte
        Flexible(
          flex: 6,
          child: Center(
            child: SingleChildScrollView(
              child: Text(text, textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 17, height: 1.5, fontWeight: FontWeight.w700, color: textColor)),
            ),
          ),
        ),
        const Spacer(),
        // Hint
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.touch_app_rounded, size: 13,
              color: dark ? Colors.white38 : Colors.grey.shade400),
          const SizedBox(width: 5),
          Text(hint, style: GoogleFonts.plusJakartaSans(
              fontSize: 10.5, color: dark ? Colors.white38 : Colors.grey.shade400)),
        ]),
      ]),
    );
  }
}

// ── Carte à retournement 3D (rotation Y avec perspective) ──────
class _FlipCard extends StatefulWidget {
  const _FlipCard({
    super.key, required this.flipped, required this.front, required this.back, required this.onTap,
  });
  final bool flipped;
  final Widget front, back;
  final VoidCallback onTap;

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    if (widget.flipped) _ctrl.value = 1;
  }

  @override
  void didUpdateWidget(_FlipCard old) {
    super.didUpdateWidget(old);
    if (widget.flipped != old.flipped) {
      widget.flipped ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final angle = _anim.value * math.pi; // 0 → π
          final showBack = _anim.value > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012) // perspective
              ..rotateY(angle),
            child: showBack
                // Contre-rotation pour que le dos ne soit pas en miroir
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: widget.back,
                  )
                : widget.front,
          );
        },
      ),
    );
  }
}

// ── Exercise tab ─────────────────────────────────────────────
class _ExerciceTab extends StatelessWidget {
  const _ExerciceTab({required this.questions, required this.loading, required this.answers,
      required this.onGenerate, required this.onAnswer});
  final List<dynamic> questions;
  final bool loading;
  final Map<int, String> answers;
  final Future<void> Function(String) onGenerate;
  final void Function(int, String) onAnswer;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: _kV));

    if (questions.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.quiz_rounded, size: 48, color: _kV),
          const SizedBox(height: 12),
          Text('Exercice IA', style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 6),
          Text('Choisis un niveau de difficulté :',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final diff in ['facile', 'moyen', 'difficile'])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ElevatedButton(
                  onPressed: () => onGenerate(diff),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: diff == 'facile' ? Colors.green : diff == 'difficile' ? Colors.red : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(diff, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ),
          ]),
        ]),
      );
    }

    final done = answers.length == questions.length;
    int score = 0;
    if (done) {
      for (int i = 0; i < questions.length; i++) {
        final q = questions[i] as Map<String, dynamic>;
        if (answers[i] == q['correct']) score++;
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        if (done) Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kVD, _kV]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.emoji_events_rounded, color: _kG, size: 28),
            const SizedBox(width: 10),
            Text('Score : $score / ${questions.length}', style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          ]),
        ),
        ...List.generate(questions.length, (qi) {
          final q        = questions[qi] as Map<String, dynamic>;
          final qText    = q['question'] as String? ?? '';
          final options  = (q['options'] as List<dynamic>?) ?? [];
          final correct  = q['correct'] as String? ?? '';
          final expl     = q['explanation'] as String? ?? '';
          final selected = answers[qi];

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Q${qi + 1}. $qText', style: GoogleFonts.plusJakartaSans(
                  fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.navy, height: 1.4)),
              const SizedBox(height: 12),
              ...options.asMap().entries.map((entry) {
                final optStr = entry.value.toString();
                // Lettre déterminée par la POSITION (robuste même si l'IA
                // oublie les préfixes A) B) C) dans le texte des options)
                final letter = String.fromCharCode(65 + entry.key); // A, B, C…
                final isSelected = selected == letter;
                final isCorrect = correct.isNotEmpty && correct[0].toUpperCase() == letter;
                final showResult = selected != null;

                Color borderColor = Colors.grey.shade200;
                Color bgColor = Colors.grey.shade50;
                if (showResult) {
                  if (isCorrect) { borderColor = Colors.green; bgColor = Colors.green.shade50; }
                  else if (isSelected) { borderColor = Colors.red; bgColor = Colors.red.shade50; }
                }

                // Texte sans le préfixe « A) » éventuel
                final display = optStr.replaceFirst(RegExp(r'^[A-Fa-f][\)\.\:\-]\s*'), '');

                return GestureDetector(
                  onTap: selected == null
                      ? () {
                          HapticFeedback.selectionClick();
                          onAnswer(qi, letter);
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: borderColor,
                          width: showResult && (isCorrect || isSelected) ? 1.6 : 1),
                    ),
                    child: Row(children: [
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: showResult && isCorrect
                              ? Colors.green
                              : showResult && isSelected
                                  ? Colors.red
                                  : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: showResult && (isCorrect || isSelected)
                                  ? Colors.transparent
                                  : Colors.grey.shade300),
                        ),
                        child: Center(
                          child: showResult && (isCorrect || isSelected)
                              ? Icon(isCorrect ? Icons.check : Icons.close, color: Colors.white, size: 14)
                              : Text(letter, style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(display,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: showResult && isCorrect ? FontWeight.w700 : FontWeight.w500,
                              color: AppColors.textPrimary, height: 1.35))),
                    ]),
                  ),
                );
              }),
              if (selected != null && expl.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: _kV),
                    const SizedBox(width: 8),
                    Expanded(child: Text(expl, style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: _kV, height: 1.4))),
                  ]),
                ),
              ],
            ]),
          );
        }),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════
// BOUTON TÉLÉCHARGEMENT HORS-LIGNE (PDF + vidéos du cours)
// ════════════════════════════════════════════════════════════
class _DownloadButton extends StatefulWidget {
  const _DownloadButton({required this.course, required this.token});
  final CourseDetail course;
  final String token;

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _downloaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    DownloadService.isCourseDownloaded(widget.course.id).then((v) {
      if (mounted) setState(() => _downloaded = v);
    });
  }

  Future<void> _onTap() async {
    if (_busy) return;
    HapticFeedback.lightImpact();

    if (_downloaded) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Supprimer le téléchargement ?',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
          content: Text('Les fichiers de ce cours ne seront plus disponibles hors-ligne.',
              style: GoogleFonts.plusJakartaSans(fontSize: 13)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer')),
          ],
        ),
      );
      if (confirm != true) return;
      await DownloadService.deleteCourse(widget.course.id);
      if (mounted) setState(() => _downloaded = false);
      return;
    }

    final urls = DownloadService.downloadableUrls(widget.course);
    if (urls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Aucun fichier téléchargeable dans ce cours.',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
      ));
      return;
    }

    setState(() => _busy = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.navy,
      content: Text('Téléchargement de ${urls.length} fichier(s)… Reste sur cette page.',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
    ));

    final done = await DownloadService.downloadCourse(widget.course, widget.token);

    if (!mounted) return;
    setState(() { _busy = false; _downloaded = done > 0; });
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: done > 0 ? const Color(0xFF059669) : Colors.red.shade600,
      content: Text(
          done > 0
              ? '✓ $done fichier(s) disponibles hors-ligne !'
              : 'Échec du téléchargement. Vérifie ta connexion.',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return ValueListenableBuilder<Map<int, double>>(
        valueListenable: DownloadService.progress,
        builder: (_, map, __) {
          final p = map[widget.course.id];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    value: p, color: Colors.white, strokeWidth: 2.2),
              ),
            ),
          );
        },
      );
    }
    return IconButton(
      tooltip: _downloaded ? 'Disponible hors-ligne' : 'Télécharger pour le hors-ligne',
      icon: Icon(
        _downloaded ? Icons.download_done_rounded : Icons.download_rounded,
        color: _downloaded ? const Color(0xFF34D399) : Colors.white,
      ),
      onPressed: _onTap,
    );
  }
}
