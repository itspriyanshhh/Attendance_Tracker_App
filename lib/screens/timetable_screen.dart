import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/screens/paywall_screen.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:attendance_management/services/notification_service.dart';
import 'package:attendance_management/services/subscription_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<Subject> _subjects = [];
  bool _isLoading = true;
  bool _isLocked = false;

  // 1 = Mon, 7 = Sun
  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _checkAccessAndLoad();
  }

  Future<void> _checkAccessAndLoad() async {
    // Check if user has access to timetable
    final hasAccess = await SubscriptionService.instance.hasFeatureAccess(
      'timetable',
    );

    if (!hasAccess && mounted) {
      // Set loading to false before showing paywall
      setState(() => _isLoading = false);

      // Navigate to paywall
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallScreen()),
      );

      // If user subscribed, reload
      if (result == true && mounted) {
        setState(() => _isLoading = true);
        _loadSubjects();
      } else {
        // User didn't subscribe, keep locked state
        if (mounted) setState(() => _isLocked = true);
      }
    } else {
      _loadSubjects();
    }
  }

  Future<void> _loadSubjects() async {
    final subjects = await FirestoreService.instance.getAllSubjects();
    setState(() {
      _subjects = subjects;
      _isLoading = false;
    });
  }

  Future<void> _addSlot(int dayIndex) async {
    // Show dialog to pick subject and time
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    Subject? selectedSubject;

    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subjects available. Add subjects first.'),
        ),
      );
      return;
    }

    selectedSubject = _subjects.first;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Class on ${_days[dayIndex - 1]}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<Subject>(
                value: selectedSubject,
                isExpanded: true,
                items: _subjects.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.name));
                }).toList(),
                onChanged: (val) => setDialogState(() => selectedSubject = val),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Time'),
                trailing: Text(selectedTime.format(context)),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (t != null) {
                    setDialogState(() => selectedTime = t);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Add slot to subject
                if (selectedSubject != null) {
                  final newSlot = ScheduleSlot(
                    dayOfWeek: dayIndex,
                    startTime: selectedTime,
                  );

                  // Update subject in local list and Firestore
                  // We need to update the specific subject instance
                  final subjectIndex = _subjects.indexWhere(
                    (s) => s.id == selectedSubject!.id,
                  );
                  if (subjectIndex != -1) {
                    final updatedSubject = _subjects[subjectIndex];
                    updatedSubject.schedule.add(newSlot);

                    // Sort schedule by day then time
                    updatedSubject.schedule.sort((a, b) {
                      if (a.dayOfWeek != b.dayOfWeek)
                        return a.dayOfWeek.compareTo(b.dayOfWeek);
                      final aMin = a.startTime.hour * 60 + a.startTime.minute;
                      final bMin = b.startTime.hour * 60 + b.startTime.minute;
                      return aMin.compareTo(bMin);
                    });

                    await FirestoreService.instance.updateSubject(
                      updatedSubject,
                    );

                    // Reschedule notifications
                    await NotificationService.instance.scheduleClassReminders(
                      _subjects,
                    );

                    setState(() {}); // refresh UI
                  }
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAllTimetables() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete All Timetables?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will remove all class schedules for all subjects. This action cannot be undone.',
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete All', style: GoogleFonts.poppins()),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await FirestoreService.instance.clearAllTimetables();
        await _loadSubjects();
        // Clear notifications
        await NotificationService.instance.cancelAll();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All timetables deleted successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete timetables: $e')),
          );
        }
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeSlot(Subject subject, ScheduleSlot slot) async {
    subject.schedule.remove(slot);
    await FirestoreService.instance.updateSubject(subject);
    await NotificationService.instance.scheduleClassReminders(_subjects);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Timetable',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Premium Feature',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upgrade to access the timetable',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PaywallScreen()),
                  );
                  if (result == true && mounted) {
                    setState(() {
                      _isLocked = false;
                      _isLoading = true;
                    });
                    _loadSubjects();
                  }
                },
                child: Text('Unlock Now', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Timetable',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: 'Delete All Timetables',
            onPressed: _deleteAllTimetables,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 7,
              itemBuilder: (context, index) {
                final dayNum = index + 1;
                final dayName = _days[index];

                // Find all slots for this day across all subjects
                List<Map<String, dynamic>> daySlots = [];
                for (var subject in _subjects) {
                  for (var slot in subject.schedule) {
                    if (slot.dayOfWeek == dayNum) {
                      daySlots.add({'subject': subject, 'slot': slot});
                    }
                  }
                }

                // Sort by time
                daySlots.sort((a, b) {
                  final slotA = a['slot'] as ScheduleSlot;
                  final slotB = b['slot'] as ScheduleSlot;
                  final minA =
                      slotA.startTime.hour * 60 + slotA.startTime.minute;
                  final minB =
                      slotB.startTime.hour * 60 + slotB.startTime.minute;
                  return minA.compareTo(minB);
                });

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
                              dayName,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle_outline,
                                color: Colors.indigo,
                              ),
                              onPressed: () => _addSlot(dayNum),
                            ),
                          ],
                        ),
                        if (daySlots.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No classes',
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          )
                        else
                          ...daySlots.map((item) {
                            final subject = item['subject'] as Subject;
                            final slot = item['slot'] as ScheduleSlot;
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 4,
                                height: 40,
                                color: subject.isLab
                                    ? Colors.orange
                                    : Colors.blue,
                              ),
                              title: Text(
                                subject.name,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                slot.startTime.format(context),
                                style: GoogleFonts.poppins(
                                  color: Colors.grey[600],
                                ),
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removeSlot(subject, slot),
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
