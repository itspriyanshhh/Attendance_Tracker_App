import 'dart:io';
import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/local_db_service.dart';
import 'package:attendance_management/services/threshold_service.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  static Future<void> generateAttendanceReport() async {
    final pdf = pw.Document();
    final subjects = await LocalDbService.instance.getAllSubjects();
    final records = await LocalDbService.instance.getAllRecords();

    // Calculate summary data
    int totalClassesHeld = 0;
    int totalClassesAttended = 0;

    // Weighted totals for overall percentage
    int totalWeightedHeld = 0;
    int totalWeightedAttended = 0;

    final subjectStats = <String, Map<String, dynamic>>{};

    for (var subject in subjects) {
      int held = 0;
      int attended = 0;
      for (var record in records) {
        if (record.subjectId == subject.id) {
          held += record.held;
          attended += record.attended;
        }
      }
      subjectStats[subject.id!] = {
        'name': subject.name,
        'held': held,
        'attended': attended,
        'percentage': held == 0 ? 0.0 : (attended / held) * 100,
      };

      totalClassesHeld += held;
      totalClassesAttended += attended;

      // Apply weights: Lab = 2, Lecture = 1
      final weight = subject.isLab ? 2 : 1;
      totalWeightedHeld += held * weight;
      totalWeightedAttended += attended * weight;
    }

    final overallPercentage = totalWeightedHeld == 0
        ? 0.0
        : (totalWeightedAttended / totalWeightedHeld) * 100;

    // Load font
    final font = await PdfGoogleFonts.poppinsRegular();
    final boldFont = await PdfGoogleFonts.poppinsSemiBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          _buildHeader(context),
          pw.SizedBox(height: 20),
          _buildSummary(
            context,
            totalClassesHeld,
            totalClassesAttended,
            overallPercentage,
          ),
          pw.SizedBox(height: 20),
          _buildSubjectTable(context, subjects, subjectStats),
          pw.SizedBox(height: 20),
          pw.Text(
            "Detailed Attendance History",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          _buildDetailedHistory(context, subjects, records),
        ],
        footer: _buildFooter,
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/attendance_report.pdf");
    await file.writeAsBytes(await pdf.save());
    await OpenFile.open(file.path);
  }

  static pw.Widget _buildHeader(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          "Attendance Report",
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          "Generated on: ${DateTime.now().toString().split('.')[0]}",
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildSummary(
    pw.Context context,
    int totalHeld,
    int totalAttended,
    double percentage,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(5),
        color: PdfColors.grey100,
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem("Total Classes", "$totalHeld"),
          _buildSummaryItem("Attended", "$totalAttended"),
          _buildSummaryItem(
            "Overall %",
            "${percentage.toStringAsFixed(1)}%",
            color: percentage >= ThresholdService.instance.threshold ? PdfColors.green700 : PdfColors.red700,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryItem(
    String label,
    String value, {
    PdfColor? color,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: color,
          ),
        ),
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    );
  }

  static pw.Widget _buildSubjectTable(
    pw.Context context,
    List<Subject> subjects,
    Map<String, Map<String, dynamic>> stats,
  ) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellHeight: 30,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
      },
      headers: ['Subject', 'Held', 'Attended', 'Percentage'],
      data: subjects.map((subject) {
        final stat = stats[subject.id]!;
        final percentage = stat['percentage'] as double;
        return [
          subject.name,
          stat['held'],
          stat['attended'],
          "${percentage.toStringAsFixed(1)}%",
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildDetailedHistory(
    pw.Context context,
    List<Subject> subjects,
    List<AttendanceRecord> records,
  ) {
    // Sort records by date descending
    records.sort((a, b) => b.date.compareTo(a.date));

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      cellHeight: 25,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
      },
      headers: ['Date', 'Subject', 'Held', 'Attended'],
      data: records.map((record) {
        final subjectName = subjects
            .firstWhere(
              (s) => s.id == record.subjectId,
              orElse: () => Subject(name: 'Unknown'),
            )
            .name;
        return [record.date, subjectName, record.held, record.attended];
      }).toList(),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        "Page ${context.pageNumber} of ${context.pagesCount}",
        style: const pw.TextStyle(color: PdfColors.grey),
      ),
    );
  }
}
