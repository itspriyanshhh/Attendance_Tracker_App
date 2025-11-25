import 'package:attendance_management/services/safe_bunk_calculator.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SafeBunkSheet extends StatefulWidget {
  final int totalPointsHeld;
  final int totalPointsAttended;

  const SafeBunkSheet({
    super.key,
    required this.totalPointsHeld,
    required this.totalPointsAttended,
  });

  @override
  State<SafeBunkSheet> createState() => _SafeBunkSheetState();
}

class _SafeBunkSheetState extends State<SafeBunkSheet> {
  // 0 = Can I Bunk?, 1 = Recovery
  int _modeIndex = 0;

  // Bunk Mode State
  int _lecturesToMiss = 0;
  int _labsToMiss = 0;

  // Recovery Mode State
  double _targetPercentage = 75.0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Safe Bunk Calculator',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 20),

          // Mode Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [_buildTab('Can I Bunk?', 0), _buildTab('Recovery', 1)],
            ),
          ),
          const SizedBox(height: 24),

          // Content
          if (_modeIndex == 0)
            _buildBunkMode(isDark, textColor)
          else
            _buildRecoveryMode(isDark, textColor),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = _modeIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _modeIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBunkMode(bool isDark, Color textColor) {
    double newPercentage = SafeBunkCalculator.calculateNewGlobalPercentage(
      widget.totalPointsHeld,
      widget.totalPointsAttended,
      _lecturesToMiss,
      _labsToMiss,
    );
    String status = SafeBunkCalculator.getStatusMessage(newPercentage);
    Color statusColor;
    if (status == 'Safe')
      statusColor = Colors.green;
    else if (status == 'Warning')
      statusColor = Colors.orange;
    else
      statusColor = Colors.red;

    return Column(
      children: [
        _buildCounterRow('Lectures to miss (1 pt)', _lecturesToMiss, (val) {
          setState(() => _lecturesToMiss = val);
        }),
        const SizedBox(height: 16),
        _buildCounterRow('Labs to miss (2 pts)', _labsToMiss, (val) {
          setState(() => _labsToMiss = val);
        }),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                'New Attendance',
                style: GoogleFonts.poppins(color: textColor.withOpacity(0.7)),
              ),
              Text(
                '${newPercentage.toStringAsFixed(2)}%',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
              Text(
                status,
                style: GoogleFonts.poppins(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecoveryMode(bool isDark, Color textColor) {
    int sessionsNeeded = SafeBunkCalculator.calculateSessionsToRecover(
      widget.totalPointsHeld,
      widget.totalPointsAttended,
      _targetPercentage,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Target Percentage',
              style: GoogleFonts.poppins(color: textColor),
            ),
            Text(
              '${_targetPercentage.toInt()}%',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ],
        ),
        Slider(
          value: _targetPercentage,
          min: 1,
          max: 100,
          divisions: 100,
          activeColor: Colors.indigo,
          onChanged: (val) => setState(() => _targetPercentage = val),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.indigo.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Text(
                'You need to attend',
                style: GoogleFonts.poppins(color: textColor.withOpacity(0.7)),
              ),
              const SizedBox(height: 8),
              Text(
                sessionsNeeded == -1 ? 'Impossible' : '$sessionsNeeded',
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              Text(
                'Consecutive Lectures',
                style: GoogleFonts.poppins(
                  color: Colors.indigo,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCounterRow(String label, int value, Function(int) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 14)),
        Row(
          children: [
            IconButton(
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
              color: Colors.indigo,
            ),
            Text(
              '$value',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            IconButton(
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add_circle_outline),
              color: Colors.indigo,
            ),
          ],
        ),
      ],
    );
  }
}
