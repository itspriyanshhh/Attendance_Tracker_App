class PlannerItem {
  String? id;
  String title;
  String? subjectId; // Optional link to a subject
  String description;
  DateTime date;
  String type; // 'Assignment' or 'Exam'
  bool isCompleted;

  PlannerItem({
    this.id,
    required this.title,
    this.subjectId,
    this.description = '',
    required this.date,
    required this.type,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subjectId': subjectId,
      'description': description,
      'date': date.toIso8601String(),
      'type': type,
      'isCompleted': isCompleted,
    };
  }

  factory PlannerItem.fromMap(Map<String, dynamic> map) {
    return PlannerItem(
      id: map['id'],
      title: map['title'] ?? '',
      subjectId: map['subjectId'],
      description: map['description'] ?? '',
      date: DateTime.parse(map['date']),
      type: map['type'] ?? 'Assignment',
      isCompleted: map['isCompleted'] ?? false,
    );
  }
}
