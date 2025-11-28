import 'package:attendance_management/main.dart';
import 'package:attendance_management/screens/history_screen.dart';
import 'package:attendance_management/screens/login_screen.dart';
import 'package:attendance_management/screens/privacy_policy_screen.dart';
import 'package:attendance_management/screens/profile_screen.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:attendance_management/services/notification_service.dart';
import 'package:attendance_management/services/pdf_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _saveDarkMode(bool enabled) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', enabled);
  } catch (e) {
    print('Failed to save dark mode pref: $e');
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isProcessing = false;

  Future<void> _confirmAndDeleteAllSubjects() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete all subjects',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will delete ALL subjects and their attendance records. This cannot be undone. Do you want to continue?',
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
            child: Text('Delete all', style: GoogleFonts.poppins()),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await FirestoreService.instance.deleteAllSubjects();
      // also ensure any orphan records are removed (defensive)
      await FirestoreService.instance.deleteAllRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All subjects and their records deleted'),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete subjects: $e')),
        );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmAndDeleteAllHistory() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete all history',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'This will delete ALL attendance history (all dates and records). This cannot be undone. Do you want to continue?',
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
            child: Text('Delete all history', style: GoogleFonts.poppins()),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await FirestoreService.instance.deleteAllRecords();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All attendance history deleted')),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete history: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isProcessing = true);
    try {
      await PdfService.generateAttendanceReport();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isProcessing = true);
    try {
      await FirebaseAuth.instance.signOut();
      try {
        // best-effort Google sign out
        await GoogleSignIn().signOut();
      } catch (_) {}
      // stop background monitor
      await AttendanceMonitor.instance.stop();
      if (mounted) {
        // navigate to login and clear back stack
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (iconColor ?? theme.colorScheme.primary).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor ?? theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _buildSectionHeader('ACCOUNT', context),
            _buildSettingTile(
              context,
              icon: Icons.person_rounded,
              title: 'My Profile',
              subtitle: 'View account details',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              },
            ),

            _buildSectionHeader('APPEARANCE', context),
            _buildSettingTile(
              context,
              icon: isDarkMode.value
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              title: 'Dark Mode',
              subtitle: 'Toggle application theme',
              trailing: Switch(
                value: isDarkMode.value,
                onChanged: (v) async {
                  isDarkMode.value = v;
                  try {
                    await _saveDarkMode(v);
                  } catch (_) {}
                  if (mounted) setState(() {});
                },
              ),
            ),

            _buildSectionHeader('NOTIFICATIONS', context),
            _buildSettingTile(
              context,
              icon: Icons.notifications_active_rounded,
              title: 'Attendance Reminders',
              subtitle: 'Get notified when attendance is low',
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Notification settings coming soon',
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                );
              },
            ),

            _buildSectionHeader('DATA MANAGEMENT', context),
            _buildSettingTile(
              context,
              icon: Icons.history_rounded,
              title: 'View History',
              subtitle: 'Check past attendance records',
              iconColor: Colors.purple,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HistoryScreen(),
                  ),
                );
              },
            ),
            _buildSettingTile(
              context,
              icon: Icons.delete_forever_rounded,
              title: 'Delete All Subjects',
              subtitle: 'Remove all subjects and records',
              iconColor: Colors.red,
              onTap: _isProcessing ? null : _confirmAndDeleteAllSubjects,
            ),
            _buildSettingTile(
              context,
              icon: Icons.history_toggle_off_rounded,
              title: 'Delete History',
              subtitle: 'Clear all attendance history',
              iconColor: Colors.red,
              onTap: _isProcessing ? null : _confirmAndDeleteAllHistory,
            ),

            _buildSectionHeader('OFFICIAL REPORTS', context),
            _buildSettingTile(
              context,
              icon: Icons.picture_as_pdf_rounded,
              title: 'Export Attendance Report',
              subtitle: 'Generate PDF report of your attendance',
              iconColor: Colors.blue,
              onTap: _isProcessing ? null : _generateReport,
            ),

            _buildSectionHeader('ABOUT & LEGAL', context),
            _buildSettingTile(
              context,
              icon: Icons.privacy_tip_rounded,
              title: 'Privacy Policy',
              subtitle: 'How we handle your data',
              iconColor: Colors.green,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            _buildSettingTile(
              context,
              icon: Icons.info_rounded,
              title: 'About Attendify',
              subtitle: 'App information and credits',
              iconColor: Colors.blue,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Attendify',
                  applicationVersion: '1.0.0 (1)',
                  applicationLegalese:
                      '© 2024 Priyansh Garg\n\nDesigned for college students to track and manage their attendance effortlessly.',
                  applicationIcon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.calendar_today_rounded,
                      size: 32,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                );
              },
            ),

            _buildSectionHeader('SESSION', context),
            _buildSettingTile(
              context,
              icon: Icons.logout_rounded,
              title: 'Sign Out',
              subtitle: 'Log out of your account',
              onTap: _isProcessing ? null : _signOut,
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                'App Version 1.0.0',
                style: GoogleFonts.poppins(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
