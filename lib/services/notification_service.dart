import 'dart:async';

import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Notification channels
// ---------------------------------------------------------------------------
const _kPreClassChannelId = 'pre_class_reminders';
const _kPreClassChannelName = 'Pre-Class Reminders';
const _kPreClassChannelDesc = 'Alerts a few minutes before a class begins';

const _kPostClassChannelId = 'attendance_reminders';
const _kPostClassChannelName = 'Attendance Reminders';
const _kPostClassChannelDesc =
    'Prompts to mark attendance right after a class ends';

const _kAttendanceChannelId = 'attendance_channel';
const _kAttendanceChannelName = 'Attendance Alerts';
const _kAttendanceChannelDesc = 'Alerts when attendance is below threshold';

// How many minutes before the class the pre-class reminder fires
const int _kPreClassOffsetMinutes = 10;

// ---------------------------------------------------------------------------

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

  static const String _prefKey = 'class_reminders_enabled';

  Future<void> init() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _fln.initialize(initSettings);

    // Request FCM / platform permissions for iOS
    await FirebaseMessaging.instance.requestPermission();
  }

  Future<bool> areRemindersEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? true; // Default to enabled
  }

  Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  /// Shows an immediate notification (used for low-attendance alerts etc.)
  Future<void> show({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          _kAttendanceChannelId,
          _kAttendanceChannelName,
          channelDescription: _kAttendanceChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );
    await _fln.show(id, title, body, platformDetails);
  }

  /// Cancels all scheduled notifications
  Future<void> cancelAll() async {
    await _fln.cancelAll();
  }

  /// Cancels a specific notification by ID
  Future<void> cancel(int id) async {
    await _fln.cancel(id);
  }

  /// Returns list of pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _fln.pendingNotificationRequests();
  }

  // ---------------------------------------------------------------------------
  // Per-class dual-reminder scheduling
  // ---------------------------------------------------------------------------

  /// Schedules two weekly repeating notifications for every [ScheduleSlot]
  /// across all subjects:
  ///   1. Pre-class  – fires [_kPreClassOffsetMinutes] min before class starts.
  ///   2. Post-class – fires right after the class ends
  ///                    (50 min for lectures, 100 min for labs).
  Future<void> scheduleClassReminders(List<Subject> subjects) async {
    // Respect user preference
    if (!await areRemindersEnabled()) {
      await cancelAll();
      return;
    }

    // Clear existing to avoid stale / duplicate schedules
    await cancelAll();

    for (final subject in subjects) {
      for (final slot in subject.schedule) {
        // Stable, unique base ID derived from subject + day
        // Range: 0 – 999_999 (safe for notification IDs which are int)
        final baseId =
            (subject.id.hashCode.abs() % 5000) * 100 + (slot.dayOfWeek * 2);

        final preClassId = baseId;      // even → pre-class
        final postClassId = baseId + 1; // odd  → post-class

        // ---- 1. Pre-class reminder ----
        await _scheduleWeekly(
          id: preClassId,
          title: '📚 Class Starting Soon',
          body:
              '${subject.name} starts in $_kPreClassOffsetMinutes minutes. Get ready!',
          dayOfWeek: slot.dayOfWeek,
          hour: slot.startTime.hour,
          minute: slot.startTime.minute,
          addMinutes: -_kPreClassOffsetMinutes, // negative = before class
          channelId: _kPreClassChannelId,
          channelName: _kPreClassChannelName,
          channelDesc: _kPreClassChannelDesc,
        );

        // ---- 2. Post-class mark-attendance reminder ----
        final classDuration = subject.isLab ? 100 : 50; // minutes
        await _scheduleWeekly(
          id: postClassId,
          title: '✅ Mark Your Attendance',
          body:
              '${subject.name} just ended — don\'t forget to mark your attendance!',
          dayOfWeek: slot.dayOfWeek,
          hour: slot.startTime.hour,
          minute: slot.startTime.minute,
          addMinutes: classDuration, // fires right after class ends
          channelId: _kPostClassChannelId,
          channelName: _kPostClassChannelName,
          channelDesc: _kPostClassChannelDesc,
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helper
  // ---------------------------------------------------------------------------

  Future<void> _scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek, // 1 = Mon … 7 = Sun (Dart weekday)
    required int hour,
    required int minute,
    required int addMinutes, // positive = after start, negative = before start
    required String channelId,
    required String channelName,
    required String channelDesc,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    // Build the target TZDateTime for today at (hour:minute + addMinutes)
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).add(Duration(minutes: addMinutes));

    // Advance to the correct weekday
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // If already past this week's occurrence, push to next week
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _fln.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    debugPrint(
      'Scheduled #$id [$channelId]: "$title" at $scheduledDate '
      '(${_weekdayName(dayOfWeek)} ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} ${addMinutes >= 0 ? '+' : ''}${addMinutes}min)',
    );
  }

  String _weekdayName(int d) =>
      const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d];
}

// ---------------------------------------------------------------------------
// AttendanceMonitor — unchanged except for internal _checkAll formatting
// ---------------------------------------------------------------------------

class AttendanceMonitor {
  AttendanceMonitor._();
  static final AttendanceMonitor instance = AttendanceMonitor._();

  // Threshold (75%)
  static const double threshold = 75.0;

  // check every X minutes while app is running
  static const Duration _pollInterval = Duration(minutes: 60);

  Timer? _timer;
  static const String _lastNotificationKey = 'last_low_attendance_notification';

  Future<void> start() async {
    await NotificationService.instance.init();
    await checkAll();
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => checkAll());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  /// Checks per-subject and total attendance, triggers notifications for drops
  /// below threshold.
  Future<void> checkAll() async {
    try {
      final subjects = await FirestoreService.instance.getAllSubjects();
      final records = await FirestoreService.instance.getAllRecords();

      final Map<String, int> pointsPerSubject = {
        for (var s in subjects) s.id!: (s.isLab ? 2 : 1),
      };

      int totalPoints = 0;
      int attendedPoints = 0;

      for (var r in records) {
        final ptsPerSession = pointsPerSubject[r.subjectId] ?? 1;
        totalPoints += r.held * ptsPerSession;
        attendedPoints += r.attended * ptsPerSession;
      }

      final totalPerc =
          totalPoints > 0 ? (attendedPoints / totalPoints) * 100.0 : 100.0;

      if (totalPerc < threshold) {
        final prefs = await SharedPreferences.getInstance();
        final lastTime = prefs.getInt(_lastNotificationKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;

        // Throttle: at most once per 24 hours
        if (now - lastTime > 86400000) {
          await NotificationService.instance.show(
            id: 'TOTAL'.hashCode,
            title: 'Low total attendance',
            body:
                '${totalPerc.toStringAsFixed(1)}% (below ${threshold.toStringAsFixed(0)}%)',
          );
          await prefs.setInt(_lastNotificationKey, now);
        }
      }
    } catch (e) {
      debugPrint('AttendanceMonitor.checkAll error: $e');
    }
  }

  /// Optional: call this after a specific subject changed for an immediate check.
  Future<void> checkSubject(String subjectId) async {
    await checkAll();
  }
}
