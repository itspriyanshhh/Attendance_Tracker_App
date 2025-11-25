import 'package:attendance_management/main.dart';
import 'package:attendance_management/screens/analytics_screen.dart';
import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/screens/safe_bunk_sheet.dart';
import 'package:attendance_management/screens/timetable_screen.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    List<Subject> subjects = await FirestoreService.instance.getAllSubjects();
    List<AttendanceRecord> records = await FirestoreService.instance
        .getAllRecords();
    setState(() {
      _subjects = subjects;
      _records = records;
      _sortSubjects();
      _calculateTotalAttendance();
      _isLoading = false;
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
        builder: (BuildContext context, StateSetter dialogSetState) =>
            AlertDialog(
              title: Text(
                'Add Subject',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Subject Name',
                        labelStyle: GoogleFonts.poppins(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      style: GoogleFonts.poppins(),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a subject name'
                          : null,
                      onSaved: (v) => name = v!.trim(),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Is Lab?',
                            style: GoogleFonts.poppins(fontSize: 16),
                          ),
                          Switch(
                            value: isLab,
                            onChanged: (value) =>
                                dialogSetState(() => isLab = value),
                            activeColor: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ),
                FilledButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      _formKey.currentState!.save();
                      final newSubject = Subject(
                        name: name,
                        isLab: isLab,
                        color: '#FFFFFF',
                      );
                      try {
                        await FirestoreService.instance.insertSubject(
                          newSubject,
                        );
                        await _loadData();
                        Navigator.pop(dialogContext);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to add subject: $e')),
                        );
                      }
                    }
                  },
                  child: Text('Add', style: GoogleFonts.poppins()),
                ),
              ],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
      ),
    );
  }

  Future<void> _deleteSubject(Subject subject) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          'Delete Subject',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${subject.name}"? This will also delete all attendance records for this subject.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendify',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 24),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          ValueListenableBuilder<bool>(
            valueListenable: isDarkMode,
            builder: (context, dark, _) => IconButton(
              tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
              icon: Icon(
                dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                // Ensure visibility in both modes by using onSurface
                // In light mode, onSurface is dark (visible on light bg)
                // In dark mode, onSurface is light (visible on dark bg)
                // If the issue persists, we can force specific colors
                color: dark ? Colors.amber : colorScheme.onSurface,
              ),
              onPressed: () async {
                isDarkMode.value = !dark;
                await _saveDarkMode(isDarkMode.value);
              },
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.calendar_month_rounded,
              color: colorScheme.onSurface,
            ),
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
            icon: Icon(Icons.bar_chart_rounded, color: colorScheme.onSurface),
            tooltip: 'Analytics',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(Icons.add, color: colorScheme.onSurface),
              onPressed: () => _addSubject(context),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // Total Attendance Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Overall Attendance',
                    style: GoogleFonts.poppins(
                      color: colorScheme.onPrimary.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_totalAttendance.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      color: colorScheme.onPrimary,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
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
                      icon: Icon(
                        Icons.calculate_outlined,
                        color: colorScheme.primary,
                      ),
                      label: Text(
                        'Safe Bunk Calculator',
                        style: GoogleFonts.poppins(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.onPrimary,
                        foregroundColor: colorScheme.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Subject List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    )
                  : _subjects.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.class_outlined,
                            size: 64,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No subjects added yet',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          TextButton(
                            onPressed: () => _addSubject(context),
                            child: Text(
                              'Add your first subject',
                              style: GoogleFonts.poppins(),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _subjects.length,
                      itemBuilder: (context, index) {
                        Subject subject = _subjects[index];
                        final percentage = _getSubjectPercentage(subject);
                        final attended = _getSubjectAttendedSessions(subject);
                        final total = _getSubjectTotalSessions(subject);
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;

                        // Define colors based on Theme
                        final cardColor = isDark
                            ? const Color(0xFF2C2C2E)
                            : Colors.white;
                        final titleColor = isDark ? Colors.white : Colors.black;
                        final labelColor = isDark
                            ? Colors.grey
                            : Colors.grey.shade600;

                        // Status Colors (Green/Red)
                        final greenColor = isDark
                            ? const Color(0xFF30D158)
                            : const Color(0xFF34C759);
                        final redColor = isDark
                            ? const Color(0xFFFF453A)
                            : const Color(0xFFFF3B30);
                        final statusColor = percentage >= 75
                            ? greenColor
                            : redColor;

                        // Shadow Configuration
                        final List<BoxShadow> shadows = isDark
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ];

                        // Progress Bar Glow (Dark Mode Only)
                        final List<BoxShadow>? progressShadows = isDark
                            ? [
                                BoxShadow(
                                  color: statusColor.withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: shadows,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(24),
                              onTap: () => _deleteSubject(subject),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Name and Percentage
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            subject.name,
                                            style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: titleColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${percentage.toStringAsFixed(0)}%',
                                          style: GoogleFonts.poppins(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Row 2: Badge and "Attendance" Label
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: subject.isLab
                                                ? Colors.orange.withOpacity(0.2)
                                                : Colors.blue.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            subject.isLab ? 'Lab' : 'Lecture',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: subject.isLab
                                                  ? Colors.orange.shade800
                                                  : Colors.blue.shade800,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'Attendance',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: labelColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    // Custom Progress Bar
                                    Stack(
                                      children: [
                                        Container(
                                          height: 10,
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                        ),
                                        FractionallySizedBox(
                                          widthFactor: (percentage / 100).clamp(
                                            0.0,
                                            1.0,
                                          ),
                                          child: Container(
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: statusColor,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              boxShadow: progressShadows,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Row 3: Attended and Total
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Attended: $attended',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: labelColor,
                                          ),
                                        ),
                                        Text(
                                          'Total: $total',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: labelColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

  // ignore: unused_element
  String _calculateSafeBunk(int attended, int total) {
    if (total == 0) return 'N/A';
    final percentage = (attended / total) * 100;
    if (percentage >= 75) {
      int bunks = ((4 * attended - 3 * total) / 3).floor();
      return 'Can bunk $bunks';
    } else {
      int classes = (3 * total - 4 * attended).ceil();
      return 'Attend $classes';
    }
  }
}
