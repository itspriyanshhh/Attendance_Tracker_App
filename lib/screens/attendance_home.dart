import 'package:attendance_management/main.dart';
import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/screens/safe_bunk_sheet.dart';
import 'package:attendance_management/screens/timetable_screen.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persist user's dark-mode choice
Future<void> _saveDarkMode(bool enabled) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', enabled);
  } catch (e) {
    print('Failed to save dark mode pref: $e');
  }
}

class AttendanceHome extends StatefulWidget {
  const AttendanceHome({super.key});

  @override
  State<AttendanceHome> createState() => AttendanceHomeState();
}

class AttendanceHomeState extends State<AttendanceHome> {
  List<Subject> _subjects = [];
  List<AttendanceRecord> _records = [];
  double _totalAttendance = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    List<Subject> subjects = await FirestoreService.instance.getAllSubjects();
    List<AttendanceRecord> records = await FirestoreService.instance
        .getAllRecords();
    setState(() {
      _subjects = subjects;
      _records = records;
      _sortSubjects();
      _calculateTotalAttendance();
    });
  }

  void _sortSubjects() {
    final today = DateTime.now().weekday; // 1=Mon, 7=Sun
    _subjects.sort((a, b) {
      // Check if subjects have class today
      bool aHasClass = a.schedule.any((s) => s.dayOfWeek == today);
      bool bHasClass = b.schedule.any((s) => s.dayOfWeek == today);

      if (aHasClass && !bHasClass) return -1;
      if (!aHasClass && bHasClass) return 1;

      // If both have class today, sort by time
      if (aHasClass && bHasClass) {
        final aSlot = a.schedule.firstWhere((s) => s.dayOfWeek == today);
        final bSlot = b.schedule.firstWhere((s) => s.dayOfWeek == today);
        final aMin = aSlot.startTime.hour * 60 + aSlot.startTime.minute;
        final bMin = bSlot.startTime.hour * 60 + bSlot.startTime.minute;
        return aMin.compareTo(bMin);
      }

      // Otherwise alphabetical
      return a.name.compareTo(b.name);
    });
  }

  void _calculateTotalAttendance() {
    // Build subject lookup for points-per-session
    final Map<String, int> pointsPerSubject = {
      for (var s in _subjects) s.id!: (s.isLab ? 2 : 1),
    };

    int totalPoints = 0;
    int attendedPoints = 0;

    for (var record in _records) {
      final ptsPerSession = pointsPerSubject[record.subjectId] ?? 1;
      totalPoints += record.held * ptsPerSession;
      attendedPoints += record.attended * ptsPerSession;
    }

    _totalAttendance = totalPoints > 0
        ? (attendedPoints / totalPoints) * 100
        : 0.0;
  }

  Future<void> _addSubject(BuildContext context) async {
    final _formKey = GlobalKey<FormState>();
    String name = '';
    bool isLab = false;

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter dialogSetState) => AlertDialog(
          title: const Text('Add Subject'),
          content: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Subject Name'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter a subject name'
                      : null,
                  onSaved: (v) => name = v!.trim(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Is Lab?'),
                    Switch(
                      value: isLab,
                      onChanged: (value) => dialogSetState(() => isLab = value),
                      activeColor: Colors.indigo, // when ON
                      inactiveThumbColor: Colors.grey, // thumb when OFF
                      inactiveTrackColor:
                          Colors.grey.shade300, // track when OFF
                      materialTapTargetSize: MaterialTapTargetSize
                          .shrinkWrap, // optional: smaller tap target inside dialogs
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                  final newSubject = Subject(
                    name: name,
                    isLab: isLab,
                    color: '#FFFFFF',
                  );
                  try {
                    await FirestoreService.instance.insertSubject(newSubject);
                    await _loadData();
                    Navigator.pop(dialogContext);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add subject: $e')),
                    );
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSubject(Subject subject) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Subject'),
        content: Text(
          'Are you sure you want to delete "${subject.name}"? This will also delete all attendance records for this subject.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirestoreService.instance.deleteSubject(subject.id!);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${subject.name} deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete subject: $e')));
      }
    }
  }

  int _getSubjectTotalSessions(Subject subject) {
    return _records
        .where((r) => r.subjectId == subject.id)
        .fold(0, (sum, r) => sum + r.held);
  }

  int _getSubjectAttendedSessions(Subject subject) {
    return _records
        .where((r) => r.subjectId == subject.id)
        .fold(0, (sum, r) => sum + r.attended);
  }

  double _getSubjectPercentage(Subject subject) {
    int total = _getSubjectTotalSessions(subject);
    int attended = _getSubjectAttendedSessions(subject);
    return total > 0 ? (attended / total) * 100 : 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // final cardTextColor = Theme.of(context).textTheme.bodyLarge!.color;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendify',
          style: Theme.of(context).textTheme.headlineMedium!,
        ),
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: isDarkMode,
            builder: (context, dark, _) => IconButton(
              tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
              icon: Icon(dark ? Icons.dark_mode : Icons.light_mode),
              onPressed: () async {
                isDarkMode.value = !dark;
                await _saveDarkMode(isDarkMode.value);
              },
            ),
          ),

          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Timetable',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TimetableScreen(),
                ),
              );
              _loadData(); // Refresh to re-sort if schedule changed
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addSubject(context),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo, Colors.indigo[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    'Total Attendance',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    '${_totalAttendance.toStringAsFixed(2)}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Calculate current totals
                      final Map<String, int> pointsPerSubject = {
                        for (var s in _subjects) s.id!: (s.isLab ? 2 : 1),
                      };
                      int totalPoints = 0;
                      int attendedPoints = 0;
                      for (var record in _records) {
                        final ptsPerSession =
                            pointsPerSubject[record.subjectId] ?? 1;
                        totalPoints += record.held * ptsPerSession;
                        attendedPoints += record.attended * ptsPerSession;
                      }

                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => SafeBunkSheet(
                          totalPointsHeld: totalPoints,
                          totalPointsAttended: attendedPoints,
                        ),
                      );
                    },
                    icon: const Icon(Icons.calculate, color: Colors.indigo),
                    label: const Text(
                      'Safe Bunk Calculator',
                      style: TextStyle(
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _subjects.isEmpty
                  ? const Center(child: Text('No subjects added yet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _subjects.length,
                      itemBuilder: (context, index) {
                        Subject subject = _subjects[index];
                        // Replace the existing Card(...) return in the ListView.builder with this block
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              // Show a simple delete-only confirmation when the card is tapped
                              final bool? confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Subject'),
                                  content: Text(
                                    'Delete "${subject.name}" and all its attendance records?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                _deleteSubject(subject);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // left accent strip
                                  Container(
                                    width: 6,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.indigo.shade700,
                                          Colors.indigo.shade400,
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // main info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title row: name (no menu)
                                        Text(
                                          subject.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),

                                        const SizedBox(height: 6),

                                        // type chip + sessions summary
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: subject.isLab
                                                    ? Colors.orange.withOpacity(
                                                        0.12,
                                                      )
                                                    : Colors.blue.withOpacity(
                                                        0.10,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                subject.isLab
                                                    ? 'Lab (2 pts)'
                                                    : 'Lecture (1 pt)',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              'Sessions: ${_getSubjectAttendedSessions(subject)} / ${_getSubjectTotalSessions(subject)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: const Color.fromARGB(
                                                      255,
                                                      156,
                                                      156,
                                                      156,
                                                    ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // circular progress + % label
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // background circle
                                            SizedBox(
                                              width: 64,
                                              height: 64,
                                              child: CircularProgressIndicator(
                                                value:
                                                    (_getSubjectPercentage(
                                                              subject,
                                                            ) /
                                                            100)
                                                        .clamp(0.0, 1.0),
                                                strokeWidth: 6,
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(
                                                      Theme.of(
                                                        context,
                                                      ).colorScheme.primary,
                                                    ),
                                              ),
                                            ),
                                            // percentage text
                                            Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${_getSubjectPercentage(subject).toStringAsFixed(0)}%',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
    );
  }
}
