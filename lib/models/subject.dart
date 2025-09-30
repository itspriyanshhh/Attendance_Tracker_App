class Subject {
  String? id;
  String name;
  bool isLab;
  String color; // hex like "#3B82F6"

  Subject({
    this.id,
    required this.name,
    this.isLab = false,
    this.color = '#FFFFFF', // default dark gray
  });

  Map<String, dynamic> toMap() {
    return {'name': name, 'isLab': isLab ? 1 : 0, 'color': color};
  }

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'],
      name: map['name'] ?? '',
      isLab: (map['isLab'] == 1 || map['isLab'] == true),
      color: (map['color'] as String?) ?? '#3B82F6',
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
