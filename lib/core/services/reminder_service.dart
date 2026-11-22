import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service for managing local notification reminders for scheduled therapy sessions.
class ReminderService {
  static final ReminderService _instance = ReminderService._();
  factory ReminderService() => _instance;
  ReminderService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _notificationsEnabled = true;

  bool get notificationsEnabled => _notificationsEnabled;

  /// Sets whether session reminder notifications are enabled.
  void setNotificationsEnabled(bool enabled) {
    _notificationsEnabled = enabled;
  }

  /// Initializes timezone and local notification plugin.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    } catch (e) {
      debugPrint('Failed to configure timezone: $e');
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initSettings,
      );

      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize ReminderService: $e');
    }
  }

  /// Calculates a stable notification integer ID from a session ID string.
  int _notificationId(String sessionId) {
    return sessionId.hashCode.abs() % 100000;
  }

  /// Schedules a reminder notification 30 minutes before the scheduled session.
  /// If the time is already past or notifications are disabled, this is a no-op.
  Future<void> scheduleSessionReminder({
    required String sessionId,
    required String patientName,
    required DateTime sessionDate,
  }) async {
    if (!_notificationsEnabled) return;
    if (!_initialized) {
      await initialize();
    }

    final notifyAt = sessionDate.subtract(const Duration(minutes: 30));
    if (notifyAt.isBefore(DateTime.now())) {
      return;
    }

    final id = _notificationId(sessionId);

    const androidDetails = AndroidNotificationDetails(
      'session_reminders',
      'تذكيرات الجلسات',
      channelDescription: 'إشعارات تذكيرية قبل موعد الجلسة بـ 30 دقيقة',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final scheduledDate = tz.TZDateTime.from(notifyAt, tz.local);

    try {
      // First try exact alarm
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: 'تذكير بموعد جلسة',
        body: 'جلستك مع $patientName بعد 30 دقيقة',
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Exact alarm failed, falling back to inexact: $e');
      try {
        await _notificationsPlugin.zonedSchedule(
          id: id,
          title: 'تذكير بموعد جلسة',
          body: 'جلستك مع $patientName بعد 30 دقيقة',
          scheduledDate: scheduledDate,
          notificationDetails: notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      } catch (e2) {
        debugPrint('Failed to schedule reminder notification: $e2');
      }
    }
  }

  /// Cancels any scheduled reminder for the given session ID.
  Future<void> cancelSessionReminder(String sessionId) async {
    try {
      final id = _notificationId(sessionId);
      await _notificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('Failed to cancel session reminder: $e');
    }
  }

  /// Cancels all scheduled reminder notifications.
  Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel all notifications: $e');
    }
  }
}
