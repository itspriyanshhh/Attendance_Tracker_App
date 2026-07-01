import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GPACalculatorScreen extends StatefulWidget {
  const GPACalculatorScreen({super.key});

  @override
  State<GPACalculatorScreen> createState() => _GPACalculatorScreenState();
}

class _GPACalculatorScreenState extends State<GPACalculatorScreen>
    with SingleTickerProviderStateMixin {
  // SGPA State
  final List<CourseInput> _courses = [];
  double _calculatedSGPA = 0.0;

  // CGPA State
  final _currentCGPAController = TextEditingController();
  final _creditsCompletedController = TextEditingController();
  double _predictedCGPA = 0.0;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _courses.add(CourseInput());
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    for (var course in _courses) {
      course.marksController.dispose();
    }
    _currentCGPAController.dispose();
    _creditsCompletedController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _addCourse() {
    setState(() {
      _courses.add(CourseInput());
    });
    _calculateSGPA();
    _calculateCGPA();
  }

  void _removeCourse(int index) {
    if (_courses.length > 1) {
      setState(() {
        _courses[index].marksController.dispose();
        _courses.removeAt(index);
      });
      _calculateSGPA();
      _calculateCGPA();
    }
  }

  void _calculateSGPA() {
    double totalPoints = 0;
    double totalCredits = 0;

    for (var course in _courses) {
      double? marks = course.marks;
      if (marks != null && marks >= 0 && marks <= 100) {
        totalPoints += course.credits * _getGradePoint(marks);
        totalCredits += course.credits;
      } else {
        totalCredits += course.credits;
      }
    }

    setState(() {
      _calculatedSGPA = totalCredits > 0 ? totalPoints / totalCredits : 0.0;
    });
  }

  void _calculateCGPA() {
    double currentCGPA = double.tryParse(_currentCGPAController.text) ?? 0.0;
    double creditsCompleted =
        double.tryParse(_creditsCompletedController.text) ?? 0.0;

    double currentTotalPoints = currentCGPA * creditsCompleted;

    double semesterPoints = 0;
    double semesterCredits = 0;

    for (var course in _courses) {
      double? marks = course.marks;
      if (marks != null && marks >= 0 && marks <= 100) {
        semesterPoints += course.credits * _getGradePoint(marks);
        semesterCredits += course.credits;
      } else {
        semesterCredits += course.credits;
      }
    }

    double newTotalPoints = currentTotalPoints + semesterPoints;
    double newTotalCredits = creditsCompleted + semesterCredits;

    setState(() {
      _predictedCGPA = newTotalCredits > 0
          ? newTotalPoints / newTotalCredits
          : 0.0;
    });
  }

  String _getGrade(double? marks) {
    if (marks == null) return 'F';
    if (marks > 100 || marks < 0) return 'Invalid';
    if (marks >= 90 && marks <= 100) return 'O';
    if (marks >= 75 && marks < 90) return 'A+';
    if (marks >= 65 && marks < 75) return 'A';
    if (marks >= 55 && marks < 65) return 'B+';
    if (marks >= 50 && marks < 55) return 'B';
    if (marks >= 45 && marks < 50) return 'C';
    if (marks >= 40 && marks < 45) return 'P';
    return 'F';
  }

  int _getGradePoint(double? marks) {
    if (marks == null || marks > 100 || marks < 0) return 0;
    if (marks >= 90 && marks <= 100) return 10;
    if (marks >= 75 && marks < 90) return 9;
    if (marks >= 65 && marks < 75) return 8;
    if (marks >= 55 && marks < 65) return 7;
    if (marks >= 50 && marks < 55) return 6;
    if (marks >= 45 && marks < 50) return 5;
    if (marks >= 40 && marks < 45) return 4;
    return 0;
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'O':
        return const Color(0xFF2E7D32);
      case 'A+':
        return const Color(0xFF43A047);
      case 'A':
        return const Color(0xFF66BB6A);
      case 'B+':
        return const Color(0xFF1565C0);
      case 'B':
        return const Color(0xFF00897B);
      case 'C':
        return const Color(0xFFFF8F00);
      case 'P':
        return const Color(0xFFEF6C00);
      case 'F':
      case 'Invalid':
      default:
        return const Color(0xFFD32F2F);
    }
  }

  void _showGradingSystemLegend() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.school_rounded,
                            color: theme.colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Grading System',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Grade rows
                    ...([
                      ['90 – 100', 'O', '10', const Color(0xFF2E7D32)],
                      ['75 – 89', 'A+', '9', const Color(0xFF43A047)],
                      ['65 – 74', 'A', '8', const Color(0xFF66BB6A)],
                      ['55 – 64', 'B+', '7', const Color(0xFF1565C0)],
                      ['50 – 54', 'B', '6', const Color(0xFF00897B)],
                      ['45 – 49', 'C', '5', const Color(0xFFFF8F00)],
                      ['40 – 44', 'P', '4', const Color(0xFFEF6C00)],
                      ['< 40', 'F', '0', const Color(0xFFD32F2F)],
                    ].map((item) {
                      final color = item[3] as Color;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: isDark ? 0.15 : 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: color.withValues(alpha: isDark ? 0.3 : 0.12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  item[1] as String,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                '${item[0]} marks',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${item[2]} GP',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    })),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Grade P (GP 4) is the passing grade. Below that, GP is 0.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'GPA Calculator',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showGradingSystemLegend,
            icon: const Icon(Icons.school_rounded),
            tooltip: 'Grading System',
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: colorScheme.onPrimary,
              unselectedLabelColor: colorScheme.onSurfaceVariant,
              labelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.all(4),
              tabs: const [
                Tab(text: 'SGPA', height: 40),
                Tab(text: 'CGPA Predictor', height: 40),
              ],
            ),
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSGPATab(theme, colorScheme, isDark),
                _buildCGPATab(theme, colorScheme, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SGPA Tab
  // ---------------------------------------------------------------------------
  Widget _buildSGPATab(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Result card at the top
        _buildGPAResultCard(
          label: 'Semester GPA',
          value: _calculatedSGPA,
          color: colorScheme.primary,
          isDark: isDark,
          theme: theme,
        ),
        const SizedBox(height: 20),

        // Section header
        Row(
          children: [
            Text(
              'Subjects',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_courses.length}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addCourse,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Add',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Course cards
        ..._courses.asMap().entries.map((entry) {
          int idx = entry.key;
          CourseInput course = entry.value;
          return _buildCourseCard(idx, course, theme, colorScheme, isDark);
        }),

        const SizedBox(height: 16),

        // Calculate button
        _buildCalculateButton(
          onPressed: () {
            _calculateSGPA();
            _calculateCGPA();
          },
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CGPA Tab
  // ---------------------------------------------------------------------------
  Widget _buildCGPATab(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        // Result card
        _buildGPAResultCard(
          label: 'Predicted CGPA',
          value: _predictedCGPA,
          color: const Color(0xFF7C4DFF),
          isDark: isDark,
          theme: theme,
        ),
        const SizedBox(height: 24),

        // Info hint
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Enter your current CGPA and total credits, then add subjects in the SGPA tab to predict your new CGPA.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Input fields
        Text(
          'Previous Performance',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildStyledInput(
                controller: _currentCGPAController,
                label: 'Current CGPA',
                hint: 'e.g. 8.5',
                icon: Icons.trending_up_rounded,
                colorScheme: colorScheme,
                isDark: isDark,
                isDecimal: true,
                onChanged: (_) => _calculateCGPA(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStyledInput(
                controller: _creditsCompletedController,
                label: 'Credits Done',
                hint: 'e.g. 120',
                icon: Icons.credit_score_rounded,
                colorScheme: colorScheme,
                isDark: isDark,
                isDecimal: false,
                onChanged: (_) => _calculateCGPA(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Current semester summary
        Text(
          'Current Semester',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              _buildCGPAStat(
                label: 'Subjects',
                value: '${_courses.length}',
                icon: Icons.menu_book_rounded,
                colorScheme: colorScheme,
              ),
              _buildVerticalDivider(colorScheme),
              _buildCGPAStat(
                label: 'Semester Credits',
                value: '${_courses.fold<int>(0, (sum, c) => sum + c.credits)}',
                icon: Icons.star_rounded,
                colorScheme: colorScheme,
              ),
              _buildVerticalDivider(colorScheme),
              _buildCGPAStat(
                label: 'SGPA',
                value: _calculatedSGPA.toStringAsFixed(2),
                icon: Icons.insights_rounded,
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Shared widgets
  // ---------------------------------------------------------------------------

  /// Circular gauge GPA result card
  Widget _buildGPAResultCard({
    required String label,
    required double value,
    required Color color,
    required bool isDark,
    required ThemeData theme,
  }) {
    final percentage = (value / 10.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  color.withValues(alpha: 0.15),
                  color.withValues(alpha: 0.05),
                ]
              : [
                  color.withValues(alpha: 0.08),
                  color.withValues(alpha: 0.02),
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.15),
        ),
      ),
      child: Row(
        children: [
          // Circular gauge
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _GPAGaugePainter(
                progress: percentage,
                color: color,
                backgroundColor: color.withValues(alpha: isDark ? 0.15 : 0.1),
                strokeWidth: 10,
              ),
              child: Center(
                child: Text(
                  value.toStringAsFixed(2),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'out of 10.0',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                // Mini performance indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: color.withValues(alpha: isDark ? 0.15 : 0.1),
                    color: color,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getPerformanceLabel(value),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPerformanceLabel(double gpa) {
    if (gpa >= 9.0) return '🏆 Outstanding';
    if (gpa >= 8.0) return '🌟 Excellent';
    if (gpa >= 7.0) return '👏 Very Good';
    if (gpa >= 6.0) return '👍 Good';
    if (gpa >= 5.0) return '📈 Average';
    if (gpa > 0) return '⚠️ Needs Improvement';
    return '—';
  }

  /// Individual course card
  Widget _buildCourseCard(
    int index,
    CourseInput course,
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    String grade = _getGrade(course.marks);
    int gp = _getGradePoint(course.marks);
    Color gradeColor = _getGradeColor(grade);
    final hasMarks = course.marks != null &&
        course.marks! >= 0 &&
        course.marks! <= 100;

    return Padding(
      key: ValueKey(course),
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.4 : 0.35,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasMarks
                ? gradeColor.withValues(alpha: 0.2)
                : colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              // Top row: Subject number + grade badge + delete
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Subject ${index + 1}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  // Grade pill
                  if (hasMarks)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: gradeColor.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: gradeColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            grade,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: gradeColor,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: 1,
                            height: 14,
                            color: gradeColor.withValues(alpha: 0.3),
                          ),
                          Text(
                            '$gp',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: gradeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_courses.length > 1) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: Colors.red.shade400,
                      onPressed: () => _removeCourse(index),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              // Input row
              Row(
                children: [
                  // Credits chips
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Credits',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [1, 2, 3, 4, 5, 6].map((c) {
                            final selected = course.credits == c;
                            return GestureDetector(
                              onTap: () {
                                setState(() => course.credits = c);
                                _calculateSGPA();
                                _calculateCGPA();
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? colorScheme.primary
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                  border: selected
                                      ? null
                                      : Border.all(
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.4),
                                        ),
                                ),
                                child: Center(
                                  child: Text(
                                    '$c',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? colorScheme.onPrimary
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Marks input
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: course.marksController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Marks',
                        hintText: '0 – 100',
                        isDense: true,
                        filled: true,
                        fillColor: colorScheme.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (v) {
                        setState(() {});
                        _calculateSGPA();
                        _calculateCGPA();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStyledInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required ColorScheme colorScheme,
    required bool isDark,
    required bool isDecimal,
    required ValueChanged<String> onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildCalculateButton({
    required VoidCallback onPressed,
    required ColorScheme colorScheme,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.calculate_rounded, size: 22),
        label: Text(
          'Calculate GPA',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildCGPAStat({
    required String label,
    required String value,
    required IconData icon,
    required ColorScheme colorScheme,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(ColorScheme colorScheme) {
    return Container(
      width: 1,
      height: 40,
      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
    );
  }
}

// ---------------------------------------------------------------------------
// Circular gauge painter
// ---------------------------------------------------------------------------

class _GPAGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  _GPAGaugePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background arc
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * 0.75, // start at ~135 degrees
      math.pi * 1.5, // sweep 270 degrees
      false,
      bgPaint,
    );

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi * 0.75,
        math.pi * 1.5 * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GPAGaugePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class CourseInput {
  int credits;
  final TextEditingController marksController;

  CourseInput({this.credits = 3, String initialMarks = ''})
      : marksController = TextEditingController(text: initialMarks);

  double? get marks => double.tryParse(marksController.text);
}
