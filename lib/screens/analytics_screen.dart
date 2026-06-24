import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/local_db_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: unused_import
import 'package:intl/intl.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _isLoading = true;

  List<Subject> _subjects = [];
  List<AttendanceRecord> _records = [];

  // Chart Data
  List<FlSpot> _trendSpots = [];
  double _minY = 0;
  double _maxY = 100;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final subjects = await LocalDbService.instance.getAllSubjects();
      final records = await LocalDbService.instance.getAllRecords();

      setState(() {
        _subjects = subjects;
        _records = records;
        _prepareChartData();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _prepareChartData() {
    if (_records.isEmpty) return;

    // Sort records by date
    _records.sort((a, b) => a.date.compareTo(b.date));

    // Calculate cumulative percentage over time
    // We'll take the last 30 distinct dates with records
    final Map<String, List<AttendanceRecord>> recordsByDate = {};
    for (var r in _records) {
      recordsByDate.putIfAbsent(r.date, () => []).add(r);
    }

    final sortedDates = recordsByDate.keys.toList()..sort();
    // Take last 15 dates for cleaner chart
    final datesToShow = sortedDates.length > 15
        ? sortedDates.sublist(sortedDates.length - 15)
        : sortedDates;

    List<FlSpot> spots = [];

    // Running totals
    int runningHeld = 0;
    int runningAttended = 0;

    // Pre-calculate totals before the window if we are slicing
    if (sortedDates.length > 15) {
      final preDates = sortedDates.sublist(0, sortedDates.length - 15);
      for (var date in preDates) {
        for (var r in recordsByDate[date]!) {
          final weight = _getSubjectWeight(r.subjectId);
          runningHeld += r.held * weight;
          runningAttended += r.attended * weight;
        }
      }
    }

    for (int i = 0; i < datesToShow.length; i++) {
      final date = datesToShow[i];
      for (var r in recordsByDate[date]!) {
        final weight = _getSubjectWeight(r.subjectId);
        runningHeld += r.held * weight;
        runningAttended += r.attended * weight;
      }

      final pct = runningHeld > 0 ? (runningAttended / runningHeld) * 100 : 0.0;
      spots.add(FlSpot(i.toDouble(), pct));
    }

    _trendSpots = spots;
    if (spots.isNotEmpty) {
      // Add a bit of padding to Y axis
      final yValues = spots.map((e) => e.y).toList();
      _minY = (yValues.reduce((a, b) => a < b ? a : b) - 5).clamp(0.0, 100.0);
      _maxY = (yValues.reduce((a, b) => a > b ? a : b) + 5).clamp(0.0, 100.0);
    }
  }

  int _getSubjectWeight(String subjectId) {
    final subject = _subjects.firstWhere(
      (s) => s.id == subjectId,
      orElse: () => Subject(name: 'Unknown'),
    );
    return subject.isLab ? 2 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // ignore: unused_local_variable
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Analytics',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
          ? Center(
              child: Text(
                'Not enough data yet',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Attendance Trend'),
                  const SizedBox(height: 16),
                  Container(
                    height: 250,
                    padding: const EdgeInsets.only(
                      right: 16,
                      top: 16,
                      bottom: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: colorScheme.outlineVariant.withOpacity(0.2),
                            strokeWidth: 1,
                            dashArray: [5, 5], // Dashed grid lines
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 20,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}%',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (_trendSpots.length - 1).toDouble(),
                        minY: _minY,
                        maxY: _maxY,
                        // Tooltip Configuration
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) =>
                                colorScheme.surfaceContainerHighest,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((
                                LineBarSpot touchedSpot,
                              ) {
                                return LineTooltipItem(
                                  '${touchedSpot.y.toStringAsFixed(1)}%',
                                  GoogleFonts.poppins(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        // 75% Threshold Line
                        extraLinesData: ExtraLinesData(
                          horizontalLines: [
                            HorizontalLine(
                              y: 75,
                              color: Colors.green.withOpacity(0.5),
                              strokeWidth: 2,
                              dashArray: [10, 5],
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                padding: const EdgeInsets.only(
                                  right: 5,
                                  bottom: 5,
                                ),
                                style: GoogleFonts.poppins(
                                  color: Colors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                labelResolver: (line) => '75%',
                              ),
                            ),
                          ],
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _trendSpots,
                            isCurved: true,
                            color: colorScheme.primary,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: colorScheme.surface,
                                  strokeWidth: 2,
                                  strokeColor: colorScheme.primary,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  colorScheme.primary.withOpacity(0.3),
                                  colorScheme.primary.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  _buildSectionTitle('Subject Performance'),
                  const SizedBox(height: 16),
                  _buildSubjectBarChart(context),

                  const SizedBox(height: 32),
                  _buildSectionTitle('Insights'),
                  const SizedBox(height: 16),
                  _buildInsightsList(context),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSubjectBarChart(BuildContext context) {
    final theme = Theme.of(context);

    // Prepare data
    final List<Map<String, dynamic>> data = [];
    for (var s in _subjects) {
      final sRecords = _records.where((r) => r.subjectId == s.id);
      final total = sRecords.fold(0, (sum, r) => sum + r.held);
      final attended = sRecords.fold(0, (sum, r) => sum + r.attended);
      final pct = total > 0 ? (attended / total) * 100 : 0.0;
      data.add({'name': s.name, 'pct': pct, 'isLab': s.isLab});
    }

    // Sort by percentage ascending (worst first)
    data.sort((a, b) => (a['pct'] as double).compareTo(b['pct'] as double));

    return Column(
      children: data.map((d) {
        final pct = d['pct'] as double;
        final color = pct >= 75
            ? const Color(0xFF34C759) // Green
            : const Color(0xFFFF3B30); // Red

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      d['name'],
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: color,
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInsightsList(BuildContext context) {
    final insights = <Widget>[];

    for (var s in _subjects) {
      final sRecords = _records.where((r) => r.subjectId == s.id);
      final total = sRecords.fold(0, (sum, r) => sum + r.held);
      final attended = sRecords.fold(0, (sum, r) => sum + r.attended);
      final pct = total > 0 ? (attended / total) * 100 : 0.0;

      if (pct < 75) {
        // Calculate needed
        int needed = (3 * total - 4 * attended).ceil();
        if (needed > 0) {
          insights.add(
            _buildInsightCard(
              context,
              icon: Icons.warning_amber_rounded,
              color: Colors.orange,
              title: 'Attend next $needed classes',
              subtitle: 'in ${s.name} to reach 75%',
            ),
          );
        }
      } else {
        // Calculate bunkable
        int bunkable = ((4 * attended - 3 * total) / 3).floor();
        if (bunkable > 0) {
          insights.add(
            _buildInsightCard(
              context,
              icon: Icons.check_circle_outline_rounded,
              color: Colors.green,
              title: 'Can bunk $bunkable classes',
              subtitle: 'in ${s.name} and stay above 75%',
            ),
          );
        }
      }
    }

    if (insights.isEmpty) {
      return Text(
        'No specific insights available.',
        style: GoogleFonts.poppins(color: Colors.grey),
      );
    }

    return Column(children: insights);
  }

  Widget _buildInsightCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.8), // slightly darker for text
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
