import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Rappel quotidien de révision — notification locale planifiée,
/// fonctionne même sans connexion internet.
class ReminderService {
  static const _enabledKey = 'maarif_reminder_enabled';
  static const _hourKey = 'maarif_reminder_hour';
  static const _minuteKey = 'maarif_reminder_minute';
  static const _notifId = 1001;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      // Les Écoles Maarif du Mali : fuseau de Bamako (GMT, sans heure d'été)
      tz.setLocalLocation(tz.getLocation('Africa/Bamako'));

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );
      _ready = true;

      // Re-planifie au démarrage (les alarmes sautent après un redémarrage du téléphone)
      if (await isEnabled()) {
        final t = await time();
        await _schedule(t.$1, t.$2);
      }
    } catch (_) {}
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// (heure, minute) du rappel — 18h00 par défaut.
  static Future<(int, int)> time() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt(_hourKey) ?? 18, prefs.getInt(_minuteKey) ?? 0);
  }

  /// Active le rappel quotidien à l'heure donnée. Retourne false si refusé.
  static Future<bool> enable(int hour, int minute) async {
    if (!_ready) return false;
    try {
      // Permission notifications (Android 13+ / iOS)
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted == false) return false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
        if (granted == false) return false;
      }

      await _schedule(hour, minute);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, true);
      await prefs.setInt(_hourKey, hour);
      await prefs.setInt(_minuteKey, minute);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disable() async {
    try {
      await _plugin.cancel(_notifId);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, false);
  }

  static Future<void> _schedule(int hour, int minute) async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (next.isBefore(now)) next = next.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      _notifId,
      '📖 C\'est l\'heure de réviser !',
      'Ouvre MaarifMaliEdu et continue ta préparation. MAARIFA t\'attend ✦',
      next,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'revision_reminder',
          'Rappels de révision',
          channelDescription: 'Rappel quotidien pour réviser tes cours',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // répète chaque jour
    );
  }
}
