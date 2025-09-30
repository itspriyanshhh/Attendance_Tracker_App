import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/screens/edit_day_screen.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

DateTime _maxPickableDate({int years = 5}) =>
    DateTime.now().add(Duration(days: 365 * years));

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<String> _dates = [];
  List<String> _filteredDates = [];
  Map<String, List<AttendanceRecord>> _recordsByDate = {};
  List<Subject> _subjects = [];

  // Filters / UI state
  String _searchQuery = '';
  String? _selectedSubjectId; // null == all subjects
  String? _selectedMonthLabel; // e.g. "September 2025"
  List<String> _monthLabels = [];
  bool _showCalendar = false;

  @override
  void initState() {
    super.initState();
    _loadDates();
  }

  Future<void> _deleteDate(String date) async {
    final readable = _formatDate(date);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete all attendance'),
        content: Text(
          'Are you sure you want to delete all attendance records for $readable? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirestoreService.instance.deleteRecordsForDate(date);
      // refresh UI
      await _loadDates();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted all attendance for $readable')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete records: $e')));
    }
  }

  Future<void> _loadDates() async {
    // Load dates and records (and subjects) from repository (works offline via Repository)
    final dates = await FirestoreService.instance.getUniqueDates();
    final allRecords = await FirestoreService.instance.getAllRecords();
    final allSubjects = await FirestoreService.instance.getAllSubjects();

    // Build recordsByDate map
    final Map<String, List<AttendanceRecord>> map = {};
    for (var r in allRecords) {
      map.putIfAbsent(r.date, () => []).add(r);
    }

    // Build month labels (unique month-year labels from dates)
    final monthSet = <String>{};
    for (var d in dates) {
      final dt = DateTime.parse(d);
      monthSet.add(DateFormat('MMMM yyyy').format(dt));
    }
    final months = monthSet.toList()
      ..sort((a, b) {
        // sort by date descending using parsed month-year - convert back to DateTime for sorting
        DateTime pa = DateFormat('MMMM yyyy').parse(a);
        DateTime pb = DateFormat('MMMM yyyy').parse(b);
        return pb.compareTo(pa);
      });

    setState(() {
      _dates = dates;
      _recordsByDate = map;
      _subjects = allSubjects;
      _monthLabels = months;
    });

    _applyFilters();
  }

  void _applyFilters() {
    List<String> result = _dates.where((dateStr) {
      // 1) search filter: check date formatted string or ISO date contains search text
      final formatted = DateFormat(
        'MMMM d, yyyy',
      ).format(DateTime.parse(dateStr));
      final searchLower = _searchQuery.trim().toLowerCase();
      if (searchLower.isNotEmpty) {
        if (!(formatted.toLowerCase().contains(searchLower) ||
            dateStr.toLowerCase().contains(searchLower))) {
          return false;
        }
      }

      // 2) month filter
      if (_selectedMonthLabel != null) {
        final monthLabel = DateFormat(
          'MMMM yyyy',
        ).format(DateTime.parse(dateStr));
        if (monthLabel != _selectedMonthLabel) return false;
      }

      // 3) subject filter: if selected, only include dates that have at least one record for that subject
      if (_selectedSubjectId != null) {
        final records = _recordsByDate[dateStr] ?? [];
        final has = records.any((r) => r.subjectId == _selectedSubjectId);
        if (!has) return false;
      }

      return true;
    }).toList();

    // Keep descending date order (same as your existing approach)
    result.sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));

    setState(() {
      _filteredDates = result;
    });
  }

  Future<void> _onSearchChanged(String q) async {
    setState(() => _searchQuery = q);
    _applyFilters();
  }

  Future<void> _onSelectedSubjectChanged(String? subjectId) async {
    setState(() => _selectedSubjectId = subjectId);
    _applyFilters();
  }

  Future<void> _onMonthChanged(String? monthLabel) async {
    setState(() => _selectedMonthLabel = monthLabel);
    _applyFilters();
  }

  // Helper: build dropdown items for subjects (include "All subjects")
  List<DropdownMenuItem<String?>> _subjectDropdownItems() {
    final items = <DropdownMenuItem<String?>>[];
    items.add(
      const DropdownMenuItem<String?>(value: null, child: Text('All subjects')),
    );
    for (var s in _subjects) {
      items.add(DropdownMenuItem<String?>(value: s.id, child: Text(s.name)));
    }
    return items;
  }

  List<DropdownMenuItem<String?>> _monthDropdownItems() {
    final items = <DropdownMenuItem<String?>>[];
    items.add(
      const DropdownMenuItem<String?>(value: null, child: Text('All months')),
    );
    for (var m in _monthLabels) {
      items.add(DropdownMenuItem<String?>(value: m, child: Text(m)));
    }
    return items;
  }

  // Calendar event loader for TableCalendar: convert DateTime->List of records for that date
  List<AttendanceRecord> _eventsForDay(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    return _recordsByDate[key] ?? [];
  }

  // When selecting a day on the calendar, navigate if there are records or allow navigation anyway
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    final iso = DateFormat('yyyy-MM-dd').format(selectedDay);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditDayScreen(date: iso)),
    ).then((_) => _loadDates());
  }

  // Format date for list display
  String _formatDate(String date) {
    return DateFormat('MMMM d, yyyy').format(DateTime.parse(date));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // Search bar + calendar toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText:
                            'Search by date (e.g. September 3, 2025) or ISO (yyyy-mm-dd)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Toggle calendar view',
                    icon: Icon(
                      _showCalendar ? Icons.view_list : Icons.calendar_today,
                    ),
                    onPressed: () =>
                        setState(() => _showCalendar = !_showCalendar),
                  ),
                ],
              ),
            ),

            // Filters row: subject + month
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      value: _selectedSubjectId,
                      decoration: const InputDecoration(
                        labelText: 'Filter by subject',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: _subjectDropdownItems(),
                      onChanged: _onSelectedSubjectChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 200,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      value: _selectedMonthLabel,
                      decoration: const InputDecoration(
                        labelText: 'Filter by month',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: _monthDropdownItems(),
                      onChanged: _onMonthChanged,
                    ),
                  ),
                ],
              ),
            ),

            // Calendar view or list view
            Expanded(
              child: _showCalendar
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TableCalendar<AttendanceRecord>(
                        firstDay: DateTime(2000),
                        lastDay: DateTime.now(),
                        focusedDay: DateTime.now(),
                        availableCalendarFormats: const {
                          CalendarFormat.month: 'Month',
                        },
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            final evs = _eventsForDay(date);
                            if (evs.isEmpty) return const SizedBox.shrink();
                            // small dot with count
                            return Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.indigo[700],
                                ),
                                child: Text(
                                  '${evs.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        eventLoader: (date) => _eventsForDay(date),
                        onDaySelected: _onDaySelected,
                      ),
                    )
                  : _filteredDates.isEmpty
                  ? const Center(
                      child: Text('No attendance records match the filter.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredDates.length,
                      itemBuilder: (context, index) {
                        final date = _filteredDates[index];
                        final records = _recordsByDate[date] ?? [];
                        // Build a subtitle listing subjects present that day (nice quick summary)
                        final subjectNames = records
                            .map(
                              (r) => _subjects
                                  .firstWhere(
                                    (s) => s.id == r.subjectId,
                                    orElse: () => Subject(name: 'Unknown'),
                                  )
                                  .name,
                            )
                            .toSet()
                            .join(', ');

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(_formatDate(date)),
                            subtitle: subjectNames.isNotEmpty
                                ? Text(subjectNames)
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            EditDayScreen(date: date),
                                      ),
                                    ).then((_) => _loadDates());
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Delete all records for this date',
                                  onPressed: () => _deleteDate(date),
                                ),
                              ],
                            ),

                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditDayScreen(date: date),
                                ),
                              ).then((_) => _loadDates());
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          DateTime? picked = await showDatePicker(
            context: context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: _maxPickableDate(), // allows adding future day entries
          );

          if (picked != null) {
            String newDate = DateFormat('yyyy-MM-dd').format(picked);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditDayScreen(date: newDate),
              ),
            ).then((_) => _loadDates());
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
