import 'dart:convert';

import 'package:attendance_management/models/planner_item.dart';
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

        await db.execute('''
          CREATE TABLE planner_items (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            title        TEXT    NOT NULL,
            subject_id   TEXT,
            description  TEXT    NOT NULL DEFAULT '',
            date         TEXT    NOT NULL,
            type         TEXT    NOT NULL DEFAULT 'Assignment',
            is_completed INTEGER NOT NULL DEFAULT 0
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

  // ---------------------------------------------------------------------------
  // Planner Items
  // ---------------------------------------------------------------------------

  Future<List<PlannerItem>> getPlannerItems() async {
    final db = await _database;
    final rows = await db.query('planner_items', orderBy: 'date ASC');
    return rows.map(_rowToPlannerItem).toList();
  }

  Future<PlannerItem> addPlannerItem(PlannerItem item) async {
    final db = await _database;
    final id = await db.insert('planner_items', _plannerItemToRow(item));
    item.id = id.toString();
    return item;
  }

  Future<void> updatePlannerItem(PlannerItem item) async {
    final db = await _database;
    if (item.id == null) return;
    await db.update(
      'planner_items',
      _plannerItemToRow(item),
      where: 'id = ?',
      whereArgs: [int.parse(item.id!)],
    );
  }

  Future<void> deletePlannerItem(String id) async {
    final db = await _database;
    await db.delete(
      'planner_items',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
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
    await db.delete('planner_items');
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

  PlannerItem _rowToPlannerItem(Map<String, dynamic> row) => PlannerItem(
    id: row['id'].toString(),
    title: row['title'] as String,
    subjectId: row['subject_id'] as String?,
    description: row['description'] as String? ?? '',
    date: DateTime.parse(row['date'] as String),
    type: row['type'] as String? ?? 'Assignment',
    isCompleted: (row['is_completed'] as int) == 1,
  );

  Map<String, dynamic> _plannerItemToRow(PlannerItem p) => {
    'title': p.title,
    'subject_id': p.subjectId,
    'description': p.description,
    'date': p.date.toIso8601String(),
    'type': p.type,
    'is_completed': p.isCompleted ? 1 : 0,
  };
}
