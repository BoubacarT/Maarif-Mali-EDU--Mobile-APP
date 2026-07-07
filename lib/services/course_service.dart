import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class CourseService {
  /// Liste des matières pour l'étudiant (selon son niveau)
  static Future<List<SubjectItem>> getSubjects(String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.subjectsUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? [];
      return data.map((e) => SubjectItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    if (response.statusCode == 401) {
      throw CourseException('Session expirée. Reconnectez-vous.', 401);
    }
    if (response.statusCode == 403) {
      throw CourseException('Accès non autorisé.', 403);
    }
    final body = response.body;
    String message = 'Impossible de charger les matières';
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      message = j['message'] as String? ?? message;
    } catch (_) {}
    throw CourseException(message, response.statusCode);
  }

  /// Liste des cours d'une matière pour l'étudiant connecté
  static Future<CoursesBySubjectResponse> getCoursesBySubject(int subjectId, String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.subjectCoursesUrl(subjectId)),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? [];
      final subject = json['subject'] as Map<String, dynamic>?;
      final courses = data.map((e) => CourseItem.fromJson(e as Map<String, dynamic>)).toList();
      SubjectRef? subjectRef;
      if (subject != null) {
        subjectRef = SubjectRef(id: subject['id'] as int, name: subject['name'] as String);
      }
      return CoursesBySubjectResponse(courses: courses, subject: subjectRef);
    }
    if (response.statusCode == 404) {
      final j = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic>? : null;
      throw CourseException(j?['message'] as String? ?? 'Matière non trouvée.', 404);
    }
    if (response.statusCode == 401) {
      throw CourseException('Session expirée. Reconnectez-vous.', 401);
    }
    if (response.statusCode == 403) {
      throw CourseException('Accès non autorisé.', 403);
    }
    final body = response.body;
    String message = 'Impossible de charger les cours';
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      message = j['message'] as String? ?? message;
    } catch (_) {}
    throw CourseException(message, response.statusCode);
  }

  /// Détail d'un cours (vidéos, exercices, quiz) avec Bearer token
  static Future<CourseDetail> getCourseDetail(int courseId, String token) async {
    final response = await http.get(
      Uri.parse(ApiConfig.courseUrl(courseId)),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return CourseDetail.fromJson(json);
    }
    if (response.statusCode == 401) {
      throw CourseException('Session expirée. Reconnectez-vous.', 401);
    }
    if (response.statusCode == 403 || response.statusCode == 404) {
      final j = response.body.isNotEmpty ? jsonDecode(response.body) as Map<String, dynamic>? : null;
      throw CourseException(j?['message'] as String? ?? 'Cours non trouvé.', response.statusCode);
    }
    throw CourseException('Impossible de charger le cours.', response.statusCode);
  }
}

class CourseException implements Exception {
  final String message;
  final int? statusCode;
  CourseException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class SubjectItem {
  final int id;
  final String name;
  final String color;
  final int coursesCount;

  SubjectItem({
    required this.id,
    required this.name,
    this.color = '#00ADBB',
    required this.coursesCount,
  });

  static SubjectItem fromJson(Map<String, dynamic> json) => SubjectItem(
        id: json['id'] as int,
        name: json['name'] as String,
        color: json['color'] as String? ?? '#00ADBB',
        coursesCount: json['courses_count'] as int? ?? 0,
      );
}

class CoursesBySubjectResponse {
  final List<CourseItem> courses;
  final SubjectRef? subject;

  CoursesBySubjectResponse({required this.courses, this.subject});
}

class CourseItem {
  final int id;
  final String title;
  final String? description;
  final SubjectRef subject;
  final List<LevelRef> levels;
  final int videosCount;
  final int exercisesCount;
  final String? contentFileUrl;

  CourseItem({
    required this.id,
    required this.title,
    this.description,
    required this.subject,
    required this.levels,
    required this.videosCount,
    required this.exercisesCount,
    this.contentFileUrl,
  });

  static CourseItem fromJson(Map<String, dynamic> json) {
    return CourseItem(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      subject: SubjectRef.fromJson(json['subject'] as Map<String, dynamic>),
      levels: (json['levels'] as List<dynamic>?)
              ?.map((e) => LevelRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      videosCount: json['videos_count'] as int? ?? 0,
      exercisesCount: json['exercises_count'] as int? ?? 0,
      contentFileUrl: json['content_file_url'] as String?,
    );
  }
}

class SubjectRef {
  final int id;
  final String name;
  SubjectRef({required this.id, required this.name});
  static SubjectRef fromJson(Map<String, dynamic> json) =>
      SubjectRef(id: json['id'] as int, name: json['name'] as String);
}

class LevelRef {
  final int id;
  final String name;
  LevelRef({required this.id, required this.name});
  static LevelRef fromJson(Map<String, dynamic> json) =>
      LevelRef(id: json['id'] as int, name: json['name'] as String);
}

class CourseDetail {
  final int id;
  final String title;
  final String? description;
  final SubjectRef subject;
  final List<LevelRef> levels;
  final String? contentFileUrl;
  final String? contentFileName;
  final String? contentFileKind;
  final String? contentFileMimeType;
  final String? contentFileExtension;
  final bool contentFileIsPreviewable;
  final String? documentContentStatus;
  final String? documentContentError;
  final String? documentContentText;
  final List<String> documentContentBlocks;
  final List<VideoItem> videos;
  final List<ExerciseItem> exercises;
  final QuizDetail? quiz;

  CourseDetail({
    required this.id,
    required this.title,
    this.description,
    required this.subject,
    required this.levels,
    this.contentFileUrl,
    this.contentFileName,
    this.contentFileKind,
    this.contentFileMimeType,
    this.contentFileExtension,
    this.contentFileIsPreviewable = false,
    this.documentContentStatus,
    this.documentContentError,
    this.documentContentText,
    this.documentContentBlocks = const [],
    required this.videos,
    required this.exercises,
    this.quiz,
  });

  static CourseDetail fromJson(Map<String, dynamic> json) {
    return CourseDetail(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      subject: SubjectRef.fromJson(json['subject'] as Map<String, dynamic>),
      levels: (json['levels'] as List<dynamic>?)
              ?.map((e) => LevelRef.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      contentFileUrl: json['content_file_url'] as String?,
      contentFileName: json['content_file_name'] as String?,
      contentFileKind: json['content_file_kind'] as String?,
      contentFileMimeType: json['content_file_mime_type'] as String?,
      contentFileExtension: json['content_file_extension'] as String?,
      contentFileIsPreviewable: json['content_file_is_previewable'] as bool? ?? false,
      documentContentStatus: json['document_content_status'] as String?,
      documentContentError: json['document_content_error'] as String?,
      documentContentText: json['document_content_text'] as String?,
      documentContentBlocks: (json['document_content_blocks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      videos: (json['videos'] as List<dynamic>?)
              ?.map((e) => VideoItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((e) => ExerciseItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      quiz: json['quiz'] != null
          ? QuizDetail.fromJson(json['quiz'] as Map<String, dynamic>)
          : null,
    );
  }
}

class VideoItem {
  final int id;
  final String title;
  final String? duration;
  final String? description;
  final String? videoFileUrl;
  final String? videoUrl;
  final String? embedUrl;

  VideoItem({
    required this.id,
    required this.title,
    this.duration,
    this.description,
    this.videoFileUrl,
    this.videoUrl,
    this.embedUrl,
  });

  static VideoItem fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'];
    final dynamic rawDuration = json['duration'];
    final String? durationValue = rawDuration == null ? null : rawDuration.toString();

    return VideoItem(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0,
      title: (json['title'] as String?) ?? 'Vidéo',
      duration: durationValue,
      description: json['description'] as String?,
      videoFileUrl: (json['video_file_url'] as String?) ?? (json['file_url'] as String?),
      videoUrl: (json['video_url'] as String?) ?? (json['url'] as String?),
      embedUrl: json['embed_url'] as String?,
    );
  }
}

class ExerciseItem {
  final int id;
  final String question;
  final String? solution;
  final String? difficulty;
  final String? contentFileUrl;
  final String? contentFileName;
  final String? documentContentStatus;
  final String? documentContentError;
  final String? documentContentText;
  final List<String> documentContentBlocks;

  ExerciseItem({
    required this.id,
    required this.question,
    this.solution,
    this.difficulty,
    this.contentFileUrl,
    this.contentFileName,
    this.documentContentStatus,
    this.documentContentError,
    this.documentContentText,
    this.documentContentBlocks = const [],
  });

  static ExerciseItem fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'];
    final rawQuestion = (json['question'] as String?) ?? (json['title'] as String?);
    final trimmed = rawQuestion?.trim();
    final fileName = json['content_file_name'] as String?;
    final question = (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : ((fileName != null && fileName.trim().isNotEmpty) ? fileName.trim() : 'Exercice');

    return ExerciseItem(
      id: rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0,
      question: question,
      solution: json['solution'] as String?,
      difficulty: json['difficulty'] as String?,
      contentFileUrl: json['content_file_url'] as String?,
      contentFileName: fileName,
      documentContentStatus: json['document_content_status'] as String?,
      documentContentError: json['document_content_error'] as String?,
      documentContentText: json['document_content_text'] as String?,
      documentContentBlocks: (json['document_content_blocks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class QuizDetail {
  final int id;
  final String title;
  final List<QuizQuestion> questions;

  QuizDetail({required this.id, required this.title, required this.questions});

  static QuizDetail fromJson(Map<String, dynamic> json) => QuizDetail(
        id: json['id'] as int,
        title: json['title'] as String? ?? 'Quiz',
        questions: (json['questions'] as List<dynamic>?)
                ?.map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class QuizQuestion {
  final int id;
  final String text;
  final List<QuizOption> options;

  QuizQuestion({required this.id, required this.text, required this.options});

  static QuizQuestion fromJson(Map<String, dynamic> json) => QuizQuestion(
        id: json['id'] as int,
        text: json['text'] as String,
        options: (json['options'] as List<dynamic>?)
                ?.map((e) => QuizOption.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class QuizOption {
  final int id;
  final String text;
  final bool isCorrect;

  QuizOption({required this.id, required this.text, required this.isCorrect});

  static QuizOption fromJson(Map<String, dynamic> json) => QuizOption(
        id: json['id'] as int,
        text: (json['text'] as String?) ?? (json['option_text'] as String?) ?? '',
        isCorrect: json['is_correct'] as bool? ?? false,
      );
}
