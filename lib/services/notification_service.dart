import 'dart:async';

import 'package:attendance_management/services/firestore_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
