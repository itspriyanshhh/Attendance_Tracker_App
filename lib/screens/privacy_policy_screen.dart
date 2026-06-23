import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attendify Privacy Policy',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Last updated: ${DateTime.now().toString().substring(0, 10)}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              _buildSection(
                context,
                'Introduction',
                'Attendify ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, and safeguard your information when you use our attendance tracking application.',
              ),

              _buildSection(
                context,
                'Information We Collect',
                '• Account Information: When you sign in with Google, we collect your name and email address.\n\n'
                    '• Attendance Data: We collect and store your subject information, attendance records, timetable schedules, and related analytics.\n\n'
                    '• Usage Data: We may collect information about how you interact with the app, including device information and app performance data.',
              ),

              _buildSection(
                context,
                'How We Use Your Information',
                'We use your information to:\n\n'
                    '• Provide and maintain our attendance tracking services\n'
                    '• Sync your data across your devices\n'
                    '• Send you attendance reminders and notifications\n'
                    '• Generate attendance reports and analytics\n'
                    '• Improve and optimize app performance\n'
                    '• Communicate important updates about the app',
              ),

              _buildSection(
                context,
                'Data Storage and Security',
                'Your data is stored securely using Firebase Cloud Firestore, which provides:\n\n'
                    '• Encrypted data transmission (HTTPS/TLS)\n'
                    '• Secure data storage with industry-standard security measures\n'
                    '• Data redundancy and backup\n\n'
                    'We implement appropriate technical and organizational measures to protect your personal information from unauthorized access, disclosure, or destruction.',
              ),

              _buildSection(
                context,
                'Third-Party Services',
                'We use the following third-party services:\n\n'
                    '• Google Sign-In: For authentication\n'
                    '• Firebase (Google): For data storage, authentication, and push notifications\n\n'
                    'These services have their own privacy policies governing the use of your information.',
              ),

              _buildSection(
                context,
                'Data Retention',
                'We retain your data for as long as your account is active. You can delete your data at any time through the app settings. Upon deletion, your data will be permanently removed from our servers.',
              ),

              _buildSection(
                context,
                'Your Rights',
                'You have the right to:\n\n'
                    '• Access your personal data\n'
                    '• Correct inaccurate data\n'
                    '• Delete your data\n'
                    '• Export your attendance data\n'
                    '• Opt-out of notifications\n\n'
                    'You can exercise these rights directly within the app settings.',
              ),

              _buildSection(
                context,
                'Children\'s Privacy',
                'Attendify is designed for students and educational use. If you are under 18, please ensure you have permission from your parent or guardian before using the app.',
              ),

              _buildSection(
                context,
                'Changes to This Policy',
                'We may update this Privacy Policy from time to time. We will notify you of any significant changes by updating the "Last updated" date and, where appropriate, through in-app notifications.',
              ),

              _buildSection(
                context,
                'Contact Us',
                'If you have any questions about this Privacy Policy or our data practices, please contact us at:\n\n'
                    'Email: priyanshg2108@gmail.com',
              ),

              const SizedBox(height: 32),
              Center(
                child: Text(
                  '© 2026 Attendify by Priyansh Garg',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
