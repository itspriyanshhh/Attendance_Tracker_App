import 'dart:math';

import 'package:attendance_management/models/planner_item.dart';
import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/local_db_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles:
///  1. First-login cloud-to-local restore
///  2. Weekly local-to-cloud backup push
///  3. Single-device session enforcement
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const String _lastSyncKey = 'last_cloud_sync';
  static const String _deviceIdKey = 'device_id';
  static const Duration _syncInterval = Duration(days: 7);

  final _firestore = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ---------------------------------------------------------------------------
  // Device ID
  // ---------------------------------------------------------------------------

  /// Returns a persistent unique device ID (generated once, stored locally).
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_deviceIdKey);
    if (id == null) {
      id = _generateId();
      await prefs.setString(_deviceIdKey, id);
    }
    return id;
  }

  String _generateId() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return List.generate(24, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // ---------------------------------------------------------------------------
  // Session enforcement — single active device
  // ---------------------------------------------------------------------------

  /// Called after login. Registers this device as the active session in
  /// Firestore. If another device was previously active, it will be kicked out
  /// next time it checks [validateSession].
  Future<void> registerSession() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final deviceId = await getDeviceId();
      await _firestore.collection('users').doc(uid).set({
        'session': {
          'deviceId': deviceId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
      debugPrint('SyncService: session registered for device $deviceId');
    } catch (e) {
      // Non-fatal — user may be offline; we proceed anyway
      debugPrint('SyncService: registerSession failed (offline?): $e');
    }
  }

  /// Checks whether this device is still the active session.
  /// Returns `false` if another device has taken over (user should be
  /// signed out and shown a message).
  /// Returns `true` if online and session is valid, OR if offline (we trust
  /// the local session when there's no connectivity).
  Future<bool> validateSession() async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final deviceId = await getDeviceId();
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      final data = doc.data();
      if (data == null) return true; // no session doc yet → valid
      final sessionDeviceId =
          (data['session'] as Map<String, dynamic>?)?['deviceId'] as String?;
      if (sessionDeviceId == null) return true;
      final isValid = sessionDeviceId == deviceId;
      if (!isValid) {
        debugPrint(
          'SyncService: session mismatch. Expected $deviceId, got $sessionDeviceId',
        );
      }
      return isValid;
    } catch (e) {
      // Offline or server error → trust local session
      debugPrint('SyncService: validateSession failed (offline?): $e');
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // First-login restore: Firestore → Local
  // ---------------------------------------------------------------------------

  /// If the local DB is empty (fresh install), pulls all data from Firestore
  /// into the local SQLite database. No-op if local DB already has data.
  Future<void> restoreFromCloudIfEmpty() async {
    final uid = _uid;
    if (uid == null) return;

    final isLocalEmpty = await LocalDbService.instance.isEmpty();
    if (!isLocalEmpty) {
      debugPrint('SyncService: local DB has data, skipping restore.');
      return;
    }

    debugPrint('SyncService: local DB is empty — restoring from Firestore…');
    try {
      final cloudToLocalSubjectId = await _pullSubjects(uid);
      await _pullRecords(uid, cloudToLocalSubjectId);
      await _pullPlannerItems(uid, cloudToLocalSubjectId);
      debugPrint('SyncService: restore complete.');
    } catch (e) {
      debugPrint('SyncService: restore failed (offline?): $e');
    }
  }

  Future<Map<String, String>> _pullSubjects(String uid) async {
    final Map<String, String> cloudToLocalSubjectId = {};
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .get();
    for (final doc in snapshot.docs) {
      final data = doc.data()..['id'] = doc.id;
      final subject = Subject.fromMap(data);
      final cloudId = doc.id;
      subject.id = null; // let SQLite assign its own ID
      final insertedSubject =
          await LocalDbService.instance.insertSubject(subject);
      if (insertedSubject.id != null) {
        cloudToLocalSubjectId[cloudId] = insertedSubject.id!;
      }
    }
    debugPrint('SyncService: restored ${snapshot.docs.length} subjects.');
    return cloudToLocalSubjectId;
  }

  Future<void> _pullRecords(
    String uid,
    Map<String, String> cloudToLocalSubjectId,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('attendance_records')
        .get();
    for (final doc in snapshot.docs) {
      final data = doc.data()..['id'] = doc.id;
      final record = AttendanceRecord.fromMap(data);

      // Remap Firestore subject doc ID to new local SQLite autoincremented ID
      final localSubjectId = cloudToLocalSubjectId[record.subjectId];
      if (localSubjectId != null) {
        record.subjectId = localSubjectId;
      }

      record.id = null; // let SQLite assign its own ID
      await LocalDbService.instance.insertRecord(record);
    }
    debugPrint('SyncService: restored ${snapshot.docs.length} records.');
  }

  Future<void> _pullPlannerItems(
    String uid,
    Map<String, String> cloudToLocalSubjectId,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('planner_items')
        .get();
    for (final doc in snapshot.docs) {
      final data = doc.data()..['id'] = doc.id;
      final item = PlannerItem.fromMap(data);

      // Remap Firestore subject doc ID to new local SQLite autoincremented ID
      if (item.subjectId != null) {
        final localSubjectId = cloudToLocalSubjectId[item.subjectId];
        if (localSubjectId != null) {
          item.subjectId = localSubjectId;
        }
      }

      item.id = null;
      await LocalDbService.instance.addPlannerItem(item);
    }
    debugPrint(
      'SyncService: restored ${snapshot.docs.length} planner items.',
    );
  }

  // ---------------------------------------------------------------------------
  // Weekly push: Local → Firestore
  // ---------------------------------------------------------------------------

  /// Checks if 7 days have elapsed since the last sync and pushes if so.
  /// Called silently at app start.
  Future<void> syncIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSync = prefs.getInt(_lastSyncKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastSync >= _syncInterval.inMilliseconds) {
      debugPrint('SyncService: sync is due — pushing to cloud…');
      await pushToCloud();
    } else {
      final daysLeft =
          (_syncInterval.inMilliseconds - (now - lastSync)) ~/
          Duration.millisecondsPerDay;
      debugPrint('SyncService: sync not due yet (~$daysLeft days left).');
    }
  }

  /// Pushes all local data to Firestore (full overwrite for this user).
  /// Safe to call manually (e.g. from Settings "Sync Now" button).
  Future<void> pushToCloud() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final subjects = await LocalDbService.instance.getAllSubjects();
      final records = await LocalDbService.instance.getAllRecords();
      final plannerItems = await LocalDbService.instance.getPlannerItems();

      // Build a local-id → Firestore-doc-id map for subject cross-referencing
      final Map<String, String> localToCloudId = {};

      // --- Subjects ---
      // Delete existing cloud subjects
      final existingSubjects = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .get();
      final subjectBatch = _firestore.batch();
      for (final doc in existingSubjects.docs) {
        subjectBatch.delete(doc.reference);
      }
      await subjectBatch.commit();

      // Write new subjects and record ID mapping
      for (final s in subjects) {
        final ref = _firestore
            .collection('users')
            .doc(uid)
            .collection('subjects')
            .doc();
        await ref.set(s.toMap());
        localToCloudId[s.id!] = ref.id;
      }

      // --- Attendance Records ---
      final existingRecords = await _firestore
          .collection('users')
          .doc(uid)
          .collection('attendance_records')
          .get();
      final recordBatch = _firestore.batch();
      for (final doc in existingRecords.docs) {
        recordBatch.delete(doc.reference);
      }
      await recordBatch.commit();

      for (final r in records) {
        final cloudSubjectId = localToCloudId[r.subjectId] ?? r.subjectId;
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('attendance_records')
            .add({
              'subjectId': cloudSubjectId,
              'date': r.date,
              'held': r.held,
              'attended': r.attended,
            });
      }

      // --- Planner Items ---
      final existingPlanner = await _firestore
          .collection('users')
          .doc(uid)
          .collection('planner_items')
          .get();
      final plannerBatch = _firestore.batch();
      for (final doc in existingPlanner.docs) {
        plannerBatch.delete(doc.reference);
      }
      await plannerBatch.commit();

      for (final p in plannerItems) {
        final cloudSubjectId = p.subjectId != null
            ? (localToCloudId[p.subjectId] ?? p.subjectId)
            : null;
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('planner_items')
            .add({
              'title': p.title,
              'subjectId': cloudSubjectId,
              'description': p.description,
              'date': p.date.toIso8601String(),
              'type': p.type,
              'isCompleted': p.isCompleted,
            });
      }

      // Record sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastSyncKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      debugPrint(
        'SyncService: push complete — '
        '${subjects.length} subjects, ${records.length} records, '
        '${plannerItems.length} planner items.',
      );
    } catch (e) {
      debugPrint('SyncService: pushToCloud failed: $e');
      rethrow; // let caller show an error if needed
    }
  }

  /// Returns the DateTime of the last successful cloud sync, or null.
  Future<DateTime?> lastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_lastSyncKey);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
