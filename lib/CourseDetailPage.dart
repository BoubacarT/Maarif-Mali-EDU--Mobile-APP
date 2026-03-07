import 'package:flutter/material.dart';
import 'package:maarif_learn/services/auth_storage.dart';
import 'package:maarif_learn/services/course_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
      if (mounted) setState(() { _course = course; _loading = false; _error = null; });
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (course.description != null && course.description!.isNotEmpty) ...[
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
          if (course.contentFileUrl != null) ...[
            const Text(
              "Support du cours",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _openUrl(course.contentFileUrl!),
              child: Row(
                children: const [
                  Icon(Icons.picture_as_pdf, color: Color(0xFF00BCD4)),
                  SizedBox(width: 8),
                  Text(
                    "Télécharger / ouvrir le fichier du cours",
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF00BCD4),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if ((course.description == null || course.description!.isEmpty) &&
              course.contentFileUrl == null)
            const Text(
              "Aucun contenu supplémentaire pour ce cours.",
              style: TextStyle(color: Colors.grey),
            ),
        ],
      ),
    );
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
                if (v.videoFileUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: () => _openUrl(v.videoFileUrl!),
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
