import 'package:attendance_management/models/planner_item.dart';
import 'package:attendance_management/models/subject.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static FirestoreService? _instance;
  static FirestoreService get instance => _instance ??= FirestoreService._();
  FirestoreService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference _subjectsCollection() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    return _firestore.collection('users').doc(userId).collection('subjects');
  }

  /// Delete all attendance records for a given date (yyyy-MM-dd)
  Future<void> deleteRecordsForDate(String date) async {
    final snapshot = await _recordsCollection()
        .where('date', isEqualTo: date)
        .get();
    for (final doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  CollectionReference _recordsCollection() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('attendance_records');
  }

  Future<List<Subject>> getAllSubjects() async {
    QuerySnapshot snapshot = await _subjectsCollection().get();
    return snapshot.docs
        .map(
          (doc) => Subject.fromMap(
            doc.data() as Map<String, dynamic>..['id'] = doc.id,
          ),
        )
        .toList();
  }

  /// Delete all subjects (and their related records)
  Future<void> deleteAllSubjects() async {
    final snapshot = await _subjectsCollection().get();
    for (final doc in snapshot.docs) {
      // deleteSubject will also remove attendance records for that subject
      await deleteSubject(doc.id);
    }
  }

  /// Delete all attendance records for the current user
  Future<void> deleteAllRecords() async {
    final snapshot = await _recordsCollection().get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    // commit batch if any docs
    if (snapshot.docs.isNotEmpty) {
      await batch.commit();
    }
  }

  Future<void> insertSubject(Subject subject) async {
    await _subjectsCollection().add(subject.toMap());
  }

  Future<void> updateSubject(Subject subject) async {
    if (subject.id != null) {
      await _subjectsCollection().doc(subject.id).update(subject.toMap());
    }
  }

  Future<void> deleteSubject(String id) async {
    await _recordsCollection().where('subjectId', isEqualTo: id).get().then((
      snapshot,
    ) {
      for (var doc in snapshot.docs) {
        doc.reference.delete();
      }
    });
    await _subjectsCollection().doc(id).delete();
  }

  Future<List<AttendanceRecord>> getAllRecords() async {
    QuerySnapshot snapshot = await _recordsCollection().get();
    return snapshot.docs
        .map(
          (doc) => AttendanceRecord.fromMap(
            doc.data() as Map<String, dynamic>..['id'] = doc.id,
          ),
        )
        .toList();
  }

  Future<List<String>> getUniqueDates() async {
    QuerySnapshot snapshot = await _recordsCollection().get();
    Set<String> dates = snapshot.docs
        .map((doc) => doc['date'] as String)
        .toSet();
    return dates.toList()
      ..sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));
  }

  Future<List<AttendanceRecord>> getRecordsForDate(String date) async {
    QuerySnapshot snapshot = await _recordsCollection()
        .where('date', isEqualTo: date)
        .get();
    return snapshot.docs
        .map(
          (doc) => AttendanceRecord.fromMap(
            doc.data() as Map<String, dynamic>..['id'] = doc.id,
          ),
        )
        .toList();
  }

  Future<AttendanceRecord?> getRecordForSubjectAndDate(
    String subjectId,
    String date,
  ) async {
    QuerySnapshot snapshot = await _recordsCollection()
        .where('subjectId', isEqualTo: subjectId)
        .where('date', isEqualTo: date)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return AttendanceRecord.fromMap(
      snapshot.docs.first.data() as Map<String, dynamic>
        ..['id'] = snapshot.docs.first.id,
    );
  }

  Future<void> insertRecord(AttendanceRecord record) async {
    await _recordsCollection().add(record.toMap());
  }

  Future<void> updateRecord(AttendanceRecord record) async {
    await _recordsCollection().doc(record.id).update(record.toMap());
  }

  Future<void> deleteRecord(String id) async {
    await _recordsCollection().doc(id).delete();
  }

  CollectionReference _plannerCollection() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('planner_items');
  }

  Future<List<PlannerItem>> getPlannerItems() async {
    QuerySnapshot snapshot = await _plannerCollection().get();
    return snapshot.docs
        .map(
          (doc) => PlannerItem.fromMap(
            doc.data() as Map<String, dynamic>..['id'] = doc.id,
          ),
        )
        .toList();
  }

  Future<void> addPlannerItem(PlannerItem item) async {
    await _plannerCollection().add(item.toMap());
  }

  Future<void> updatePlannerItem(PlannerItem item) async {
    if (item.id != null) {
      await _plannerCollection().doc(item.id).update(item.toMap());
    }
  }

  Future<void> deletePlannerItem(String id) async {
    await _plannerCollection().doc(id).delete();
  }

  Future<void> clearAllTimetables() async {
    final snapshot = await _subjectsCollection().get();
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;
      final subject = Subject.fromMap(data);
      subject.schedule.clear();
      await updateSubject(subject);
    }
  }
}
