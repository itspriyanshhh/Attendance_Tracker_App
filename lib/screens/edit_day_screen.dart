import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/local_db_service.dart';
import 'package:attendance_management/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    List<Subject> subjects = await LocalDbService.instance.getAllSubjects();
    List<AttendanceRecord> records = await LocalDbService.instance
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
      await LocalDbService.instance.updateRecord(record);
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
              title: Text(
                'Add Record',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Subject>(
                    value: selectedSubject,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (Subject? newValue) {
                      dialogSetState(() => selectedSubject = newValue);
                    },
                    items: availableSubjects.map((Subject subject) {
                      return DropdownMenuItem<Subject>(
                        value: subject,
                        child: Text(subject.name, style: GoogleFonts.poppins()),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Sessions Held',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => heldText = value,
                    style: GoogleFonts.poppins(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Sessions Attended',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => attendedText = value,
                    style: GoogleFonts.poppins(),
                  ),
                ],
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
                      await LocalDbService.instance.insertRecord(newRecord);
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

  Future<void> _deleteRecord(AttendanceRecord record) async {
    Subject? subject = _subjects.firstWhere(
      (s) => s.id == record.subjectId,
      orElse: () => Subject(name: 'Unknown'),
    );

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(
          'Delete Record',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete the attendance record for ${subject.name} on ${_formatDate(record.date)}?',
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
        await LocalDbService.instance.deleteRecord(record.id!);
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit ${_formatDate(widget.date)}',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton.filled(
              icon: const Icon(Icons.save),
              tooltip: 'Save Changes',
              onPressed: _saveChanges,
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: true,
        child: _dayRecords.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 64,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No records for this day',
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
                itemCount: _dayRecords.length,
                itemBuilder: (context, index) {
                  AttendanceRecord record = _dayRecords[index];
                  Subject? subject = _subjects.firstWhere(
                    (s) => s.id == record.subjectId,
                    orElse: () => Subject(name: 'Unknown'),
                  );
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  subject.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red,
                                ),
                                onPressed: () => _deleteRecord(record),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Held',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _heldControllers[record.id],
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.poppins(),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Attended',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller:
                                          _attendedControllers[record.id],
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                      ),
                                      keyboardType: TextInputType.number,
                                      style: GoogleFonts.poppins(),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
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
