import 'dart:math';
import 'dart:ui';

import 'package:attendance_management/models/subject.dart';
import 'package:attendance_management/services/local_db_service.dart';
import 'package:attendance_management/services/threshold_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: unused_import
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Circular Progress Painter — used for the hero "Overall %" ring
// ─────────────────────────────────────────────────────────────────────────────
class _CircularProgressPainter extends CustomPainter {
  final double progress; // 0..1
  final Color trackColor;
  final Color progressColor;
  final Color? progressEndColor; // for gradient sweep
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    this.progressEndColor,
    this.strokeWidth = 6,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);

    final progressPaint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (progressEndColor != null) {
      progressPaint.shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + sweepAngle,
        colors: [progressColor, progressEndColor!],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    } else {
      progressPaint.color = progressColor;
    }

    canvas.drawArc(rect, -pi / 2, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer placeholder widget
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerBlock extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _ShimmerBlock({
    this.width = double.infinity,
    required this.height,
    this.borderRadius = 16,
  });

  @override
  State<_ShimmerBlock> createState() => _ShimmerBlockState();
}

class _ShimmerBlockState extends State<_ShimmerBlock>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white10 : Colors.grey.shade200;
    final shimmerColor = isDark ? Colors.white24 : Colors.grey.shade100;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _controller.value, 0),
              end: Alignment(-1.0 + 2.0 * _controller.value + 1.0, 0),
              colors: [baseColor, shimmerColor, baseColor],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANALYTICS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;

  List<Subject> _subjects = [];
  List<AttendanceRecord> _records = [];

  // Chart Data
  List<FlSpot> _trendSpots = [];
  double _minY = 0;
  double _maxY = 100;

  // Computed stats
  double _overallPct = 0;
  int _totalAttended = 0;
  int _totalHeld = 0;
  int _streak = 0;

  // Stagger animation
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _loadData();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final subjects = await LocalDbService.instance.getAllSubjects();
      final records = await LocalDbService.instance.getAllRecords();

      setState(() {
        _subjects = subjects;
        _records = records;
        _computeStats();
        _prepareChartData();
        _isLoading = false;
      });
      _staggerController.forward();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading analytics: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _computeStats() {
    int totalHeld = 0;
    int totalAttended = 0;
    for (var r in _records) {
      final weight = _getSubjectWeight(r.subjectId);
      totalHeld += r.held * weight;
      totalAttended += r.attended * weight;
    }
    _totalHeld = totalHeld;
    _totalAttended = totalAttended;
    _overallPct = totalHeld > 0 ? (totalAttended / totalHeld) * 100 : 0;

    // Compute streak — consecutive dates (most recent first) where daily % ≥ threshold
    final threshold = ThresholdService.instance.threshold;
    final Map<String, List<AttendanceRecord>> byDate = {};
    for (var r in _records) {
      byDate.putIfAbsent(r.date, () => []).add(r);
    }
    final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    int streak = 0;
    for (var date in dates) {
      final dayRecords = byDate[date]!;
      int dayHeld = 0, dayAttended = 0;
      for (var r in dayRecords) {
        final w = _getSubjectWeight(r.subjectId);
        dayHeld += r.held * w;
        dayAttended += r.attended * w;
      }
      final dayPct = dayHeld > 0 ? (dayAttended / dayHeld) * 100 : 0;
      if (dayPct >= threshold) {
        streak++;
      } else {
        break;
      }
    }
    _streak = streak;
  }

  void _prepareChartData() {
    if (_records.isEmpty) return;

    _records.sort((a, b) => a.date.compareTo(b.date));

    final Map<String, List<AttendanceRecord>> recordsByDate = {};
    for (var r in _records) {
      recordsByDate.putIfAbsent(r.date, () => []).add(r);
    }

    final sortedDates = recordsByDate.keys.toList()..sort();
    final datesToShow = sortedDates.length > 15
        ? sortedDates.sublist(sortedDates.length - 15)
        : sortedDates;

    List<FlSpot> spots = [];

    int runningHeld = 0;
    int runningAttended = 0;

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

      final pct =
          runningHeld > 0 ? (runningAttended / runningHeld) * 100 : 0.0;
      spots.add(FlSpot(i.toDouble(), pct));
    }

    _trendSpots = spots;
    if (spots.isNotEmpty) {
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

  // ───────────────────────────── BUILD ─────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? _buildShimmerLoading(isDark)
          : _records.isEmpty
              ? _buildEmptyState(theme)
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // ── Collapsing App Bar ──
                    SliverAppBar(
                      expandedHeight: 72,
                      floating: false,
                      pinned: true,
                      elevation: 0,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      flexibleSpace: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(
                          left: 20,
                          bottom: 16,
                        ),
                        title: Text(
                          'Analytics',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),

                    // ── Content ──
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildStaggeredChild(0, _buildHeroStats(theme, isDark)),
                          const SizedBox(height: 24),
                          _buildStaggeredChild(1, _buildChartSection(theme, isDark)),
                          const SizedBox(height: 28),
                          _buildStaggeredChild(2, _buildSubjectPerformance(theme, isDark)),
                          const SizedBox(height: 28),
                          _buildStaggeredChild(3, _buildInsightsSection(theme, isDark)),
                        ]),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ─────────────────── Staggered animation wrapper ───────────────────

  Widget _buildStaggeredChild(int index, Widget child) {
    final begin = (index * 0.15).clamp(0.0, 0.7);
    final end = (begin + 0.4).clamp(0.0, 1.0);
    final curvedAnimation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - curvedAnimation.value)),
          child: Opacity(
            opacity: curvedAnimation.value,
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  // ─────────────────── Shimmer Loading ───────────────────

  Widget _buildShimmerLoading(bool isDark) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _ShimmerBlock(height: 24, width: 120, borderRadius: 8),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _ShimmerBlock(height: 110, borderRadius: 20)),
                const SizedBox(width: 12),
                Expanded(child: _ShimmerBlock(height: 110, borderRadius: 20)),
                const SizedBox(width: 12),
                Expanded(child: _ShimmerBlock(height: 110, borderRadius: 20)),
              ],
            ),
            const SizedBox(height: 24),
            _ShimmerBlock(height: 260, borderRadius: 24),
            const SizedBox(height: 24),
            _ShimmerBlock(height: 80, borderRadius: 16),
            const SizedBox(height: 12),
            _ShimmerBlock(height: 80, borderRadius: 16),
          ],
        ),
      ),
    );
  }

  // ─────────────────── Empty State ───────────────────

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insights_rounded,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Not enough data yet',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start marking attendance to see analytics',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. HERO SUMMARY STATS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeroStats(ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;

    return Row(
      children: [
        // ── Overall % with circular ring ──
        Expanded(
          child: _GlassCard(
            isDark: isDark,
            child: Column(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _overallPct / 100),
                    duration: const Duration(milliseconds: 1200),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return CustomPaint(
                        painter: _CircularProgressPainter(
                          progress: value,
                          trackColor: primary.withOpacity(0.12),
                          progressColor: primary,
                          progressEndColor: primary.withOpacity(0.6),
                          strokeWidth: 5,
                        ),
                        child: Center(
                          child: Text(
                            '${(value * 100).toInt()}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Overall %',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // ── Classes Attended ──
        Expanded(
          child: _GlassCard(
            isDark: isDark,
            child: Column(
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: _totalAttended),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Text(
                      '$value',
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    );
                  },
                ),
                Text(
                  'of $_totalHeld',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Attended',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // ── Streak ──
        Expanded(
          child: _GlassCard(
            isDark: isDark,
            child: Column(
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: _streak),
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$value',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        if (_streak > 0)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5, left: 2),
                            child: Icon(
                              Icons.local_fire_department_rounded,
                              size: 18,
                              color: Colors.orange.shade400,
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Day Streak',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 2. TREND CHART
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildChartSection(ThemeData theme, bool isDark) {
    final primary = theme.colorScheme.primary;
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          icon: Icons.trending_up_rounded,
          title: 'Attendance Trend',
        ),
        const SizedBox(height: 14),
        Container(
          height: 260,
          padding: const EdgeInsets.only(right: 16, top: 20, bottom: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.04)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.04),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.3)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: colorScheme.outlineVariant.withOpacity(0.15),
                  strokeWidth: 1,
                  dashArray: [6, 4],
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
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (_trendSpots.length - 1).toDouble().clamp(0, double.infinity),
              minY: _minY,
              maxY: _maxY,
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => isDark
                      ? colorScheme.surfaceContainerHighest
                      : Colors.grey.shade900,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      return LineTooltipItem(
                        '${spot.y.toStringAsFixed(1)}%',
                        GoogleFonts.poppins(
                          color: isDark
                              ? colorScheme.onSurface
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              // Threshold line
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(
                    y: ThresholdService.instance.threshold,
                    color: const Color(0xFF34C759).withOpacity(0.45),
                    strokeWidth: 1.5,
                    dashArray: [8, 6],
                    label: HorizontalLineLabel(
                      show: true,
                      alignment: Alignment.topRight,
                      padding: const EdgeInsets.only(right: 5, bottom: 5),
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF34C759),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      labelResolver: (line) =>
                          '${ThresholdService.instance.threshold.round()}%',
                    ),
                  ),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: _trendSpots,
                  isCurved: true,
                  curveSmoothness: 0.3,
                  gradient: LinearGradient(
                    colors: [primary, primary.withOpacity(0.7)],
                  ),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      // Glow on last dot
                      final isLast = index == _trendSpots.length - 1;
                      return FlDotCirclePainter(
                        radius: isLast ? 5 : 3.5,
                        color: isLast ? primary : colorScheme.surface,
                        strokeWidth: isLast ? 0 : 2,
                        strokeColor: primary,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        primary.withOpacity(0.25),
                        primary.withOpacity(0.08),
                        primary.withOpacity(0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 3. SUBJECT PERFORMANCE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSubjectPerformance(ThemeData theme, bool isDark) {
    final List<Map<String, dynamic>> data = [];
    for (var s in _subjects) {
      final sRecords = _records.where((r) => r.subjectId == s.id);
      final total = sRecords.fold(0, (sum, r) => sum + r.held);
      final attended = sRecords.fold(0, (sum, r) => sum + r.attended);
      final pct = total > 0 ? (attended / total) * 100 : 0.0;
      data.add({
        'name': s.name,
        'pct': pct,
        'isLab': s.isLab,
        'color': s.color,
        'attended': attended,
        'total': total,
      });
    }
    data.sort((a, b) => (a['pct'] as double).compareTo(b['pct'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          icon: Icons.school_rounded,
          title: 'Subject Performance',
        ),
        const SizedBox(height: 14),
        ...data.asMap().entries.map((entry) {
          final index = entry.key;
          final d = entry.value;
          return _buildSubjectCard(theme, isDark, d, index);
        }),
      ],
    );
  }

  Widget _buildSubjectCard(
    ThemeData theme,
    bool isDark,
    Map<String, dynamic> d,
    int index,
  ) {
    final pct = d['pct'] as double;
    final threshold = ThresholdService.instance.threshold;
    final isAbove = pct >= threshold;

    // Color for the progress bar
    Color barColor;
    if (pct >= threshold) {
      barColor = const Color(0xFF34C759);
    } else if (pct >= threshold - 10) {
      barColor = const Color(0xFFFFCC00);
    } else {
      barColor = const Color(0xFFFF3B30);
    }

    // Subject accent color
    Color subjectColor;
    try {
      final hex = (d['color'] as String).replaceAll('#', '');
      subjectColor = Color(int.parse('FF$hex', radix: 16));
      // If it's white or very light, fall back to primary
      if (subjectColor.computeLuminance() > 0.9) {
        subjectColor = theme.colorScheme.primary;
      }
    } catch (_) {
      subjectColor = theme.colorScheme.primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.2)
                : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: subjectColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  d['name'],
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (d['isLab'] == true) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'LAB',
                                    style: GoogleFonts.poppins(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAbove
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 14,
                              color: barColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${pct.toStringAsFixed(1)}%',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: barColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${d['attended']} of ${d['total']} classes',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Animated progress bar
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (pct / 100).clamp(0.0, 1.0)),
                      duration: Duration(milliseconds: 800 + index * 100),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.06)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: value,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    barColor,
                                    barColor.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // 4. INSIGHTS SECTION
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildInsightsSection(ThemeData theme, bool isDark) {
    final insights = <Widget>[];

    for (var s in _subjects) {
      final sRecords = _records.where((r) => r.subjectId == s.id);
      final total = sRecords.fold(0, (sum, r) => sum + r.held);
      final attended = sRecords.fold(0, (sum, r) => sum + r.attended);
      final pct = total > 0 ? (attended / total) * 100 : 0.0;

      if (pct < ThresholdService.instance.threshold) {
        final t = ThresholdService.instance.threshold / 100.0;
        int needed = ((t * total - attended) / (1 - t)).ceil();
        if (needed > 0) {
          insights.add(
            _buildInsightCard(
              theme,
              isDark,
              icon: Icons.warning_amber_rounded,
              accentColor: const Color(0xFFFF9500),
              title: 'Attend next $needed classes',
              subtitle:
                  'in ${s.name} to reach ${ThresholdService.instance.threshold.round()}%',
            ),
          );
        }
      } else {
        final t = ThresholdService.instance.threshold / 100.0;
        int bunkable = ((attended - t * total) / t).floor();
        if (bunkable > 0) {
          insights.add(
            _buildInsightCard(
              theme,
              isDark,
              icon: Icons.check_circle_outline_rounded,
              accentColor: const Color(0xFF34C759),
              title: 'Can skip $bunkable classes',
              subtitle:
                  'in ${s.name} and stay above ${ThresholdService.instance.threshold.round()}%',
            ),
          );
        }
      }
    }

    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          theme,
          icon: Icons.lightbulb_outline_rounded,
          title: 'Insights',
        ),
        const SizedBox(height: 14),
        ...insights,
      ],
    );
  }

  Widget _buildInsightCard(
    ThemeData theme,
    bool isDark, {
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? accentColor.withOpacity(0.08)
                  : accentColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accentColor.withOpacity(isDark ? 0.15 : 0.12),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Icon with gradient background
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withOpacity(0.2),
                        accentColor.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.7),
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
  }

  // ═══════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Glassmorphic Card Widget
// ═══════════════════════════════════════════════════════════════════════════════
class _GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const _GlassCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withOpacity(0.07),
                      Colors.white.withOpacity(0.03),
                    ]
                  : [
                      Colors.white.withOpacity(0.9),
                      Colors.white.withOpacity(0.7),
                    ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? primary.withOpacity(0.12)
                  : primary.withOpacity(0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.25)
                    : Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
