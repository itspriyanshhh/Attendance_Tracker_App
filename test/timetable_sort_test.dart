import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_management/models/subject.dart';

void main() {
  group('Subject Sorting', () {
    test('Sorts subjects with class today first', () {
      final today = DateTime.now().weekday;
      final tomorrow = (today % 7) + 1;

      final subjectToday = Subject(
        name: 'Today Class',
        schedule: [
          ScheduleSlot(
            dayOfWeek: today,
            startTime: const TimeOfDay(hour: 10, minute: 0),
          ),
        ],
      );

      final subjectTomorrow = Subject(
        name: 'Tomorrow Class',
        schedule: [
          ScheduleSlot(
            dayOfWeek: tomorrow,
            startTime: const TimeOfDay(hour: 10, minute: 0),
          ),
        ],
      );

      final subjects = [subjectTomorrow, subjectToday];

      subjects.sort((a, b) {
        bool aHasClass = a.schedule.any((s) => s.dayOfWeek == today);
        bool bHasClass = b.schedule.any((s) => s.dayOfWeek == today);

        if (aHasClass && !bHasClass) return -1;
        if (!aHasClass && bHasClass) return 1;
        return 0;
      });

      expect(subjects.first.name, 'Today Class');
      expect(subjects.last.name, 'Tomorrow Class');
    });

    test('Sorts subjects by time if both have class today', () {
      final today = DateTime.now().weekday;

      final earlyClass = Subject(
        name: 'Early Class',
        schedule: [
          ScheduleSlot(
            dayOfWeek: today,
            startTime: const TimeOfDay(hour: 9, minute: 0),
          ),
        ],
      );

      final lateClass = Subject(
        name: 'Late Class',
        schedule: [
          ScheduleSlot(
            dayOfWeek: today,
            startTime: const TimeOfDay(hour: 11, minute: 0),
          ),
        ],
      );

      final subjects = [lateClass, earlyClass];

      subjects.sort((a, b) {
        bool aHasClass = a.schedule.any((s) => s.dayOfWeek == today);
        bool bHasClass = b.schedule.any((s) => s.dayOfWeek == today);

        if (aHasClass && bHasClass) {
          final aSlot = a.schedule.firstWhere((s) => s.dayOfWeek == today);
          final bSlot = b.schedule.firstWhere((s) => s.dayOfWeek == today);
          final aMin = aSlot.startTime.hour * 60 + aSlot.startTime.minute;
          final bMin = bSlot.startTime.hour * 60 + bSlot.startTime.minute;
          return aMin.compareTo(bMin);
        }
        return 0;
      });

      expect(subjects.first.name, 'Early Class');
      expect(subjects.last.name, 'Late Class');
    });
  });
}
