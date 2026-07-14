import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache local JSON (SharedPreferences) pour le mode hors-ligne.
///
/// Chaque appel réseau réussi sauvegarde sa réponse ; en cas de coupure,
/// l'app ressert la dernière version connue avec son âge.
class CacheService {
  static const _prefix = 'maarif_cache_';

  static Future<void> put(String key, dynamic jsonData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode({
        'at': DateTime.now().toIso8601String(),
        'data': jsonData,
      }));
    } catch (_) {}
  }

  /// Retourne {data, age} ou null si absent.
  static Future<CachedEntry?> get(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return CachedEntry(
        data: decoded['data'],
        savedAt: DateTime.tryParse(decoded['at']?.toString() ?? '') ?? DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await prefs.remove(k);
    }
  }
}

class CachedEntry {
  final dynamic data;
  final DateTime savedAt;
  CachedEntry({required this.data, required this.savedAt});

  String get ageLabel {
    final diff = DateTime.now().difference(savedAt);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return 'il y a ${diff.inDays} j';
  }
}
