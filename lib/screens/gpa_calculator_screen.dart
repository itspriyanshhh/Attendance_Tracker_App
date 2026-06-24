import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GPACalculatorScreen extends StatefulWidget {
  const GPACalculatorScreen({super.key});

  @override
  State<GPACalculatorScreen> createState() => _GPACalculatorScreenState();
}

class _GPACalculatorScreenState extends State<GPACalculatorScreen> {
  // SGPA State
  final List<CourseInput> _courses = [];
  double _calculatedSGPA = 0.0;

  // CGPA State
  final _currentCGPAController = TextEditingController();
  final _creditsCompletedController = TextEditingController();
  double _predictedCGPA = 0.0;

  @override
  void initState() {
    super.initState();
    // Add one course by default
    _courses.add(CourseInput());
  }

  @override
  void dispose() {
    for (var course in _courses) {
      course.marksController.dispose();
    }
    _currentCGPAController.dispose();
    _creditsCompletedController.dispose();
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
        return Colors.green.shade800;
      case 'A+':
        return Colors.green;
      case 'A':
        return Colors.lightGreen.shade700;
      case 'B+':
        return Colors.blue.shade700;
      case 'B':
        return Colors.teal;
      case 'C':
        return Colors.amber.shade700;
      case 'P':
        return Colors.orange;
      case 'F':
      case 'Invalid':
      default:
        return Colors.red;
    }
  }

  void _showGradingSystemLegend() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Grading System Reference',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Table(
                    border: TableBorder.all(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    columnWidths: const {
                      0: FlexColumnWidth(2),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                        ),
                        children: [
                          _buildCell('Marks Range', isHeader: true),
                          _buildCell('Grade', isHeader: true),
                          _buildCell('GP', isHeader: true),
                        ],
                      ),
                      _buildRow('90 - 100', 'O', '10'),
                      _buildRow('75 - 89', 'A+', '9'),
                      _buildRow('65 - 74', 'A', '8'),
                      _buildRow('55 - 64', 'B+', '7'),
                      _buildRow('50 - 54', 'B', '6'),
                      _buildRow('45 - 49', 'C', '5'),
                      _buildRow('40 - 44', 'P', '4'),
                      _buildRow('Less than 40', 'F', '0'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Note: Grade P (Grade Point 4) is the course passing grade. For grades below passing, the associated grade points shall be zero.',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 14 : 13,
        ),
      ),
    );
  }

  TableRow _buildRow(String range, String grade, String gp) {
    return TableRow(
      children: [
        _buildCell(range),
        _buildCell(grade),
        _buildCell(gp),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'GPA Calculator',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SGPA Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Semester GPA (SGPA)',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showGradingSystemLegend,
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: Text(
                    'Grading System',
                    style: GoogleFonts.poppins(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Courses List
            ..._courses.asMap().entries.map((entry) {
              int idx = entry.key;
              CourseInput course = entry.value;
              String grade = _getGrade(course.marks);
              int gp = _getGradePoint(course.marks);
              Color gradeColor = _getGradeColor(grade);

              return Padding(
                key: ValueKey(course),
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subject ${idx + 1}',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (_courses.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20),
                                color: Colors.red.shade400,
                                onPressed: () => _removeCourse(idx),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Credits Dropdown
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<int>(
                                initialValue: course.credits,
                                decoration: InputDecoration(
                                  labelText: 'Credits',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                items: [1, 2, 3, 4, 5, 6]
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text('$c Credits'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  setState(() {
                                    course.credits = v!;
                                  });
                                  _calculateSGPA();
                                  _calculateCGPA();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Marks Input
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: course.marksController,
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  labelText: 'Marks (0-100)',
                                  hintText: 'e.g. 85',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                onChanged: (v) {
                                  setState(() {});
                                  _calculateSGPA();
                                  _calculateCGPA();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Grade & GP Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: gradeColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: gradeColor.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    grade,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: gradeColor,
                                    ),
                                  ),
                                  Text(
                                    '$gp GP',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: gradeColor,
                                    ),
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
            }),

            TextButton.icon(
              onPressed: _addCourse,
              icon: const Icon(Icons.add),
              label: Text(
                'Add Subject',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  _calculateSGPA();
                  _calculateCGPA();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Calculate',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        'Estimated SGPA',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _calculatedSGPA.toStringAsFixed(2),
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 48),

            // CGPA Section
            Text(
              'Cumulative GPA (CGPA)',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Predict your new CGPA based on the above SGPA.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _currentCGPAController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Current CGPA',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => _calculateCGPA(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _creditsCompletedController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Credits Completed',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (v) => _calculateCGPA(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colorScheme.secondary.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        'Predicted CGPA',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _predictedCGPA.toStringAsFixed(2),
                        style: GoogleFonts.poppins(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.secondary,
                        ),
                      ),
                    ],
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

class CourseInput {
  int credits;
  final TextEditingController marksController;

  CourseInput({this.credits = 3, String initialMarks = ''})
      : marksController = TextEditingController(text: initialMarks);

  double? get marks => double.tryParse(marksController.text);
}
