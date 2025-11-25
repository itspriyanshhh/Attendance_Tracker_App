import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/screens/edit_day_screen.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDates();
  }

  Future<void> _loadDates() async {
    print('DEBUG: _loadDates called');
    setState(() => _isLoading = true);
    try {
      final dates = await FirestoreService.instance.getUniqueDates();
      print('DEBUG: Fetched ${dates.length} dates: $dates');

      final allRecords = await FirestoreService.instance.getAllRecords();
      print('DEBUG: Fetched ${allRecords.length} records');

      final allSubjects = await FirestoreService.instance.getAllSubjects();
      print('DEBUG: Fetched ${allSubjects.length} subjects');

      // Build recordsByDate map
      final Map<String, List<AttendanceRecord>> map = {};
      for (var r in allRecords) {
        map.putIfAbsent(r.date, () => []).add(r);
      }

      // Build month labels (unique month-year labels from dates)
      final monthSet = <String>{};
      for (var d in dates) {
        try {
          final dt = DateTime.parse(d);
          monthSet.add(DateFormat('MMMM yyyy').format(dt));
        } catch (e) {
          print('Error parsing date $d: $e');
        }
      }
      final months = monthSet.toList()
        ..sort((a, b) {
          try {
            DateTime pa = DateFormat('MMMM yyyy').parse(a);
            DateTime pb = DateFormat('MMMM yyyy').parse(b);
            return pb.compareTo(pa);
          } catch (e) {
            return 0;
          }
        });

      if (mounted) {
        setState(() {
          _dates = dates;
          _recordsByDate = map;
          _subjects = allSubjects;
          _monthLabels = months;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e, stack) {
      print('Error loading history: $e');
      print(stack);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading history: $e')));
      }
    }
  }

  void _applyFilters() {
    print('DEBUG: _applyFilters called. _dates count: ${_dates.length}');
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

    print('DEBUG: _applyFilters result count: ${result.length}');

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
      DropdownMenuItem<String?>(
        value: null,
        child: Text('All subjects', style: GoogleFonts.poppins()),
      ),
    );
    for (var s in _subjects) {
      items.add(
        DropdownMenuItem<String?>(
          value: s.id,
          child: Text(s.name, style: GoogleFonts.poppins()),
        ),
      );
    }
    return items;
  }

  List<DropdownMenuItem<String?>> _monthDropdownItems() {
    final items = <DropdownMenuItem<String?>>[];
    items.add(
      DropdownMenuItem<String?>(
        value: null,
        child: Text('All months', style: GoogleFonts.poppins()),
      ),
    );
    for (var m in _monthLabels) {
      items.add(
        DropdownMenuItem<String?>(
          value: m,
          child: Text(m, style: GoogleFonts.poppins()),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // Search bar + calendar toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Search date...',
                        hintStyle: GoogleFonts.poppins(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    tooltip: 'Toggle calendar view',
                    icon: Icon(
                      _showCalendar
                          ? Icons.view_list_rounded
                          : Icons.calendar_month_rounded,
                    ),
                    onPressed: () =>
                        setState(() => _showCalendar = !_showCalendar),
                  ),
                ],
              ),
            ),

            // Filters row: subject + month
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      value: _selectedSubjectId,
                      decoration: InputDecoration(
                        labelText: 'Subject',
                        labelStyle: GoogleFonts.poppins(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: _subjectDropdownItems(),
                      onChanged: _onSelectedSubjectChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      value: _selectedMonthLabel,
                      decoration: InputDecoration(
                        labelText: 'Month',
                        labelStyle: GoogleFonts.poppins(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _showCalendar
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        child: TableCalendar<AttendanceRecord>(
                          firstDay: DateTime(2000),
                          lastDay: DateTime.now(),
                          focusedDay: DateTime.now(),
                          availableCalendarFormats: const {
                            CalendarFormat.month: 'Month',
                          },
                          headerStyle: HeaderStyle(
                            titleTextStyle: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            formatButtonVisible: false,
                          ),
                          calendarStyle: CalendarStyle(
                            defaultTextStyle: GoogleFonts.poppins(),
                            weekendTextStyle: GoogleFonts.poppins(),
                            todayDecoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            todayTextStyle: GoogleFonts.poppins(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            selectedTextStyle: GoogleFonts.poppins(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              final evs = _eventsForDay(date);
                              if (evs.isEmpty) return const SizedBox.shrink();
                              // small dot with count
                              return Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: colorScheme.secondary,
                                  ),
                                  child: Text(
                                    '${evs.length}',
                                    style: GoogleFonts.poppins(
                                      color: colorScheme.onSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          eventLoader: (date) => _eventsForDay(date),
                          onDaySelected: _onDaySelected,
                        ),
                      ),
                    )
                  : _filteredDates.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            size: 64,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No records found (Total: ${_dates.length})',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
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
                          elevation: 0,
                          color: colorScheme.surfaceContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditDayScreen(date: date),
                                ),
                              ).then((_) => _loadDates());
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        DateFormat(
                                          'd',
                                        ).format(DateTime.parse(date)),
                                        style: GoogleFonts.poppins(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'MMMM yyyy',
                                          ).format(DateTime.parse(date)),
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (subjectNames.isNotEmpty)
                                          Text(
                                            subjectNames,
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.chevron_right_rounded,
                                    ),
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
                                ],
                              ),
                            ),
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
