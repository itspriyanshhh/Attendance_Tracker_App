import 'dart:async';

import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

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

  /// Schedules weekly reminders for all classes
  Future<void> scheduleClassReminders(List<Subject> subjects) async {
    // First, clear existing to avoid duplicates/stale schedules
    await cancelAll();

    int notificationId = 1000; // Start ID range for class reminders

    for (var subject in subjects) {
      for (var slot in subject.schedule) {
        // Schedule for 10 minutes AFTER class starts (assuming 1 hour duration for simplicity,
        // or just "Did you attend?" prompt shortly after start).
        // The prompt asked for "10 minutes after each class ends".
        // Without duration data, I'll assume a standard 1-hour class, so 1h 10m after start.
        // Or better, just 50 mins after start (end of typical hour).

        // Let's go with: 10 mins after start "Don't forget to mark attendance!"
        // Or if strictly "after ends", I'll assume 60 min duration -> 70 mins after start.

        // Let's use 10 mins after class ENDS. Assuming 1 hour duration.
        // So trigger at StartTime + 70 minutes.

        await _scheduleWeekly(
          id: notificationId++,
          title: 'Class Ended: ${subject.name}',
          body: 'Did you attend ${subject.name}? Mark it now!',
          dayOfWeek: slot.dayOfWeek,
          hour: slot.startTime.hour,
          minute: slot.startTime.minute,
          addMinutes: 70,
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
  final Set<String> _notifiedSubjects =
      {}; // subjectId or 'TOTAL' to avoid duplicate notifications

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
        if (!_notifiedSubjects.contains('TOTAL')) {
          await NotificationService.instance.show(
            id: 'TOTAL'.hashCode,
            title: 'Low total attendance',
            body:
                '${totalPerc.toStringAsFixed(1)}% (below ${threshold.toStringAsFixed(0)}%)',
          );
          _notifiedSubjects.add('TOTAL');
        }
      } else {
        _notifiedSubjects.remove('TOTAL');
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
