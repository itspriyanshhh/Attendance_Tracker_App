// ignore_for_file: sort_child_properties_last

import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

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
    if (q.isEmpty) return _subjects;
    return _subjects.where((s) => s.name.toLowerCase().contains(q)).toList();
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
    return Scaffold(
      appBar: AppBar(title: const Text('Mark Attendance')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // calendar header
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('MMMM d, yyyy').format(_selectedDate),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: _maxPickableDate(),
                            );
                            if (picked != null)
                              setState(() => _selectedDate = picked);
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(
                    // height: 175,
                    child: TableCalendar(
                      firstDay: DateTime(2000),
                      lastDay: _maxPickableDate(),
                      focusedDay: _selectedDate,
                      selectedDayPredicate: (d) =>
                          DateFormat('yyyy-MM-dd').format(d) ==
                          DateFormat('yyyy-MM-dd').format(_selectedDate),
                      onDaySelected: (d, _) =>
                          setState(() => _selectedDate = d),
                      headerVisible: false,
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),

                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _filteredSubjects.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = _filteredSubjects[i];
                        final sid = s.id!;
                        final mark = _marks[sid] ?? SubjectMark();

                        // Row: selection mode + counters
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 6,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // top row: name + mode buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Mode: None / Attended / Missed / Both
                                  ToggleButtons(
                                    isSelected: [
                                      !(mark.selected) &&
                                          mark.heldIncrement == 0, // None
                                      mark.selected &&
                                          mark.missed == 0 &&
                                          mark.attended > 0, // Attended
                                      mark.selected &&
                                          mark.attended == 0 &&
                                          mark.missed > 0, // Missed
                                      mark.selected &&
                                          mark.attended > 0 &&
                                          mark.missed > 0, // Both
                                    ],
                                    onPressed: (index) {
                                      setState(() {
                                        mark.selected = true;
                                        switch (index) {
                                          case 0: // None
                                            mark.selected = false;
                                            mark.attended = 0;
                                            mark.missed = 0;
                                            break;
                                          case 1: // Attended
                                            mark.attended = mark.attended == 0
                                                ? 1
                                                : mark.attended;
                                            mark.missed = 0;
                                            break;
                                          case 2: // Missed
                                            mark.missed = mark.missed == 0
                                                ? 1
                                                : mark.missed;
                                            mark.attended = 0;
                                            break;
                                          case 3: // Both
                                            if (mark.attended == 0 &&
                                                mark.missed == 0) {
                                              mark.attended = 1;
                                              mark.missed = 0;
                                            }
                                            // keep existing non-zero values if present
                                            break;
                                        }
                                        _marks[sid] = mark;
                                      });
                                    },
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text('None'),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text('Att.'),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text('Miss.'),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text('Both'),
                                      ),
                                    ],
                                    borderRadius: BorderRadius.circular(8),
                                    constraints: const BoxConstraints(
                                      minHeight: 32,
                                      minWidth: 48,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 8),

                              // counters row: Attended +/- and Missed +/- and small held summary
                              Row(
                                children: [
                                  // Attended counter
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Text('Attended:'),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                          onPressed: mark.attended > 0
                                              ? () {
                                                  setState(() {
                                                    mark.attended =
                                                        (mark.attended - 1)
                                                            .clamp(0, 999);
                                                    if (mark.attended == 0 &&
                                                        mark.missed == 0)
                                                      mark.selected = false;
                                                    _marks[sid] = mark;
                                                  });
                                                }
                                              : null,
                                        ),
                                        Text('${mark.attended}'),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              mark.attended =
                                                  (mark.attended + 1).clamp(
                                                    0,
                                                    999,
                                                  );
                                              mark.selected = true;
                                              _marks[sid] = mark;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  // SizedBox(width: 16),

                                  // Missed counter
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Text('Missed:'),

                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                          ),
                                          onPressed: mark.missed > 0
                                              ? () {
                                                  setState(() {
                                                    mark.missed =
                                                        (mark.missed - 1).clamp(
                                                          0,
                                                          999,
                                                        );
                                                    if (mark.attended == 0 &&
                                                        mark.missed == 0)
                                                      mark.selected = false;
                                                    _marks[sid] = mark;
                                                  });
                                                }
                                              : null,
                                        ),
                                        Text('${mark.missed}'),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add_circle_outline,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              mark.missed = (mark.missed + 1)
                                                  .clamp(0, 999);
                                              mark.selected = true;
                                              _marks[sid] = mark;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check),
                            onPressed: (selectedCount > 0 && !_isSubmitting)
                                ? _confirmBatchMark
                                : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            label: Text(
                              _isSubmitting
                                  ? 'Uploading...'
                                  : 'Mark (${selectedCount})',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
