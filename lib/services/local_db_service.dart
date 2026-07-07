import 'dart:convert';

import 'package:attendance_management/models/subject.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local SQLite database that is the primary data source for the app.
/// Firestore is only used for weekly backup / first-login restore.
class LocalDbService {
  LocalDbService._();
  static final LocalDbService instance = LocalDbService._();

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'attendify.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE subjects (
            id       INTEGER PRIMARY KEY AUTOINCREMENT,
            name     TEXT    NOT NULL,
            is_lab   INTEGER NOT NULL DEFAULT 0,
            color    TEXT    NOT NULL DEFAULT '#FFFFFF',
            schedule TEXT    NOT NULL DEFAULT '[]'
          )
        ''');

        await db.execute('''
          CREATE TABLE attendance_records (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            subject_id TEXT    NOT NULL,
            date       TEXT    NOT NULL,
            held       INTEGER NOT NULL DEFAULT 0,
            attended   INTEGER NOT NULL DEFAULT 0,
            UNIQUE(subject_id, date)
          )
        ''');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Subjects
  // ---------------------------------------------------------------------------

  Future<List<Subject>> getAllSubjects() async {
    final db = await _database;
    final rows = await db.query('subjects');
    return rows.map(_rowToSubject).toList();
  }

  Future<Subject> insertSubject(Subject subject) async {
    final db = await _database;
    final id = await db.insert('subjects', _subjectToRow(subject));
    subject.id = id.toString();
    return subject;
  }

  Future<void> updateSubject(Subject subject) async {
    final db = await _database;
    if (subject.id == null) return;
    await db.update(
      'subjects',
      _subjectToRow(subject),
      where: 'id = ?',
      whereArgs: [int.parse(subject.id!)],
    );
  }

  Future<void> deleteSubject(String id) async {
    final db = await _database;
    final intId = int.parse(id);
    // Remove all attendance records for this subject first
    await db.delete(
      'attendance_records',
      where: 'subject_id = ?',
      whereArgs: [id],
    );
    await db.delete('subjects', where: 'id = ?', whereArgs: [intId]);
  }

  Future<void> deleteAllSubjects() async {
    final subjects = await getAllSubjects();
    for (final s in subjects) {
      await deleteSubject(s.id!);
    }
  }

  Future<void> clearAllTimetables() async {
    final db = await _database;
    final subjects = await getAllSubjects();
    for (final s in subjects) {
      s.schedule.clear();
      await db.update(
        'subjects',
        {'schedule': '[]'},
        where: 'id = ?',
        whereArgs: [int.parse(s.id!)],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Attendance Records
  // ---------------------------------------------------------------------------

  Future<List<AttendanceRecord>> getAllRecords() async {
    final db = await _database;
    final rows = await db.query('attendance_records');
    return rows.map(_rowToRecord).toList();
  }

  Future<List<AttendanceRecord>> getRecordsForDate(String date) async {
    final db = await _database;
    final rows = await db.query(
      'attendance_records',
      where: 'date = ?',
      whereArgs: [date],
    );
    return rows.map(_rowToRecord).toList();
  }

  Future<List<String>> getUniqueDates() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT date FROM attendance_records ORDER BY date DESC',
    );
    return rows.map((r) => r['date'] as String).toList();
  }

  Future<AttendanceRecord?> getRecordForSubjectAndDate(
    String subjectId,
    String date,
  ) async {
    final db = await _database;
    final rows = await db.query(
      'attendance_records',
      where: 'subject_id = ? AND date = ?',
      whereArgs: [subjectId, date],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToRecord(rows.first);
  }

  Future<AttendanceRecord> insertRecord(AttendanceRecord record) async {
    final db = await _database;
    final id = await db.insert(
      'attendance_records',
      _recordToRow(record),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    record.id = id.toString();
    return record;
  }

  Future<void> updateRecord(AttendanceRecord record) async {
    final db = await _database;
    if (record.id == null) return;
    await db.update(
      'attendance_records',
      _recordToRow(record),
      where: 'id = ?',
      whereArgs: [int.parse(record.id!)],
    );
  }

  Future<void> deleteRecord(String id) async {
    final db = await _database;
    await db.delete(
      'attendance_records',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
  }

  Future<void> deleteRecordsForDate(String date) async {
    final db = await _database;
    await db.delete(
      'attendance_records',
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  Future<void> deleteAllRecords() async {
    final db = await _database;
    await db.delete('attendance_records');
  }

  /// Returns true if the local DB has no subjects AND no records (empty state).
  Future<bool> isEmpty() async {
    final db = await _database;
    final subjectCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM subjects'),
    )!;
    return subjectCount == 0;
  }

  /// Wipes all local data (used on account deletion or full reset).
  Future<void> wipeAll() async {
    final db = await _database;
    await db.delete('attendance_records');
    await db.delete('subjects');
  }

  // ---------------------------------------------------------------------------
  // Row ↔ Model converters
  // ---------------------------------------------------------------------------

  Subject _rowToSubject(Map<String, dynamic> row) {
    final scheduleJson = row['schedule'] as String? ?? '[]';
    final scheduleList = (jsonDecode(scheduleJson) as List<dynamic>)
        .map((e) => ScheduleSlot.fromMap(e as Map<String, dynamic>))
        .toList();

    return Subject(
      id: row['id'].toString(),
      name: row['name'] as String,
      isLab: (row['is_lab'] as int) == 1,
      color: row['color'] as String? ?? '#FFFFFF',
      schedule: scheduleList,
    );
  }

  Map<String, dynamic> _subjectToRow(Subject s) => {
    'name': s.name,
    'is_lab': s.isLab ? 1 : 0,
    'color': s.color,
    'schedule': jsonEncode(s.schedule.map((sl) => sl.toMap()).toList()),
  };

  AttendanceRecord _rowToRecord(Map<String, dynamic> row) => AttendanceRecord(
    id: row['id'].toString(),
    subjectId: row['subject_id'] as String,
    date: row['date'] as String,
    held: row['held'] as int,
    attended: row['attended'] as int,
  );

  Map<String, dynamic> _recordToRow(AttendanceRecord r) => {
    'subject_id': r.subjectId,
    'date': r.date,
    'held': r.held,
    'attended': r.attended,
  };

  /// Returns all subjects and records sorted by ID for deterministic hashing.
  /// Used by SyncService to compute a content hash for incremental sync.
  Future<({List<Subject> subjects, List<AttendanceRecord> records})>
      getAllDataForHash() async {
    final db = await _database;

    final subjectRows =
        await db.query('subjects', orderBy: 'id ASC');
    final subjects = subjectRows.map(_rowToSubject).toList();

    final recordRows =
        await db.query('attendance_records', orderBy: 'id ASC');
    final records = recordRows.map(_rowToRecord).toList();

    return (subjects: subjects, records: records);
  }
}
