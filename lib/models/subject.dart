import 'package:flutter/material.dart';

class ScheduleSlot {
  final int dayOfWeek; // 1 = Mon, 7 = Sun
  final TimeOfDay startTime;
  final int durationMinutes;

  ScheduleSlot({
    required this.dayOfWeek,
    required this.startTime,
    this.durationMinutes = 60,
  });

  Map<String, dynamic> toMap() {
    return {
      'day': dayOfWeek,
      'hour': startTime.hour,
      'minute': startTime.minute,
      'duration': durationMinutes,
    };
  }

  factory ScheduleSlot.fromMap(Map<String, dynamic> map) {
    return ScheduleSlot(
      dayOfWeek: map['day'] ?? 1,
      startTime: TimeOfDay(hour: map['hour'] ?? 9, minute: map['minute'] ?? 0),
      durationMinutes: map['duration'] ?? 60,
    );
  }
}

class Subject {
  String? id;
  String name;
  bool isLab;
  String color; // hex like "#3B82F6"
  List<ScheduleSlot> schedule;

  Subject({
    this.id,
    required this.name,
    this.isLab = false,
    this.color = '#FFFFFF', // default dark gray
    this.schedule = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'isLab': isLab ? 1 : 0,
      'color': color,
      'schedule': schedule.map((s) => s.toMap()).toList(),
    };
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'],
      name: map['name'] ?? '',
      isLab: (map['isLab'] == 1 || map['isLab'] == true),
      color: (map['color'] as String?) ?? '#3B82F6',
      schedule:
          (map['schedule'] as List<dynamic>?)
              ?.map((x) => ScheduleSlot.fromMap(x))
              .toList() ??
          [],
    );
  }
}

class AttendanceRecord {
  String? id;
  String subjectId;
  String date;
  int held;
  int attended;

  AttendanceRecord({
    this.id,
    required this.subjectId,
    required this.date,
    this.held = 0,
    this.attended = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'subjectId': subjectId,
      'date': date,
      'held': held,
      'attended': attended,
    };
  }

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) {
    return AttendanceRecord(
      id: map['id'],
      subjectId: map['subjectId'],
      date: map['date'],
      held: map['held'],
      attended: map['attended'],
    );
  }
}
