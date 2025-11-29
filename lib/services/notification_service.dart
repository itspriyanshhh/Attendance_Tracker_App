import 'dart:async';

import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

  static const String _prefKey = 'class_reminders_enabled';

  Future<void> init() async {
    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
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

  Future<void> show({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'attendance_channel',
          'Attendance Alerts',
          channelDescription: 'Alerts when attendance is below threshold',
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

  /// Schedules daily reminders - one per day, 2 hours after the last class
  Future<void> scheduleClassReminders(List<Subject> subjects) async {
    // Check preference first
    if (!await areRemindersEnabled()) {
      await cancelAll();
      return;
    }

    // First, clear existing to avoid duplicates/stale schedules
    await cancelAll();

    // Group all slots by day of week
    Map<int, List<ScheduleSlot>> slotsByDay = {};

    for (var subject in subjects) {
      for (var slot in subject.schedule) {
        slotsByDay.putIfAbsent(slot.dayOfWeek, () => []);
        slotsByDay[slot.dayOfWeek]!.add(slot);
      }
    }

    int notificationId = 1000;

    // For each day that has classes, find the last class and schedule reminder 2 hours after
    for (var dayOfWeek in slotsByDay.keys) {
      final daySlots = slotsByDay[dayOfWeek]!;

      // Find the slot with the latest start time
      ScheduleSlot? lastSlot;
      int latestMinutes = -1;

      for (var slot in daySlots) {
        final totalMinutes = slot.startTime.hour * 60 + slot.startTime.minute;
        if (totalMinutes > latestMinutes) {
          latestMinutes = totalMinutes;
          lastSlot = slot;
        }
      }

      if (lastSlot != null) {
        // Schedule reminder 2 hours (120 minutes) after last class starts
        // Assuming 1-hour class duration, this means 1 hour after class ends
        await _scheduleWeekly(
          id: notificationId++,
          title: 'Mark Your Attendance',
          body: 'Don\'t forget to mark your attendance for today!',
          dayOfWeek: dayOfWeek,
          hour: lastSlot.startTime.hour,
          minute: lastSlot.startTime.minute,
          addMinutes: 120, // 2 hours after class starts
        );
      }
    }
  }

  Future<void> _scheduleWeekly({
    required int id,
    required String title,
    required String body,
    required int dayOfWeek, // 1=Mon, 7=Sun
    required int hour,
    required int minute,
    required int addMinutes,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    // Calculate the next occurrence of this day/time
    // 1. Create date for today with target time
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).add(Duration(minutes: addMinutes));

    // 2. Adjust to correct day of week
    // dayOfWeek in Dart: 1=Mon...7=Sun
    // scheduledDate.weekday: 1=Mon...7=Sun
    while (scheduledDate.weekday != dayOfWeek) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // 3. If it's in the past, add 7 days
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'class_reminders',
          'Class Reminders',
          channelDescription: 'Reminders to mark attendance after class',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    await _fln.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );

    print('Scheduled #$id: $title at $scheduledDate');
  }
}

class AttendanceMonitor {
  AttendanceMonitor._();
  static final AttendanceMonitor instance = AttendanceMonitor._();

  // Threshold (75%)
  static const double threshold = 75.0;

  // check every X minutes while app is running (adjust as desired)
  static const Duration _pollInterval = Duration(minutes: 60);

  Timer? _timer;
  // Key for storing last notification timestamp
  static const String _lastNotificationKey = 'last_low_attendance_notification';

  Future<void> start() async {
    // ensure notification service ready
    await NotificationService.instance.init();

    // initial run
    await checkAll();

    // periodic checks
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => checkAll());
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  /// checks per-subject and total attendance, triggers notifications for drops below threshold
  Future<void> checkAll() async {
    try {
      // load subjects & records (assumes FirestoreService exists)
      final subjects = await FirestoreService.instance.getAllSubjects();
      final records = await FirestoreService.instance.getAllRecords();

      // build map subjectId -> pointsPerSession (1 for lecture, 2 for lab)
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

      final totalPerc = totalPoints > 0
          ? (attendedPoints / totalPoints) * 100.0
          : 100.0;

      if (totalPerc < threshold) {
        final prefs = await SharedPreferences.getInstance();
        final lastTime = prefs.getInt(_lastNotificationKey) ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;

        // Check if 24 hours (86400000 ms) have passed
        if (now - lastTime > 86400000) {
          await NotificationService.instance.show(
            id: 'TOTAL'.hashCode,
            title: 'Low total attendance',
            body:
                '${totalPerc.toStringAsFixed(1)}% (below ${threshold.toStringAsFixed(0)}%)',
          );
          // Update last notification time
          await prefs.setInt(_lastNotificationKey, now);
        }
      }
    } catch (e) {
      print('AttendanceMonitor.checkAll error: $e');
    }
  }

  /// optional: call this after a specific subject changed so we check immediately for that subject
  Future<void> checkSubject(String subjectId) async {
    // small optimization: just call checkAll for simplicity
    await checkAll();
  }
}
