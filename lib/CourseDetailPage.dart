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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
          if (_tabController.index != 0) return false;
          if (notification.direction == ScrollDirection.reverse && !_compactHeader) {
            setState(() => _compactHeader = true);
          } else if (notification.direction == ScrollDirection.forward && _compactHeader) {
            setState(() => _compactHeader = false);
          }
          return false;
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDescription) ...[
                const Text(
                  "Description",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  course.description!,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 20),
              ],
              const Text(
                "Contenu du cours",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SelectableText(
                _normalizeDocumentText(_decodeHtmlEntities(course.documentContentText!)),
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
            ],
          ),
        ),
      );
    }

    if (!hasFile) {
      return NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (_tabController.index != 0) return false;
          if (notification.direction == ScrollDirection.reverse && !_compactHeader) {
            setState(() => _compactHeader = true);
          } else if (notification.direction == ScrollDirection.forward && _compactHeader) {
            setState(() => _compactHeader = false);
          }
          return false;
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasDescription) ...[
                const Text(
                  "Description",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  course.description!,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ],
              if (!hasDescription)
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: exercises.length,
      itemBuilder: (context, index) {
        final e = exercises[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              e.question,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: e.difficulty != null
                ? Text(e.difficulty!, style: const TextStyle(fontSize: 12))
                : null,
            children: [
              if (e.solution != null && e.solution!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Solution",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(e.solution!, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
            ],
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
