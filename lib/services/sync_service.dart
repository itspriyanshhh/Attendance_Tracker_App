import 'dart:convert';
import 'dart:math';

import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/local_db_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles:
///  1. First-login cloud-to-local restore
///  2. Weekly local-to-cloud backup push (incremental — only changed data)
///  3. Single-device session enforcement
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const String _lastSyncKey = 'last_cloud_sync';
  static const String _deviceIdKey = 'device_id';
  static const Duration _syncInterval = Duration(days: 7);

  /// Maximum operations per Firestore batch (Firestore limit is 500).
  static const int _batchLimit = 499;

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
  // Content hashing — used to detect changes since last sync
  // ---------------------------------------------------------------------------

  /// Computes a deterministic SHA-256 hash of all local subjects + records.
  /// The data is sorted by ID and serialized to JSON so the hash is stable
  /// regardless of query ordering.
  Future<String> _computeContentHash() async {
    final data = await LocalDbService.instance.getAllDataForHash();

    final buffer = StringBuffer();

    // Subjects — sorted by ID, serialize key fields
    for (final s in data.subjects) {
      buffer.write('S|${s.id}|${s.name}|${s.isLab}|${s.color}|');
      // Include schedule slots deterministically
      for (final slot in s.schedule) {
        buffer.write(
          '${slot.dayOfWeek}:${slot.startTime.hour}:${slot.startTime.minute}:${slot.durationMinutes},',
        );
      }
      buffer.write('\n');
    }

    // Records — sorted by ID, serialize key fields
    for (final r in data.records) {
      buffer.write('R|${r.id}|${r.subjectId}|${r.date}|${r.held}|${r.attended}\n');
    }

    final bytes = utf8.encode(buffer.toString());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ---------------------------------------------------------------------------
  // Cloud hash read/write — stored on the user document
  // ---------------------------------------------------------------------------

  /// Reads the last sync content hash from the user's Firestore document.
  Future<String?> _getCloudSyncHash(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['lastSyncHash'] as String?;
    } catch (e) {
      debugPrint('SyncService: _getCloudSyncHash failed: $e');
      return null;
    }
  }

  /// Writes the content hash to the user's Firestore document.
  Future<void> _setCloudSyncHash(String uid, String hash) async {
    await _firestore.collection('users').doc(uid).set({
      'lastSyncHash': hash,
    }, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Stable document IDs — deterministic mapping from local IDs
  // ---------------------------------------------------------------------------

  /// Generates a stable Firestore document ID for a subject.
  /// Format: `sub_{localSqliteId}`
  String _subjectDocId(String localId) => 'sub_$localId';

  /// Generates a stable Firestore document ID for an attendance record.
  /// Format: `rec_{localSubjectId}_{date}`
  /// This matches the SQLite UNIQUE(subject_id, date) constraint.
  String _recordDocId(String subjectId, String date) => 'rec_${subjectId}_$date';

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
      final idMapping = await _pullSubjects(uid);
      await _pullRecords(uid, idMapping);
      debugPrint('SyncService: restore complete.');
    } catch (e) {
      debugPrint('SyncService: restore failed (offline?): $e');
    }
  }

  /// Pulls subjects from Firestore and inserts them into the local DB.
  /// Returns a mapping of { originalSubjectId → newLocalSubjectId } so
  /// that [_pullRecords] can remap attendance records correctly.
  Future<Map<String, String>> _pullSubjects(String uid) async {
    final Map<String, String> idMapping = {};
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subjects')
        .get();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      // Extract original local ID from stable doc ID (format: sub_{localId})
      String originalId;
      if (doc.id.startsWith('sub_')) {
        originalId = doc.id.substring(4); // strip "sub_" prefix
      } else {
        originalId = doc.id; // legacy auto-generated Firestore ID
      }
      data['id'] = originalId;
      final subject = Subject.fromMap(data);
      // Let SQLite assign its own ID for fresh installs
      subject.id = null;
      final inserted = await LocalDbService.instance.insertSubject(subject);
      if (inserted.id != null) {
        idMapping[originalId] = inserted.id!;
      }
    }
    debugPrint(
      'SyncService: restored ${snapshot.docs.length} subjects. '
      'ID mapping: $idMapping',
    );
    return idMapping;
  }

  /// Pulls attendance records from Firestore, remaps their subjectId using
  /// [idMapping], and inserts them into the local DB.
  Future<void> _pullRecords(
    String uid,
    Map<String, String> idMapping,
  ) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('attendance_records')
        .get();
    for (final doc in snapshot.docs) {
      final data = doc.data()..['id'] = doc.id;
      final record = AttendanceRecord.fromMap(data);

      // Remap subjectId from the original ID to the new local SQLite ID
      final newSubjectId = idMapping[record.subjectId];
      if (newSubjectId != null) {
        record.subjectId = newSubjectId;
      } else {
        debugPrint(
          'SyncService: record ${doc.id} has unmapped subjectId '
          '${record.subjectId}, keeping as-is.',
        );
      }

      record.id = null; // let SQLite assign its own ID
      await LocalDbService.instance.insertRecord(record);
    }
    debugPrint('SyncService: restored ${snapshot.docs.length} records.');
  }

  // ---------------------------------------------------------------------------
  // Weekly push: Local → Firestore (INCREMENTAL)
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

  /// Pushes local data to Firestore using incremental sync.
  ///
  /// 1. Computes a content hash of all local data.
  /// 2. Compares with the hash stored in Firestore from the last sync.
  /// 3. If identical → skip (0 writes).
  /// 4. If different → diff cloud vs local, only write changes.
  ///
  /// Safe to call manually (e.g. from Settings "Sync Now" button).
  Future<void> pushToCloud() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // Step 1: Compute local content hash
      final localHash = await _computeContentHash();

      // Step 2: Compare with cloud hash
      final cloudHash = await _getCloudSyncHash(uid);
      if (cloudHash != null && cloudHash == localHash) {
        debugPrint('SyncService: no changes since last sync, skipping.');
        // Still update the local sync timestamp so the "last synced" UI
        // reflects the check even though no data was written.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          _lastSyncKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        return;
      }

      debugPrint('SyncService: changes detected, performing incremental sync…');

      // Step 3: Fetch all local data
      final subjects = await LocalDbService.instance.getAllSubjects();
      final records = await LocalDbService.instance.getAllRecords();

      // Step 4: Fetch existing cloud document IDs
      final existingSubjectDocs = await _firestore
          .collection('users')
          .doc(uid)
          .collection('subjects')
          .get();
      final existingRecordDocs = await _firestore
          .collection('users')
          .doc(uid)
          .collection('attendance_records')
          .get();

      final existingSubjectIds =
          existingSubjectDocs.docs.map((d) => d.id).toSet();
      final existingRecordIds =
          existingRecordDocs.docs.map((d) => d.id).toSet();

      // Step 5: Compute which doc IDs we expect to exist after sync
      final expectedSubjectIds = <String>{};
      final expectedRecordIds = <String>{};

      // Collect batched operations
      final List<_BatchOp> operations = [];

      // --- Subjects: set() with merge for each local subject ---
      for (final s in subjects) {
        final docId = _subjectDocId(s.id!);
        expectedSubjectIds.add(docId);
        final ref = _firestore
            .collection('users')
            .doc(uid)
            .collection('subjects')
            .doc(docId);
        operations.add(_BatchOp.set(ref, s.toMap()));
      }

      // Delete cloud subjects that no longer exist locally
      for (final cloudId in existingSubjectIds) {
        if (!expectedSubjectIds.contains(cloudId)) {
          final ref = _firestore
              .collection('users')
              .doc(uid)
              .collection('subjects')
              .doc(cloudId);
          operations.add(_BatchOp.delete(ref));
        }
      }

      // --- Attendance Records: set() with merge for each local record ---
      for (final r in records) {
        final docId = _recordDocId(r.subjectId, r.date);
        expectedRecordIds.add(docId);
        final ref = _firestore
            .collection('users')
            .doc(uid)
            .collection('attendance_records')
            .doc(docId);
        operations.add(_BatchOp.set(ref, {
          'subjectId': r.subjectId,
          'date': r.date,
          'held': r.held,
          'attended': r.attended,
        }));
      }

      // Delete cloud records that no longer exist locally
      for (final cloudId in existingRecordIds) {
        if (!expectedRecordIds.contains(cloudId)) {
          final ref = _firestore
              .collection('users')
              .doc(uid)
              .collection('attendance_records')
              .doc(cloudId);
          operations.add(_BatchOp.delete(ref));
        }
      }

      // Step 6: Execute operations in batches of _batchLimit
      await _executeBatched(operations);

      // Step 7: Store the content hash in Firestore
      await _setCloudSyncHash(uid, localHash);

      // Record sync time locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _lastSyncKey,
        DateTime.now().millisecondsSinceEpoch,
      );

      final setCount = operations.where((op) => op.type == _BatchOpType.set).length;
      final deleteCount =
          operations.where((op) => op.type == _BatchOpType.delete).length;
      debugPrint(
        'SyncService: incremental push complete — '
        '$setCount sets, $deleteCount deletes '
        '(${subjects.length} subjects, ${records.length} records).',
      );
    } catch (e) {
      debugPrint('SyncService: pushToCloud failed: $e');
      rethrow; // let caller show an error if needed
    }
  }

  /// Executes a list of batch operations, splitting into chunks of
  /// [_batchLimit] to stay within Firestore's 500-operation batch limit.
  Future<void> _executeBatched(List<_BatchOp> operations) async {
    if (operations.isEmpty) return;

    for (int i = 0; i < operations.length; i += _batchLimit) {
      final chunk = operations.sublist(
        i,
        (i + _batchLimit).clamp(0, operations.length),
      );
      final batch = _firestore.batch();
      for (final op in chunk) {
        switch (op.type) {
          case _BatchOpType.set:
            batch.set(op.ref, op.data!);
          case _BatchOpType.delete:
            batch.delete(op.ref);
        }
      }
      await batch.commit();
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

// ---------------------------------------------------------------------------
// Internal helper for batched operations
// ---------------------------------------------------------------------------

enum _BatchOpType { set, delete }

class _BatchOp {
  final _BatchOpType type;
  final DocumentReference ref;
  final Map<String, dynamic>? data;

  _BatchOp.set(this.ref, this.data) : type = _BatchOpType.set;
  _BatchOp.delete(this.ref) : type = _BatchOpType.delete, data = null;
}
