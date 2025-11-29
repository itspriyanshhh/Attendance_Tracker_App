import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GPACalculatorScreen extends StatefulWidget {
  const GPACalculatorScreen({super.key});

  @override
  State<GPACalculatorScreen> createState() => _GPACalculatorScreenState();
}

class _GPACalculatorScreenState extends State<GPACalculatorScreen> {
  // SGPA State
  final List<CourseInput> _courses = [CourseInput()];
  double _calculatedSGPA = 0.0;

  // CGPA State
  final _currentCGPAController = TextEditingController();
  final _creditsCompletedController = TextEditingController();
  double _predictedCGPA = 0.0;

  void _addCourse() {
    setState(() {
      _courses.add(CourseInput());
    });
  }

  void _removeCourse(int index) {
    if (_courses.length > 1) {
      setState(() {
        _courses.removeAt(index);
      });
    }
  }

  void _calculateSGPA() {
    double totalPoints = 0;
    double totalCredits = 0;

    for (var course in _courses) {
      totalPoints += course.credits * _getGradePoint(course.grade);
      totalCredits += course.credits;
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
      semesterPoints += course.credits * _getGradePoint(course.grade);
      semesterCredits += course.credits;
    }

    double newTotalPoints = currentTotalPoints + semesterPoints;
    double newTotalCredits = creditsCompleted + semesterCredits;

    setState(() {
      _predictedCGPA = newTotalCredits > 0
          ? newTotalPoints / newTotalCredits
          : 0.0;
    });
  }

  int _getGradePoint(String grade) {
    switch (grade) {
      case 'S':
        return 10;
      case 'A':
        return 9;
      case 'B':
        return 8;
      case 'C':
        return 7;
      case 'D':
        return 6;
      case 'E':
        return 5;
      case 'F':
        return 0;
      default:
        return 0;
    }
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
            // SGPA Section
            Text(
              'Semester GPA (SGPA)',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            ..._courses.asMap().entries.map((entry) {
              int idx = entry.key;
              CourseInput course = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<int>(
                        value: course.credits,
                        decoration: InputDecoration(
                          labelText: 'Credits',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [1, 2, 3, 4, 5]
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.toString()),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => course.credits = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: course.grade,
                        decoration: InputDecoration(
                          labelText: 'Grade',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: ['S', 'A', 'B', 'C', 'D', 'E', 'F']
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => course.grade = v!),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.red,
                      onPressed: () => _removeCourse(idx),
                    ),
                  ],
                ),
              );
            }).toList(),
            TextButton.icon(
              onPressed: _addCourse,
              icon: const Icon(Icons.add),
              label: const Text('Add Subject'),
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
                color: colorScheme.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
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
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        _calculatedSGPA.toStringAsFixed(2),
                        style: GoogleFonts.poppins(
                          fontSize: 32,
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
            const SizedBox(height: 8),
            Text(
              'Predict your new CGPA based on the above SGPA.',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _currentCGPAController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Current CGPA',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
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
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                      Text(
                        _predictedCGPA.toStringAsFixed(2),
                        style: GoogleFonts.poppins(
                          fontSize: 32,
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
  String grade;

  CourseInput({this.credits = 3, this.grade = 'A'});
}
