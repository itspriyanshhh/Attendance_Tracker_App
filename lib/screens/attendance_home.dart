import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/screens/paywall_screen.dart';
import 'package:attendance_management/screens/safe_bunk_sheet.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:attendance_management/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show isDarkMode;

class AttendanceHome extends StatefulWidget {
  const AttendanceHome({super.key});

  @override
  State<AttendanceHome> createState() => AttendanceHomeState();
}

class AttendanceHomeState extends State<AttendanceHome>
    with TickerProviderStateMixin {
  List<Subject> _subjects = [];
  List<AttendanceRecord> _records = [];

  double _totalAttendance = 0.0;
  bool _isLoading = true;

  // Animation controllers
  late AnimationController _headerAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize header animations
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _headerSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _headerAnimationController,
            curve: Curves.fastOutSlowIn,
          ),
        );

    _loadData();
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    super.dispose();
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

    // Trigger animations after data is loaded
    _headerAnimationController.forward();
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

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder:
          (
            BuildContext buildContext,
            Animation animation,
            Animation secondaryAnimation,
          ) {
            return StatefulBuilder(
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
                                  activeColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '1 Lab = 2 Lectures (for attendance calculation)',
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(buildContext),
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
                              Navigator.pop(buildContext);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to add subject: $e'),
                                ),
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
            );
          },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          child: FadeTransition(opacity: animation, child: child),
        );
      },
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
          // Theme Toggle Switch
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ValueListenableBuilder<bool>(
              valueListenable: isDarkMode,
              builder: (context, isDark, _) {
                return IconButton(
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: colorScheme.primary,
                  ),
                  tooltip: isDark
                      ? 'Switch to Light Mode'
                      : 'Switch to Dark Mode',
                  onPressed: () async {
                    isDarkMode.value = !isDarkMode.value;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('darkMode', isDarkMode.value);
                  },
                );
              },
            ),
          ),
          // Add Subject Button
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => _addSubject(context),
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline_rounded,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  Text(
                    'add subject',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: Column(
          children: [
            // Total Attendance Card with Animations
            FadeTransition(
              opacity: _headerFadeAnimation,
              child: SlideTransition(
                position: _headerSlideAnimation,
                child: Container(
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
                      // Animated percentage counter
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        tween: Tween<double>(begin: 0.0, end: _totalAttendance),
                        builder: (context, value, child) {
                          return Text(
                            '${value.toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(
                              color: colorScheme.onPrimary,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Check if user has access to bunk calculator
                            final hasAccess = await SubscriptionService.instance
                                .hasFeatureAccess('bunk_calculator');

                            if (!hasAccess && mounted) {
                              // Navigate to paywall
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PaywallScreen(),
                                ),
                              );

                              // If subscribed, show calculator
                              if (result != true) return;
                            }

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

                        // Staggered card animation
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 400 + (index * 100)),
                          curve: Curves.easeOut,
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          builder: (context, animValue, child) {
                            return Opacity(
                              opacity: animValue,
                              child: Transform.translate(
                                offset: Offset(0, 30 * (1 - animValue)),
                                child: child,
                              ),
                            );
                          },
                          child: Container(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                  ? Colors.orange.withOpacity(
                                                      0.2,
                                                    )
                                                  : Colors.blue.withOpacity(
                                                      0.2,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                              color: Colors.grey.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                          ),
                                          FractionallySizedBox(
                                            widthFactor: (percentage / 100)
                                                .clamp(0.0, 1.0),
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
