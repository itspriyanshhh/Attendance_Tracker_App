import 'package:attendance_management/main.dart';
import 'package:attendance_management/screens/login_screen.dart';
import 'package:attendance_management/services/firestore_service.dart';
import 'package:attendance_management/services/notification_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete ALL subjects and their attendance records. This cannot be undone. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
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
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete ALL attendance history (all dates and records). This cannot be undone. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all history'),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('Dark mode'),
              subtitle: const Text('Experience the dark mode'),
              value: isDarkMode.value,
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.shade300,
              onChanged: (v) async {
                isDarkMode.value = v;
                // Save preference (you added _saveDarkMode earlier)
                try {
                  await _saveDarkMode(v);
                } catch (_) {}
                if (mounted) setState(() {});
              },
            ),

            const SizedBox(height: 12),

            // Delete all subjects
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_forever, color: Colors.white),
              label: Text(
                _isProcessing ? 'Processing...' : 'Delete all subjects',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Colors.white),
              ),
              onPressed: _isProcessing ? null : _confirmAndDeleteAllSubjects,
            ),

            const SizedBox(height: 12),

            // Delete all history
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.history_toggle_off, color: Colors.white),
              label: Text(
                _isProcessing ? 'Processing...' : 'Delete all history',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: Colors.white),
              ),
              onPressed: _isProcessing ? null : _confirmAndDeleteAllHistory,
            ),

            const SizedBox(height: 24),

            // Sign out
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              ),

              icon: const Icon(Icons.logout),
              label: Text(
                _isProcessing ? 'Signing out...' : 'Sign out',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _isProcessing ? null : _signOut,
            ),

            const SizedBox(height: 24),

            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text('Low attendance notifications'),
              subtitle: const Text('Enable or disable attendance reminders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Open notification settings')),
                );
              },
            ),

            const SizedBox(height: 24),
            Text(
              'App version: 1.0.0',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
