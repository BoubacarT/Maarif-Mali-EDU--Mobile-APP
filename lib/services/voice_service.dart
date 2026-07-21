import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'auth_storage.dart';

/// MAARIFA vocale : enregistrement micro → transcription Groq Whisper,
/// et lecture des réponses à voix haute (TTS natif, hors-ligne).
class VoiceService {
  static final _recorder = AudioRecorder();
  static final _tts = FlutterTts();
  static bool _ttsReady = false;
  static const _ttsPrefKey = 'maarif_tts_enabled';

  // ── Enregistrement micro ─────────────────────────────────────

  static Future<bool> startRecording() async {
    try {
      if (!await _recorder.hasPermission()) return false;
      final dir = await getTemporaryDirectory();
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 16000),
        path: '${dir.path}/maarifa_question.m4a',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Arrête l'enregistrement et transcrit via le backend. Retourne le texte
  /// reconnu, ou null en cas d'échec.
  static Future<String?> stopAndTranscribe() async {
    try {
      final path = await _recorder.stop();
      if (path == null) return null;

      final token = await AuthStorage.getToken();
      if (token == null) return null;

      final req = http.MultipartRequest('POST', Uri.parse(ApiConfig.url('/ai/transcribe')))
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['Accept'] = 'application/json'
        ..files.add(await http.MultipartFile.fromPath('audio', path));

      final streamed = await req.send().timeout(const Duration(seconds: 45));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode == 200) {
        final text = (jsonDecode(body) as Map<String, dynamic>)['text']?.toString().trim();
        return (text != null && text.isNotEmpty) ? text : null;
      }
      return null;
    } catch (_) {
      try { await _recorder.stop(); } catch (_) {}
      return null;
    }
  }

  static Future<void> cancelRecording() async {
    try { await _recorder.stop(); } catch (_) {}
  }

  // ── Lecture à voix haute ─────────────────────────────────────

  /// true tant qu'une lecture à voix haute est en cours (écoutable par l'UI).
  static final ValueNotifier<bool> speaking = ValueNotifier(false);

  static Future<void> _initTts() async {
    if (_ttsReady) return;
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setSpeechRate(kIsWeb ? 1.0 : 0.5); // 0.5 = vitesse normale sur mobile
      await _tts.setPitch(1.0);
      _tts.setCompletionHandler(() => speaking.value = false);
      _tts.setCancelHandler(() => speaking.value = false);
      _tts.setErrorHandler((_) => speaking.value = false);
      _ttsReady = true;
    } catch (_) {}
  }

  static Future<bool> isTtsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_ttsPrefKey) ?? false;
  }

  static Future<void> setTtsEnabled(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_ttsPrefKey, v);
    if (!v) stop();
  }

  /// Lit un texte à voix haute (nettoyé du markdown et des emojis).
  static Future<void> speak(String text) async {
    await _initTts();
    final clean = text
        .replaceAll(RegExp(r'\*\*|__|`'), '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}✦]', unicode: true), '')
        .trim();
    if (clean.isEmpty) return;
    try {
      await _tts.stop();
      speaking.value = true;
      await _tts.speak(clean);
    } catch (_) {
      speaking.value = false;
    }
  }

  static Future<void> stop() async {
    speaking.value = false;
    try { await _tts.stop(); } catch (_) {}
  }
}
