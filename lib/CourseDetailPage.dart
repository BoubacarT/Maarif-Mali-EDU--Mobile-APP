import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:maarif_learn/config/api_config.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/course_service.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  String? _token;
  bool _compactHeader = false;

  final Map<int, WebViewController> _webControllersByCourseId = {};
  final Map<int, WebViewController> _webControllersByExerciseId = {};
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
        });
      }
    } on CourseException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF00BCD4),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("Chargement...", style: TextStyle(fontSize: 15)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF00BCD4)),
        ),
      );
    }
    if (_error != null || _course == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFF00BCD4),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BCD4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          course.subject.name,
          style: const TextStyle(fontSize: 15),
        ),
      ),
      body: Column(
        children: [
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
                        color: const Color(0xFF00BCD4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              "Cours • ${course.videos.length} vidéo(s) • ${course.exercises.length} exercice(s)",
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      TabBar(
                        controller: _tabController,
                        labelColor: const Color(0xFF00BCD4),
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF00BCD4),
                        tabs: const [
                          Tab(icon: Icon(Icons.book), text: "Cours"),
                          Tab(icon: Icon(Icons.play_circle), text: "Vidéos"),
                          Tab(icon: Icon(Icons.description), text: "Exercices"),
                          Tab(icon: Icon(Icons.quiz), text: "Quiz"),
                        ],
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

    final controller = _webControllersByCourseId.putIfAbsent(course.id, () {
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              return NavigationDecision.navigate;
            },
          ),
        );
      c.loadRequest(
        fileUri,
        headers: _buildWebHeaders(),
      );
      return c;
    });

    return Column(
      children: [
        if (hasDescription)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Description",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  course.description!,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Support du cours",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          )
        else
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Support du cours",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        Expanded(
          child: WebViewWidget(controller: controller),
        ),
      ],
    );
  }

  Uri? _resolveCourseFileUri(String rawUrl) {
    final parsed = Uri.tryParse(rawUrl);
    if (parsed == null) return null;
    if (parsed.hasScheme) return parsed;

    final normalizedPath = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    return Uri.tryParse('${ApiConfig.baseUrl}$normalizedPath');
  }

  Map<String, String> _buildWebHeaders() {
    final headers = <String, String>{
      'Accept': '*/*',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEFCF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4DECC)),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFD6E6FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Solution",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          _buildReadingTextBlock(solution),
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 70, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              "Aucune vidéo pour ce cours.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final v = videos[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF00BCD4),
              child: Icon(Icons.play_arrow, color: Colors.white),
            ),
            title: Text(v.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (v.duration != null) Text(v.duration!, style: const TextStyle(fontSize: 12)),
                if (v.description != null && v.description!.isNotEmpty)
                  Text(
                    v.description!,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (_resolveVideoUri(v) != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: () => _openVideoInApp(v),
                      child: const Text(
                        "Voir la vidéo",
                        style: TextStyle(
                          color: Color(0xFF00BCD4),
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                if (_resolveVideoUri(v) == null)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      "Source vidéo indisponible.",
                      style: TextStyle(fontSize: 12, color: Colors.redAccent),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExercicesContent(List<ExerciseItem> exercises) {
    if (exercises.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment, size: 70, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              "Aucun exercice pour ce cours.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        _maybeToggleCompactHeader(notification, 2);
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: exercises.length,
        itemBuilder: (context, index) {
          final e = exercises[index];
          final exerciseTitle = _exerciseDisplayTitle(e, index);
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              title: Text(
                exerciseTitle,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              subtitle: e.difficulty != null
                  ? Text(e.difficulty!, style: const TextStyle(fontSize: 12))
                  : null,
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
        return const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            "Le fichier de l'exercice est invalide.",
            style: TextStyle(color: Colors.grey),
          ),
        );
      }
      final controller = _webControllersByExerciseId.putIfAbsent(e.id, () {
        final c = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onNavigationRequest: (_) => NavigationDecision.navigate,
            ),
          );
        c.loadRequest(fileUri, headers: _buildWebHeaders());
        return c;
      });
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Support de l'exercice",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 420,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: WebViewWidget(controller: controller),
              ),
            ),
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
      return Padding(
        padding: const EdgeInsets.all(12),
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

    return const Padding(
      padding: EdgeInsets.all(12),
      child: Text(
        "Aucun détail supplémentaire pour cet exercice.",
        style: TextStyle(color: Colors.grey, fontSize: 13),
      ),
    );
  }

  Widget _buildQuizContent(QuizDetail? quiz) {
    if (quiz == null || quiz.questions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_outlined, size: 70, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              "Aucun quiz pour ce cours.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quiz.questions.length,
      itemBuilder: (context, index) {
        final q = quiz.questions[index];
        final selectedOptionId = _selectedOptionByQuestionId[q.id];
        final bool answered = selectedOptionId != null;

        final correctOptionId = q.options
            .where((o) => o.isCorrect)
            .map((o) => o.id)
            .cast<int?>()
            .firstWhere((id) => id != null, orElse: () => null);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Q${index + 1}. ${q.text}",
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ...q.options.map((opt) {
                  final isSelected = selectedOptionId == opt.id;
                  final isCorrect = opt.isCorrect;

                  Color? bg;
                  Color border = Colors.grey.shade300;
                  Color textColor = Colors.black87;

                  if (answered) {
                    if (isSelected && isCorrect) {
                      bg = Colors.green.shade50;
                      border = Colors.green;
                      textColor = Colors.green.shade800;
                    } else if (isSelected && !isCorrect) {
                      bg = Colors.red.shade50;
                      border = Colors.red;
                      textColor = Colors.red.shade800;
                    } else if (!isSelected &&
                        isCorrect &&
                        correctOptionId == opt.id) {
                      bg = Colors.green.shade50;
                      border = Colors.green.shade300;
                      textColor = Colors.green.shade800;
                    }
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: bg ?? Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border, width: 1.2),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: answered
                          ? null
                          : () {
                              setState(() {
                                _selectedOptionByQuestionId[q.id] = opt.id;
                              });
                            },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              answered
                                  ? (isSelected
                                      ? (isCorrect
                                          ? Icons.check_circle
                                          : Icons.cancel)
                                      : (isCorrect && correctOptionId == opt.id
                                          ? Icons.check_circle_outline
                                          : Icons.radio_button_unchecked))
                                  : Icons.radio_button_unchecked,
                              size: 18,
                              color: answered
                                  ? (isSelected
                                      ? (isCorrect ? Colors.green : Colors.red)
                                      : (isCorrect && correctOptionId == opt.id
                                          ? Colors.green.shade400
                                          : Colors.grey))
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                opt.text,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: textColor,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Uri? _resolveVideoUri(VideoItem video) {
    final candidates = <String?>[
      video.embedUrl,
      video.videoUrl,
      video.videoFileUrl,
    ];
    for (final raw in candidates) {
      if (raw == null || raw.trim().isEmpty) continue;
      final parsed = Uri.tryParse(raw.trim());
      if (parsed == null) continue;
      if (parsed.hasScheme) return parsed;
      final normalizedPath = raw.startsWith('/') ? raw : '/$raw';
      final baseOrigins = _candidateBaseOrigins();
      for (final origin in baseOrigins) {
        final absolute = Uri.tryParse('$origin$normalizedPath');
        if (absolute != null) return absolute;
      }
    }
    return null;
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

    if (_isDirectVideoFile(uri)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _VideoPlayerPage(
            title: video.title,
            uri: uri,
            headers: _buildWebHeaders(),
          ),
        ),
      );
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
        headers: _buildWebHeaders(),
      );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF00BCD4),
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

  bool _isDirectVideoFile(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.m3u8') ||
        path.endsWith('.mov') ||
        path.endsWith('.webm') ||
        path.endsWith('.mkv');
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

  const _VideoPlayerPage({
    required this.title,
    required this.uri,
    required this.headers,
  });

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  VideoPlayerController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        widget.uri,
        httpHeaders: widget.headers,
      );
      await controller.initialize();
      await controller.setLooping(false);
      await controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Impossible de lire la vidéo.";
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF00BCD4),
        title: Text(widget.title, style: const TextStyle(fontSize: 15)),
      ),
      body: Center(
        child: _error != null
            ? Text(
                _error!,
                style: const TextStyle(color: Colors.white70),
              )
            : (controller == null || !controller.value.isInitialized)
                ? const CircularProgressIndicator(color: Colors.white)
                : AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(child: VideoPlayer(controller)),
                        VideoProgressIndicator(
                          controller,
                          allowScrubbing: true,
                          colors: VideoProgressColors(
                            playedColor: const Color(0xFF00BCD4),
                            bufferedColor: Colors.white38,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                        IconButton(
                          iconSize: 38,
                          color: Colors.white,
                          onPressed: () {
                            if (controller.value.isPlaying) {
                              controller.pause();
                            } else {
                              controller.play();
                            }
                            setState(() {});
                          },
                          icon: Icon(
                            controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
