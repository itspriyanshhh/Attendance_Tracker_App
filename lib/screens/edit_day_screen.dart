import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:attendance_management/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditDayScreen extends StatefulWidget {
  final String date;

  const EditDayScreen({super.key, required this.date});

  @override
  State<EditDayScreen> createState() => _EditDayScreenState();
}

class _EditDayScreenState extends State<EditDayScreen> {
  List<Subject> _subjects = [];
  List<AttendanceRecord> _dayRecords = [];
  Map<String, TextEditingController> _heldControllers = {};
  Map<String, TextEditingController> _attendedControllers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    List<Subject> subjects = await FirestoreService.instance.getAllSubjects();
    List<AttendanceRecord> records = await FirestoreService.instance
        .getRecordsForDate(widget.date);
    setState(() {
      _subjects = subjects;
      _dayRecords = records;
      _heldControllers.clear();
      _attendedControllers.clear();
      for (var record in _dayRecords) {
        _heldControllers[record.id!] = TextEditingController(
          text: record.held.toString(),
        );
        _attendedControllers[record.id!] = TextEditingController(
          text: record.attended.toString(),
        );
      }
    });
  }

  Future<void> _saveChanges() async {
    bool valid = true;
    for (var record in _dayRecords) {
      int? newHeld = int.tryParse(_heldControllers[record.id!]!.text);
      int? newAttended = int.tryParse(_attendedControllers[record.id!]!.text);
      if (newHeld == null ||
          newAttended == null ||
          newAttended > newHeld ||
          newHeld < 0 ||
          newAttended < 0) {
        valid = false;
        break;
      }
      record.held = newHeld;
      record.attended = newAttended;
      await FirestoreService.instance.updateRecord(record);
    }
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid input: attended <= held, non-negative'),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _addNewRecord() async {
    List<Subject> availableSubjects = _subjects
        .where((s) => !_dayRecords.any((r) => r.subjectId == s.id))
        .toList();
    if (availableSubjects.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No more subjects to add')));
      return;
    }

    Subject? selectedSubject = availableSubjects.first;
    String heldText = '1';
    String attendedText = '0';

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter dialogSetState) =>
            AlertDialog(
              title: const Text('Add Record'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<Subject>(
                    value: selectedSubject,
                    onChanged: (Subject? newValue) {
                      dialogSetState(() => selectedSubject = newValue);
                    },
                    items: availableSubjects.map((Subject subject) {
                      return DropdownMenuItem<Subject>(
                        value: subject,
                        child: Text(subject.name),
                      );
                    }).toList(),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Sessions Held',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => heldText = value,
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Sessions Attended',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => attendedText = value,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    int? held = int.tryParse(heldText);
                    int? attended = int.tryParse(attendedText);
                    if (held != null &&
                        attended != null &&
                        attended <= held &&
                        held >= 0 &&
                        attended >= 0) {
                      AttendanceRecord newRecord = AttendanceRecord(
                        subjectId: selectedSubject!.id!,
                        date: widget.date,
                        held: held,
                        attended: attended,
                      );
                      await FirestoreService.instance.insertRecord(newRecord);
                      AttendanceMonitor.instance.checkSubject(
                        newRecord.subjectId,
                      );

                      _loadData();
                      Navigator.pop(dialogContext);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid input')),
                      );
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
      ),
    );
  }

  Future<void> _deleteRecord(AttendanceRecord record) async {
    Subject? subject = _subjects.firstWhere(
      (s) => s.id == record.subjectId,
      orElse: () => Subject(name: 'Unknown'),
    );

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text(
          'Are you sure you want to delete the attendance record for ${subject.name} on ${_formatDate(record.date)}?',
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
        await FirestoreService.instance.deleteRecord(record.id!);
        _loadData();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Record deleted successfully')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete record: $e')));
      }
    }
  }

  String _formatDate(String date) {
    return DateFormat('MMMM d, yyyy').format(DateTime.parse(date));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${_formatDate(widget.date)}'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveChanges),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: _dayRecords.isEmpty
            ? const Center(child: Text('No records for this day.'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _dayRecords.length,
                itemBuilder: (context, index) {
                  AttendanceRecord record = _dayRecords[index];
                  Subject? subject = _subjects.firstWhere(
                    (s) => s.id == record.subjectId,
                    orElse: () => Subject(name: 'Unknown'),
                  );
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                subject.name,
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineMedium,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteRecord(record),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _heldControllers[record.id],
                                  decoration: const InputDecoration(
                                    labelText: 'Held',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: _attendedControllers[record.id],
                                  decoration: const InputDecoration(
                                    labelText: 'Attended',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewRecord,
        child: const Icon(Icons.add),
      ),
    );
  }
}
