import 'dart:math';
import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/screens/profile_screen.dart';
import 'package:attendance_management/screens/safe_bunk_sheet.dart';
import 'package:attendance_management/services/local_db_service.dart';
import 'package:attendance_management/services/home_widget_service.dart';
import 'package:attendance_management/services/sync_service.dart';
import 'package:attendance_management/services/threshold_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:attendance_management/screens/gpa_calculator_screen.dart';

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
  int _totalAttended = 0;
  int _totalHeld = 0;
  bool _isLoading = true;

  // Animation controllers
  late AnimationController _headerAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  // Ring animation
  late AnimationController _ringAnimationController;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();

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

    _ringAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _ringAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _loadData();
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _ringAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);

    await SyncService.instance.restoreFromCloudIfEmpty();

    List<Subject> subjects = await LocalDbService.instance.getAllSubjects();
    List<AttendanceRecord> records = await LocalDbService.instance
        .getAllRecords();
    setState(() {
      _subjects = subjects;
      _records = records;
      _sortSubjects();
      _calculateTotalAttendance();
      _isLoading = false;
    });

    _headerAnimationController.forward();
    _ringAnimationController.forward(from: 0.0);
  }

  void _sortSubjects() {
    final today = DateTime.now().weekday;
    _subjects.sort((a, b) {
      bool aHasClass = a.schedule.any((s) => s.dayOfWeek == today);
      bool bHasClass = b.schedule.any((s) => s.dayOfWeek == today);

      if (aHasClass && !bHasClass) return -1;
      if (!aHasClass && bHasClass) return 1;

      if (aHasClass && bHasClass) {
        final aSlot = a.schedule.firstWhere((s) => s.dayOfWeek == today);
        final bSlot = b.schedule.firstWhere((s) => s.dayOfWeek == today);
        final aMin = aSlot.startTime.hour * 60 + aSlot.startTime.minute;
        final bMin = bSlot.startTime.hour * 60 + bSlot.startTime.minute;
        return aMin.compareTo(bMin);
      }

      return a.name.compareTo(b.name);
    });
  }

  void _calculateTotalAttendance() {
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
    _totalAttended = attendedPoints;
    _totalHeld = totalPoints;

    HomeWidgetService.updateWidget(_totalAttendance);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getFirstName() {
    final user = FirebaseAuth.instance.currentUser;
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName!.split(' ').first;
    }
    return '';
  }

  Future<void> _addSubject(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    String name = '';
    bool isLab = false;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (
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
                  key: formKey,
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
                              activeTrackColor: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
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
                      if (formKey.currentState!.validate()) {
                        formKey.currentState!.save();
                        final newSubject = Subject(
                          name: name,
                          isLab: isLab,
                          color: '#FFFFFF',
                        );
                        try {
                          await LocalDbService.instance.insertSubject(
                            newSubject,
                          );
                          await _loadData();
                          if (buildContext.mounted) {
                            Navigator.pop(buildContext);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to add subject: $e'),
                              ),
                            );
                          }
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

  Color _getStatusColor(double percentage, bool isDark) {
    final threshold = ThresholdService.instance.threshold;
    if (percentage >= threshold) {
      return isDark ? const Color(0xFF30D158) : const Color(0xFF34C759);
    } else if (percentage >= threshold - 15) {
      return isDark ? const Color(0xFFFFD60A) : const Color(0xFFFF9500);
    } else {
      return isDark ? const Color(0xFFFF453A) : const Color(0xFFFF3B30);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ─── Custom Header ─────────────────────────────────
            FadeTransition(
              opacity: _headerFadeAnimation,
              child: SlideTransition(
                position: _headerSlideAnimation,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      // Greeting + name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getFirstName().isNotEmpty
                                  ? _getFirstName()
                                  : 'Attendify',
                              style: GoogleFonts.poppins(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Add subject button
                      _GlassIconButton(
                        icon: Icons.add_rounded,
                        onTap: () => _addSubject(context),
                        isDark: isDark,
                        primaryColor: colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      // Profile avatar
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          );
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.4),
                              width: 2,
                            ),
                            image: user?.photoURL != null
                                ? DecorationImage(
                                    image: NetworkImage(user!.photoURL!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: colorScheme.primaryContainer,
                          ),
                          child: user?.photoURL == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 22,
                                  color: colorScheme.onPrimaryContainer,
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Content ───────────────────────────────────────
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadData(showLoading: false),
                      color: colorScheme.primary,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          // ─── Hero Ring Card ──────────────────
                          _buildHeroCard(context, isDark, colorScheme),

                          const SizedBox(height: 20),

                          // ─── Quick Actions Row ───────────────
                          _buildQuickActions(context, isDark, colorScheme),

                          const SizedBox(height: 24),

                          // ─── Section Title ───────────────────
                          if (_subjects.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Your Subjects',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    '${_subjects.length} total',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // ─── Subject Cards / Empty State ─────
                          if (_subjects.isEmpty) _buildEmptyState(context, isDark, colorScheme),

                          ..._subjects.asMap().entries.map((entry) {
                            final index = entry.key;
                            final subject = entry.value;
                            return _buildSubjectCard(
                              context, subject, index, isDark, colorScheme,
                            );
                          }),

                          // Bottom padding for floating nav bar
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Hero Card with Circular Progress Ring ──────────────────────
  Widget _buildHeroCard(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return AnimatedBuilder(
      animation: _ringAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                      colorScheme.primary.withValues(alpha: 0.15),
                      colorScheme.primary.withValues(alpha: 0.05),
                    ]
                  : [
                      colorScheme.primary.withValues(alpha: 0.08),
                      colorScheme.primary.withValues(alpha: 0.02),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? colorScheme.primary.withValues(alpha: 0.2)
                  : colorScheme.primary.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Circular progress ring
              SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _AttendanceRingPainter(
                    progress: (_totalAttendance / 100).clamp(0.0, 1.0) *
                        _ringAnimation.value,
                    primaryColor: colorScheme.primary,
                    trackColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    strokeWidth: 12,
                    statusColor: _getStatusColor(_totalAttendance, isDark),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(begin: 0.0, end: _totalAttendance),
                          builder: (context, value, child) {
                            return Text(
                              '${value.toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
                                height: 1.1,
                              ),
                            );
                          },
                        ),
                        Text(
                          'Overall',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Stat chips
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatChip(
                    label: 'Attended',
                    value: '$_totalAttended',
                    icon: Icons.check_circle_outline_rounded,
                    color: _getStatusColor(ThresholdService.instance.threshold, isDark),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 16),
                  _StatChip(
                    label: 'Total',
                    value: '$_totalHeld',
                    icon: Icons.calendar_today_rounded,
                    color: colorScheme.primary,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 16),
                  _StatChip(
                    label: 'Subjects',
                    value: '${_subjects.length}',
                    icon: Icons.library_books_rounded,
                    color: isDark
                        ? const Color(0xFFBF5AF2)
                        : const Color(0xFFAF52DE),
                    isDark: isDark,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Quick Actions ──────────────────────────────────────────────
  Widget _buildQuickActions(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Expanded(
          child: _GlassActionButton(
            icon: Icons.calculate_rounded,
            label: 'Safe Bunk',
            isDark: isDark,
            primaryColor: colorScheme.primary,
            onTap: () {
              final Map<String, int> pointsPerSubject = {
                for (var s in _subjects) s.id!: (s.isLab ? 2 : 1),
              };
              int totalPoints = 0;
              int attendedPoints = 0;
              for (var record in _records) {
                final ptsPerSession =
                    pointsPerSubject[record.subjectId] ?? 1;
                totalPoints += record.held * ptsPerSession;
                attendedPoints +=
                    record.attended * ptsPerSession;
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
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassActionButton(
            icon: Icons.school_rounded,
            label: 'GPA Calc',
            isDark: isDark,
            primaryColor: colorScheme.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GPACalculatorScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Subject Card ───────────────────────────────────────────────
  Widget _buildSubjectCard(
    BuildContext context,
    Subject subject,
    int index,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    final percentage = _getSubjectPercentage(subject);
    final attended = _getSubjectAttendedSessions(subject);
    final total = _getSubjectTotalSessions(subject);
    final statusColor = _getStatusColor(percentage, isDark);

    final cardColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 80)),
      curve: Curves.easeOut,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(0, 24 * (1 - animValue)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Dismissible(
          key: ValueKey(subject.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: isDark ? 0.3 : 0.15),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_rounded, color: Colors.red.shade400, size: 28),
                const SizedBox(height: 4),
                Text(
                  'Delete',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade400,
                  ),
                ),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (BuildContext ctx) => AlertDialog(
                title: Text(
                  'Delete Subject',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                content: Text(
                  'Delete "${subject.name}" and all its attendance records?',
                  style: GoogleFonts.poppins(),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: Text('Delete', style: GoogleFonts.poppins()),
                  ),
                ],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          },
          onDismissed: (direction) async {
            try {
              await LocalDbService.instance.deleteSubject(subject.id!);
              _loadData(showLoading: false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${subject.name} deleted')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete: $e')),
                );
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Color accent stripe
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        bottomLeft: Radius.circular(22),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 8, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  subject.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              // Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: isDark ? 0.15 : 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  subject.isLab ? 'Lab' : 'Lecture',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '$attended / $total sessions',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Mini ring
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: CustomPaint(
                        painter: _AttendanceRingPainter(
                          progress: (percentage / 100).clamp(0.0, 1.0),
                          primaryColor: statusColor,
                          trackColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          strokeWidth: 5,
                          statusColor: statusColor,
                        ),
                        child: Center(
                          child: Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Empty State ────────────────────────────────────────────────
  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.school_rounded,
              size: 40,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No subjects yet',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first subject to start\ntracking your attendance',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _addSubject(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              'Add Subject',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  CUSTOM WIDGETS
// ═══════════════════════════════════════════════════════════════════

/// Circular attendance ring painter
class _AttendanceRingPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color trackColor;
  final double strokeWidth;
  final Color statusColor;

  _AttendanceRingPainter({
    required this.progress,
    required this.primaryColor,
    required this.trackColor,
    required this.strokeWidth,
    required this.statusColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [
          statusColor.withValues(alpha: 0.6),
          statusColor,
        ],
        stops: const [0.0, 1.0],
        transform: const GradientRotation(-pi / 2),
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * progress,
        false,
        progressPaint,
      );

      // Glow dot at the end
      final angle = -pi / 2 + 2 * pi * progress;
      final dotX = center.dx + radius * cos(angle);
      final dotY = center.dy + radius * sin(angle);

      final dotPaint = Paint()
        ..color = statusColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawCircle(Offset(dotX, dotY), strokeWidth / 2 + 1, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.statusColor != statusColor;
  }
}

/// Stat chip shown below the hero ring
class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

/// Frosted glass action button
class _GlassActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color primaryColor;
  final VoidCallback onTap;

  const _GlassActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: primaryColor),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glass-style icon button for the header
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final Color primaryColor;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : primaryColor.withValues(alpha: 0.15),
          ),
        ),
        child: Icon(
          icon,
          size: 22,
          color: primaryColor,
        ),
      ),
    );
  }
}
