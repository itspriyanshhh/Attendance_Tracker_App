// ignore_for_file: sort_child_properties_last

import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';

// add this class near top of the BatchMarkScreen file
class SubjectMark {
  int attended; // number of sessions to add to 'attended'
  int missed; // number of sessions to add to 'missed'
  bool selected; // true if user intends to modify this subject

  SubjectMark({this.attended = 0, this.missed = 0, this.selected = false});

  int get heldIncrement => attended + missed;
}

class BatchMarkScreen extends StatefulWidget {
  const BatchMarkScreen({super.key});

  @override
  State<BatchMarkScreen> createState() => _BatchMarkScreenState();
}

class _BatchMarkScreenState extends State<BatchMarkScreen> {
  List<Subject> _subjects = [];
  Map<String, SubjectMark> _marks = {};

  DateTime _selectedDate = DateTime.now();
  String _search = '';
  bool _loading = true;
  // Add this in _BatchMarkScreenState fields
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _maxPickableDate({int years = 5}) =>
      DateTime.now().add(Duration(days: 365 * years));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final subs = await FirestoreService.instance.getAllSubjects();
      final map = {for (var s in subs) s.id!: SubjectMark()};
      setState(() {
        _subjects = subs;
        _marks = map;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load subjects: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  List<Subject> get _filteredSubjects {
    final q = _search.trim().toLowerCase();
    List<Subject> filtered;
    if (q.isEmpty) {
      filtered = List.of(_subjects);
    } else {
      filtered = _subjects
          .where((s) => s.name.toLowerCase().contains(q))
          .toList();
    }

    final dayOfWeek = _selectedDate.weekday;

    filtered.sort((a, b) {
      // Helper to find the earliest slot for today
      ScheduleSlot? getEarliestSlot(Subject s) {
        final slots = s.schedule
            .where((slot) => slot.dayOfWeek == dayOfWeek)
            .toList();
        if (slots.isEmpty) return null;
        slots.sort((s1, s2) {
          final t1 = s1.startTime.hour * 60 + s1.startTime.minute;
          final t2 = s2.startTime.hour * 60 + s2.startTime.minute;
          return t1.compareTo(t2);
        });
        return slots.first;
      }

      final slotA = getEarliestSlot(a);
      final slotB = getEarliestSlot(b);

      // 1. Has slot today? (Scheduled comes first)
      if (slotA != null && slotB == null) return -1;
      if (slotA == null && slotB != null) return 1;

      // 2. Start time (Earliest first)
      if (slotA != null && slotB != null) {
        final t1 = slotA.startTime.hour * 60 + slotA.startTime.minute;
        final t2 = slotB.startTime.hour * 60 + slotB.startTime.minute;
        final timeComp = t1.compareTo(t2);
        if (timeComp != 0) return timeComp;
      }

      // 3. Name (Alphabetical)
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return filtered;
  }

  int get selectedCount =>
      _marks.values.where((m) => m.selected || m.heldIncrement > 0).length;

  // Replace your existing _confirmBatchMark(...) with this version:
  Future<void> _confirmBatchMark() async {
    if (_isSubmitting) return; // guard double taps
    setState(() => _isSubmitting = true);

    try {
      final selectedEntries = _marks.entries
          .where((e) => e.value.heldIncrement > 0)
          .toList();
      if (selectedEntries.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No subjects selected')));
        return;
      }

      final iso = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final List<Map<String, dynamic>> snapshots = [];

      int totalSubjects = selectedEntries.length;
      int totalHeldAdded = 0;
      int totalAttendedAdded = 0;
      int totalMissedAdded = 0;

      for (final entry in selectedEntries) {
        final sid = entry.key;
        final SubjectMark mark = entry.value;
        final int addHeld = mark.heldIncrement;
        final int addAttended = mark.attended;
        final int addMissed = mark.missed;

        totalHeldAdded += addHeld;
        totalAttendedAdded += addAttended;
        totalMissedAdded += addMissed;

        try {
          final existing = await FirestoreService.instance
              .getRecordForSubjectAndDate(sid, iso);
          if (existing != null) {
            // save previous snapshot for undo
            snapshots.add({
              'subjectId': sid,
              'previous': AttendanceRecord.fromMap({
                'id': existing.id,
                'subjectId': existing.subjectId,
                'date': existing.date,
                'held': existing.held,
                'attended': existing.attended,
              }),
              'resultId': existing.id,
            });

            existing.held += addHeld;
            existing.attended += addAttended;
            await FirestoreService.instance.updateRecord(existing);
          } else {
            snapshots.add({
              'subjectId': sid,
              'previous': null,
              'resultId': null,
            });
            final newRec = AttendanceRecord(
              subjectId: sid,
              date: iso,
              held: addHeld,
              attended: addAttended,
            );
            await FirestoreService.instance.insertRecord(newRec);
            final created = await FirestoreService.instance
                .getRecordForSubjectAndDate(sid, iso);
            if (created != null) snapshots.last['resultId'] = created.id;
          }
        } catch (e) {
          print('Batch mark failed for $sid: $e');
        }
      }

      // Refresh screen data
      await _load();

      // Show summary + Undo
      final snack = SnackBar(
        content: Text(
          '$totalSubjects subjects updated — $totalHeldAdded sessions added ($totalAttendedAdded attended, $totalMissedAdded missed) on ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
          maxLines: 2,
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await _revertBatch(snapshots);
          },
        ),
        duration: const Duration(seconds: 6),
      );

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(snack);

      // clear marks (reset UI)
      for (final key in _marks.keys.toList()) {
        _marks[key] = SubjectMark();
      }
      setState(() {});
    } finally {
      // ensure flag is cleared even if an error occurs
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _revertBatch(List<Map<String, dynamic>> snapshots) async {
    for (final snap in snapshots) {
      final String sid = snap['subjectId'];
      final AttendanceRecord? prev = snap['previous'] as AttendanceRecord?;
      final String? resultId = snap['resultId'] as String?;

      try {
        if (prev == null) {
          // newly created record — delete by id if we have it, otherwise attempt lookup and delete
          String? idToDelete = resultId;
          if (idToDelete == null) {
            final found = await FirestoreService.instance
                .getRecordForSubjectAndDate(
                  sid,
                  DateFormat('yyyy-MM-dd').format(_selectedDate),
                );
            idToDelete = found?.id;
          }
          if (idToDelete != null)
            await FirestoreService.instance.deleteRecord(idToDelete);
        } else {
          // existed before — restore previous values
          final restoreId = prev.id ?? resultId;
          if (restoreId != null) {
            final restore = AttendanceRecord(
              id: restoreId,
              subjectId: prev.subjectId,
              date: prev.date,
              held: prev.held,
              attended: prev.attended,
            );
            await FirestoreService.instance.updateRecord(restore);
          } else {
            final fetched = await FirestoreService.instance
                .getRecordForSubjectAndDate(prev.subjectId, prev.date);
            if (fetched != null) {
              fetched.held = prev.held;
              fetched.attended = prev.attended;
              await FirestoreService.instance.updateRecord(fetched);
            }
          }
        }
      } catch (e) {
        print('Undo failed for $sid: $e');
      }
    }
    await _load();
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Changes undone')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mark Attendance',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Date Selection Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    decoration: BoxDecoration(
                      color:
                          theme.appBarTheme.backgroundColor ??
                          theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: _maxPickableDate(),
                            );
                            if (picked != null) {
                              setState(() => _selectedDate = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat(
                                    'MMMM d, yyyy',
                                  ).format(_selectedDate),
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TableCalendar(
                          firstDay: DateTime(2000),
                          lastDay: _maxPickableDate(),
                          focusedDay: _selectedDate,
                          currentDay: DateTime.now(),
                          selectedDayPredicate: (d) =>
                              isSameDay(_selectedDate, d),
                          onDaySelected: (d, _) =>
                              setState(() => _selectedDate = d),
                          headerVisible: false,
                          calendarFormat: CalendarFormat.week,
                          availableGestures: AvailableGestures.horizontalSwipe,
                          calendarStyle: CalendarStyle(
                            selectedDecoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            todayDecoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: GoogleFonts.poppins(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                            defaultTextStyle: GoogleFonts.poppins(),
                            weekendTextStyle: GoogleFonts.poppins(
                              color: colorScheme.error,
                            ),
                          ),
                          daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle: GoogleFonts.poppins(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            weekendStyle: GoogleFonts.poppins(
                              fontSize: 12,
                              color: colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subject List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: _filteredSubjects.length,
                      itemBuilder: (context, i) {
                        final s = _filteredSubjects[i];
                        final sid = s.id!;
                        final mark = _marks[sid] ?? SubjectMark();
                        final isSelected =
                            mark.selected || mark.heldIncrement > 0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: isSelected ? 4 : 1,
                          shadowColor: isSelected
                              ? colorScheme.primary.withOpacity(0.3)
                              : null,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: isSelected
                                ? BorderSide(
                                    color: colorScheme.primary,
                                    width: 1.5,
                                  )
                                : BorderSide.none,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? colorScheme.primary
                                              : colorScheme.onSurface,
                                        ),
                                      ),
                                    ),
                                    _buildStatusChip(mark, colorScheme),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCounter(
                                        context,
                                        label: 'Attended',
                                        value: mark.attended,
                                        color: Colors.green,
                                        onChanged: (val) {
                                          setState(() {
                                            mark.attended = val;
                                            _updateSelection(mark, sid);
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildCounter(
                                        context,
                                        label: 'Missed',
                                        value: mark.missed,
                                        color: Colors.red,
                                        onChanged: (val) {
                                          setState(() {
                                            mark.missed = val;
                                            _updateSelection(mark, sid);
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Bottom Action Bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: (selectedCount > 0 && !_isSubmitting)
                            ? _confirmBatchMark
                            : null,
                        icon: _isSubmitting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline),
                        label: Text(
                          _isSubmitting
                              ? 'Saving...'
                              : 'Mark Attendance ($selectedCount)',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _updateSelection(SubjectMark mark, String sid) {
    if (mark.attended > 0 || mark.missed > 0) {
      mark.selected = true;
    } else {
      mark.selected = false;
    }
    _marks[sid] = mark;
  }

  Widget _buildStatusChip(SubjectMark mark, ColorScheme colorScheme) {
    String label = 'None';
    Color color = colorScheme.surfaceContainerHighest;
    Color onColor = colorScheme.onSurfaceVariant;

    if (mark.attended > 0 && mark.missed > 0) {
      label = 'Mixed';
      color = Colors.orange.shade100;
      onColor = Colors.orange.shade900;
    } else if (mark.attended > 0) {
      label = 'Present';
      color = Colors.green.shade100;
      onColor = Colors.green.shade900;
    } else if (mark.missed > 0) {
      label = 'Absent';
      color = Colors.red.shade100;
      onColor = Colors.red.shade900;
    }

    if (label == 'None') return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: onColor,
        ),
      ),
    );
  }

  Widget _buildCounter(
    BuildContext context, {
    required String label,
    required int value,
    required Color color,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: value > 0
                    ? () => onChanged((value - 1).clamp(0, 99))
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: value > 0
                        ? color.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.remove,
                    size: 20,
                    color: value > 0 ? color : Colors.grey.shade400,
                  ),
                ),
              ),
              Text(
                '$value',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: value > 0 ? color : Colors.grey,
                ),
              ),
              InkWell(
                onTap: () => onChanged((value + 1).clamp(0, 99)),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.add, size: 20, color: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
