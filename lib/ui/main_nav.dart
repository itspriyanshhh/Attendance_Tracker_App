import 'package:attendance_management/screens/analytics_screen.dart';
import 'package:attendance_management/screens/attendance_home.dart';
import 'package:attendance_management/screens/batch_mark_screen.dart';
import 'package:attendance_management/screens/settings_screen.dart';
import 'package:attendance_management/screens/timetable_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:attendance_management/screens/planner_screen.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;

  // Pages for each nav item
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const AttendanceHome(), // Home
      const PlannerScreen(), // Planner
      const AnalyticsScreen(), // Analytics
      const BatchMarkScreen(), // Mark
      const TimetableScreen(), // Timetable
      const SettingsScreen(), // Settings
    ];
  }

  void _onTap(int index) async {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // set system navigation bar color to match the nav container
    final Color navBarColor = Theme.of(context).scaffoldBackgroundColor;
    final Brightness navIconBrightness =
        Theme.of(context).brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        systemNavigationBarColor: navBarColor,
        systemNavigationBarIconBrightness: navIconBrightness,
        systemNavigationBarDividerColor: navBarColor,
      ),
    );

    // Modern elevated rounded container for nav
    return Scaffold(
      // show selected page
      body: SafeArea(child: _pages[_currentIndex]),

      // Bottom navigation with modern styling
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
          child: PhysicalShape(
            elevation: 0,
            color: Theme.of(context).scaffoldBackgroundColor,

            clipper: ShapeBorderClipper(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
            ),
            child: Container(
              height: 75,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    index: 0,
                    currentIndex: _currentIndex,
                    icon: Icons.home_rounded,
                    label: 'Home',
                    onTap: _onTap,
                  ),
                  _NavItem(
                    index: 1,
                    currentIndex: _currentIndex,
                    icon: Icons.calendar_today_rounded,
                    label: 'Planner',
                    onTap: _onTap,
                  ),
                  _NavItem(
                    index: 2,
                    currentIndex: _currentIndex,
                    icon: Icons.bar_chart_rounded,
                    label: 'Analytics',
                    onTap: _onTap,
                  ),
                  _NavItem(
                    index: 3,
                    currentIndex: _currentIndex,
                    icon: Icons.add_box_rounded,
                    label: 'Mark',
                    onTap: _onTap,
                  ),
                  _NavItem(
                    index: 4,
                    currentIndex: _currentIndex,
                    icon: Icons.calendar_month_rounded,
                    label: 'Timetable',
                    onTap: _onTap,
                  ),
                  _NavItem(
                    index: 5,
                    currentIndex: _currentIndex,
                    icon: Icons.settings_rounded,
                    label: 'Settings',
                    onTap: _onTap,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small nav item widget for consistent modern look
class _NavItem extends StatelessWidget {
  final int index;
  final int currentIndex;
  final IconData icon;
  final String label;
  final void Function(int) onTap;

  const _NavItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = index == currentIndex;
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color iconColor = selected
        ? primary
        : Theme.of(context).iconTheme.color!.withOpacity(0.7);
    final TextStyle labelStyle = selected
        ? Theme.of(context).textTheme.bodySmall!.copyWith(
            color: primary,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          )
        : Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(
              context,
            ).textTheme.bodySmall!.color!.withOpacity(0.7),
            fontSize: 10,
          );

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: selected
                    ? BoxDecoration(
                        color: primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                padding: const EdgeInsets.all(6),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: labelStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
