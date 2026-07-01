import 'package:attendance_management/main.dart';
import 'package:attendance_management/screens/history_screen.dart';
import 'package:attendance_management/screens/login_screen.dart';
import 'package:attendance_management/screens/privacy_policy_screen.dart';
import 'package:attendance_management/screens/profile_screen.dart';
import 'package:attendance_management/services/local_db_service.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:attendance_management/services/notification_service.dart';
import 'package:attendance_management/services/pdf_service.dart';
import 'package:attendance_management/services/sync_service.dart';
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
  bool _remindersEnabled = true;
  DateTime? _lastSyncTime;
  double _threshold = NotificationService.defaultThreshold;
  int _lectureDuration = NotificationService.defaultLectureDuration;
  int _labDuration = NotificationService.defaultLabDuration;

  @override
  void initState() {
    super.initState();
    _loadRemindersPref();
    _loadLastSyncTime();
    _loadClassSettings();
  }

  Future<void> _loadLastSyncTime() async {
    final t = await SyncService.instance.lastSyncTime();
    if (mounted) setState(() => _lastSyncTime = t);
  }

  Future<void> _loadRemindersPref() async {
    final enabled = await NotificationService.instance.areRemindersEnabled();
    if (mounted) setState(() => _remindersEnabled = enabled);
  }

  Future<void> _toggleReminders(bool value) async {
    setState(() {
      _remindersEnabled = value;
      _isProcessing = true;
    });

    try {
      await NotificationService.instance.setRemindersEnabled(value);

      if (value) {
        // Fetch subjects and schedule
        final subjects = await LocalDbService.instance.getAllSubjects();
        await NotificationService.instance.scheduleClassReminders(subjects);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Reminders enabled')));
        }
      } else {
        // Cancel all
        await NotificationService.instance.cancelAll();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Reminders disabled')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update reminders: $e')),
        );
        // Revert UI on error
        setState(() => _remindersEnabled = !value);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _loadClassSettings() async {
    final ns = NotificationService.instance;
    final t = await ns.getThreshold();
    final ld = await ns.getLectureDuration();
    final bd = await ns.getLabDuration();
    if (mounted) {
      setState(() {
        _threshold = t;
        _lectureDuration = ld;
        _labDuration = bd;
      });
    }
  }

  Future<void> _onThresholdChanged(double value) async {
    setState(() => _threshold = value);
    await NotificationService.instance.setThreshold(value);
  }

  Future<void> _pickDuration({
    required String label,
    required int current,
    required Future<void> Function(int) onSave,
  }) async {
    int picked = current;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                label,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$picked min',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: picked.toDouble(),
                    min: 20,
                    max: 180,
                    divisions: 32,
                    label: '$picked min',
                    onChanged: (v) {
                      setDialogState(() => picked = v.round());
                    },
                  ),
                  Text(
                    'Post-class notification fires after this',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, picked),
                  child: Text('Save', style: GoogleFonts.poppins()),
                ),
              ],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            );
          },
        );
      },
    );

    if (result != null && result != current) {
      await onSave(result);
      // Reschedule notifications with new duration
      final subjects = await LocalDbService.instance.getAllSubjects();
      await NotificationService.instance.scheduleClassReminders(subjects);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label updated to $result min')),
        );
      }
    }
  }

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
      await LocalDbService.instance.deleteAllSubjects();
      // also ensure any orphan records are removed (defensive)
      await LocalDbService.instance.deleteAllRecords();
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
      await LocalDbService.instance.deleteAllRecords();
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

  Future<void> _syncNow() async {
    setState(() => _isProcessing = true);
    try {
      await SyncService.instance.pushToCloud();
      final t = await SyncService.instance.lastSyncTime();
      if (mounted) {
        setState(() => _lastSyncTime = t);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data synced to cloud successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _formatSyncTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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

  Future<void> _confirmAndDeleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
        content: Text(
          'WARNING: This action is irreversible.\n\nIt will permanently delete:\n• All subjects and attendance records\n• All planner items\n• Your subscription details\n• Your account login\n\nAre you sure you want to proceed?',
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
            child: Text('Delete Forever', style: GoogleFonts.poppins()),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      // 1. Delete data from Firestore AND local DB
      await FirestoreService.instance.deleteUserData();
      await LocalDbService.instance.wipeAll();

      // 2. Delete Auth Account
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.delete();
      }

      // 3. Navigate to Login
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Account deleted')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete account. Please sign in again and try.',
            ),
          ),
        );
      }
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
        child: Stack(
          children: [
            ListView(
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
                  subtitle:
                      'Reminder before class & prompt to mark attendance after',
                  trailing: Switch(
                    value: _remindersEnabled,
                    onChanged: _isProcessing ? null : _toggleReminders,
                    activeColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.speed_rounded,
                  title: 'Attendance Threshold',
                  subtitle: '${_threshold.round()}% — alerts when below this',
                  trailing: SizedBox(
                    width: 140,
                    child: Slider(
                      value: _threshold,
                      min: 50,
                      max: 95,
                      divisions: 9,
                      label: '${_threshold.round()}%',
                      onChanged: _onThresholdChanged,
                    ),
                  ),
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.menu_book_rounded,
                  title: 'Lecture Duration',
                  subtitle: '$_lectureDuration min per lecture',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickDuration(
                    label: 'Lecture Duration',
                    current: _lectureDuration,
                    onSave: (val) async {
                      await NotificationService.instance.setLectureDuration(val);
                      if (mounted) setState(() => _lectureDuration = val);
                    },
                  ),
                ),
                _buildSettingTile(
                  context,
                  icon: Icons.science_rounded,
                  title: 'Lab Duration',
                  subtitle: '$_labDuration min per lab',
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _pickDuration(
                    label: 'Lab Duration',
                    current: _labDuration,
                    onSave: (val) async {
                      await NotificationService.instance.setLabDuration(val);
                      if (mounted) setState(() => _labDuration = val);
                    },
                  ),
                ),

                _buildSectionHeader('DATA MANAGEMENT', context),
                _buildSettingTile(
                  context,
                  icon: Icons.cloud_sync_rounded,
                  title: 'Sync to Cloud',
                  subtitle: _lastSyncTime == null
                      ? 'Never synced'
                      : 'Last synced: ${_formatSyncTime(_lastSyncTime!)}',
                  iconColor: Colors.teal,
                  onTap: _isProcessing ? null : _syncNow,
                ),
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
                          '© 2026 Priyansh Garg\n\nDesigned for college students to track and manage their attendance effortlessly.',
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
                _buildSettingTile(
                  context,
                  icon: Icons.delete_forever,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account and data',
                  iconColor: Colors.red,
                  onTap: _isProcessing ? null : _confirmAndDeleteAccount,
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
            if (_isProcessing)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
