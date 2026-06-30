import 'dart:async';
import 'dart:convert';

import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/local_db_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
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

// Notification action IDs for post-class attendance buttons
const String _kActionAttended = 'mark_attended';
const String _kActionMissed = 'mark_missed';

// ---------------------------------------------------------------------------

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln =
      FlutterLocalNotificationsPlugin();

  static const String _prefKey = 'class_reminders_enabled';

  Future<void> init() async {
    // Configure the local timezone so scheduled notifications fire at the
    // correct local time (not UTC).
    await _configureLocalTimezone();

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
    await _fln.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationActionResponse,
      onDidReceiveBackgroundNotificationResponse:
          onBackgroundNotificationActionResponse,
    );

    // Request local notification permission on Android 13+ (API 33)
    final androidPlugin = _fln
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();

    // Request FCM / platform permissions for iOS
    await FirebaseMessaging.instance.requestPermission();
  }

  /// Detects the device timezone and sets [tz.local] accordingly.
  /// Without this, [tz.local] defaults to UTC and all scheduled
  /// notifications fire at the wrong time.
  Future<void> _configureLocalTimezone() async {
    try {
      final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
      final name = timeZoneInfo.identifier;
      try {
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {
        // Some devices return legacy IANA names (e.g. "Asia/Calcutta")
        // that the timezone package doesn't have. Map to the modern name.
        final mapped = _legacyTimezoneMap[name];
        if (mapped != null) {
          tz.setLocalLocation(tz.getLocation(mapped));
          debugPrint(
            'NotificationService: Mapped legacy timezone $name → $mapped',
          );
        } else {
          debugPrint(
            'NotificationService: Unknown timezone "$name", falling back to UTC',
          );
          return;
        }
      }
      debugPrint('NotificationService: Device timezone = $name');
    } catch (e) {
      // Fallback: keep tz.local as UTC if detection fails
      debugPrint('NotificationService: Failed to get local timezone: $e');
    }
  }

  /// Legacy IANA timezone names that some Android devices still report.
  static const _legacyTimezoneMap = <String, String>{
    'Asia/Calcutta': 'Asia/Kolkata',
    'Asia/Saigon': 'Asia/Ho_Chi_Minh',
    'Asia/Katmandu': 'Asia/Kathmandu',
    'Asia/Rangoon': 'Asia/Yangon',
    'Pacific/Ponape': 'Pacific/Pohnpei',
    'Pacific/Truk': 'Pacific/Chuuk',
    'America/Buenos_Aires': 'America/Argentina/Buenos_Aires',
    'Europe/Kiev': 'Europe/Kyiv',
    'Atlantic/Faeroe': 'Atlantic/Faroe',
  };

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

    // Request exact alarm permission on Android 12+ (API 31)
    final androidPlugin = _fln
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestExactAlarmsPermission();

    // Clear existing to avoid stale / duplicate schedules
    await cancelAll();

    for (final subject in subjects) {
      for (final slot in subject.schedule) {
        // Stable, unique base ID derived from subject + day + time
        // Incorporates hour to avoid collisions for multiple classes
        // on the same day for the same subject.
        final baseId =
            (subject.id.hashCode.abs() % 5000) * 10000 +
            (slot.dayOfWeek * 100) +
            (slot.startTime.hour * 2);

        final preClassId = baseId; // even → pre-class
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
        final payload = jsonEncode({
          'subjectId': subject.id,
          'subjectName': subject.name,
        });
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
          payload: payload,
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction(
              _kActionAttended,
              'Attended ✅',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _kActionMissed,
              'Missed ❌',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
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
    String? payload,
    List<AndroidNotificationAction>? actions,
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
          actions: actions,
        );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );

    try {
      await _fln.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );

      debugPrint(
        'Scheduled #$id [$channelId]: "$title" at $scheduledDate '
        '(${_weekdayName(dayOfWeek)} ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} ${addMinutes >= 0 ? '+' : ''}${addMinutes}min)',
      );
    } catch (e) {
      debugPrint(
        'Failed to schedule #$id [$channelId]: $e',
      );
    }
  }

  String _weekdayName(int d) =>
      const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d];

  /// Foreground notification-action handler.
  static void onNotificationActionResponse(NotificationResponse response) {
    handleAttendanceAction(response);
  }
}

// ---------------------------------------------------------------------------
// Top-level background handler (must be outside any class & public)
// ---------------------------------------------------------------------------

/// Called when a notification action is tapped while the app is in the
/// background or terminated. Must be a top-level, non-private function.
@pragma('vm:entry-point')
void onBackgroundNotificationActionResponse(NotificationResponse response) {
  handleAttendanceAction(response);
}

/// Shared handler for both foreground and background action taps.
/// Marks attendance in the local DB based on the action pressed.
Future<void> handleAttendanceAction(NotificationResponse response) async {
  // Only handle action button taps, not notification body taps
  if (response.notificationResponseType !=
      NotificationResponseType.selectedNotificationAction) {
    return;
  }

  final actionId = response.actionId;
  final payload = response.payload;
  if (actionId == null || payload == null) return;
  if (actionId != _kActionAttended && actionId != _kActionMissed) return;

  try {
    // Ensure Flutter bindings are ready (may run before main())
    WidgetsFlutterBinding.ensureInitialized();

    final data = jsonDecode(payload) as Map<String, dynamic>;
    final subjectId = data['subjectId'] as String;
    final subjectName = data['subjectName'] as String? ?? 'Unknown';
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Look up any existing record for this subject + today
    final existing = await LocalDbService.instance.getRecordForSubjectAndDate(
      subjectId,
      today,
    );

    if (existing != null) {
      // Increment the existing record
      existing.held += 1;
      if (actionId == _kActionAttended) {
        existing.attended += 1;
      }
      await LocalDbService.instance.updateRecord(existing);
    } else {
      // Create a new record for today
      await LocalDbService.instance.insertRecord(
        AttendanceRecord(
          subjectId: subjectId,
          date: today,
          held: 1,
          attended: actionId == _kActionAttended ? 1 : 0,
        ),
      );
    }

    final action = actionId == _kActionAttended ? 'Attended' : 'Missed';
    debugPrint(
      'NotificationService: Marked "$action" for $subjectName (id=$subjectId) on $today',
    );
  } catch (e) {
    debugPrint('NotificationService: Failed to handle attendance action: $e');
  }
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
    // init() is already called in main.dart before start()
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
      final subjects = await LocalDbService.instance.getAllSubjects();
      final records = await LocalDbService.instance.getAllRecords();

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
