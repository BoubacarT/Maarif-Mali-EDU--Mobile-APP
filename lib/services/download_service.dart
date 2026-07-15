import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'course_service.dart';

/// Téléchargement hors-ligne des fichiers d'un cours (PDF + vidéos directes).
///
/// Les fichiers sont stockés dans le dossier documents de l'app
/// (`maarif_downloads/course_<id>/`) et un manifeste (SharedPreferences)
/// associe chaque URL à son fichier local. Les lecteurs PDF/vidéo consultent
/// [localFile] avant d'aller sur le réseau.
class DownloadService {
  static const _manifestKey = 'maarif_downloads_manifest';

  /// courseId → progression 0..1 pendant un téléchargement (écouté par l'UI).
  static final ValueNotifier<Map<int, double>> progress = ValueNotifier({});

  // ── Manifeste {courseId: {'title': ..., 'files': {url: relPath}, 'bytes': int}} ──
  static Future<Map<String, dynamic>> _manifest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_manifestKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveManifest(Map<String, dynamic> m) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_manifestKey, jsonEncode(m));
  }

  static Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/maarif_downloads');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Fichiers téléchargeables d'un cours : PDF du cours, PDF des exercices,
  /// vidéos hébergées en fichier direct (pas YouTube/embed).
  static List<String> downloadableUrls(CourseDetail course) {
    final urls = <String>[];
    void add(String? u) {
      if (u == null) return;
      final t = u.trim();
      if (t.isEmpty || urls.contains(t)) return;
      final lower = t.toLowerCase();
      if (lower.contains('youtube.com') || lower.contains('youtu.be') || lower.contains('/embed')) return;
      urls.add(t);
    }

    add(course.contentFileUrl);
    for (final e in course.exercises) {
      add(e.contentFileUrl);
    }
    for (final v in course.videos) {
      final direct = v.videoFileUrl ?? v.videoUrl;
      if (direct != null) {
        final lower = direct.toLowerCase();
        if (lower.endsWith('.mp4') || lower.endsWith('.webm') || lower.endsWith('.mov') || lower.contains('/storage/')) {
          add(direct);
        }
      }
    }
    return urls;
  }

  static Future<bool> isCourseDownloaded(int courseId) async {
    final m = await _manifest();
    return m.containsKey('$courseId');
  }

  /// Chemin local d'une URL si elle a été téléchargée (n'importe quel cours).
  static Future<File?> localFile(String url) async {
    final m = await _manifest();
    final root = await _root();
    for (final entry in m.values) {
      final files = Map<String, dynamic>.from((entry as Map)['files'] as Map? ?? {});
      final rel = files[url.trim()];
      if (rel != null) {
        final f = File('${root.path}/$rel');
        if (f.existsSync()) return f;
      }
    }
    return null;
  }

  /// Télécharge tous les fichiers du cours. Retourne le nombre de fichiers OK.
  static Future<int> downloadCourse(CourseDetail course, String token) async {
    final urls = downloadableUrls(course);
    if (urls.isEmpty) return 0;

    final root = await _root();
    final courseDir = Directory('${root.path}/course_${course.id}');
    if (!courseDir.existsSync()) courseDir.createSync(recursive: true);

    final files = <String, String>{};
    var bytes = 0;
    var done = 0;

    for (var i = 0; i < urls.length; i++) {
      _setProgress(course.id, i / urls.length);
      try {
        final res = await http.get(
          Uri.parse(urls[i]),
          headers: {'Authorization': 'Bearer $token', 'Accept': '*/*'},
        ).timeout(const Duration(minutes: 5));
        if (res.statusCode != 200 || res.bodyBytes.isEmpty) continue;

        final name = _fileName(urls[i], i);
        final file = File('${courseDir.path}/$name');
        await file.writeAsBytes(res.bodyBytes, flush: true);
        files[urls[i]] = 'course_${course.id}/$name';
        bytes += res.bodyBytes.length;
        done++;
      } catch (_) {
        // fichier suivant — un échec ne bloque pas le reste
      }
    }

    if (files.isNotEmpty) {
      final m = await _manifest();
      m['${course.id}'] = {'title': course.title, 'files': files, 'bytes': bytes};
      await _saveManifest(m);
    }
    _setProgress(course.id, null);
    return done;
  }

  static Future<void> deleteCourse(int courseId) async {
    final root = await _root();
    final dir = Directory('${root.path}/course_$courseId');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    final m = await _manifest();
    m.remove('$courseId');
    await _saveManifest(m);
  }

  /// (nombre de cours, octets totaux) pour l'écran de gestion du stockage.
  static Future<(int, int)> storageUsed() async {
    final m = await _manifest();
    var bytes = 0;
    for (final e in m.values) {
      bytes += ((e as Map)['bytes'] as num? ?? 0).toInt();
    }
    return (m.length, bytes);
  }

  static Future<void> clearAll() async {
    final root = await _root();
    if (root.existsSync()) root.deleteSync(recursive: true);
    await _saveManifest({});
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} Ko';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} Go';
  }

  static String _fileName(String url, int index) {
    final path = Uri.tryParse(url)?.path ?? '';
    final base = path.split('/').where((s) => s.isNotEmpty).lastOrNull ?? 'fichier_$index';
    // Nom sûr pour le système de fichiers
    return '${index}_${base.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}';
  }

  static void _setProgress(int courseId, double? value) {
    final map = Map<int, double>.from(progress.value);
    if (value == null) {
      map.remove(courseId);
    } else {
      map[courseId] = value;
    }
    progress.value = map;
  }
}
