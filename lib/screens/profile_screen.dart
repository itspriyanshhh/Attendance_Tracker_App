import 'package:attendance_management/models/subscription_model.dart';
import 'package:attendance_management/services/subscription_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  SubscriptionModel? _subscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscription();
  }

  Future<void> _loadSubscription() async {
    final sub = await SubscriptionService.instance.getSubscription();
    if (mounted) {
      setState(() {
        _subscription = sub;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Profile Picture
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.primaryContainer,
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 4,
                        ),
                        image: user?.photoURL != null
                            ? DecorationImage(
                                image: NetworkImage(user!.photoURL!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: user?.photoURL == null
                          ? Icon(
                              Icons.person_rounded,
                              size: 64,
                              color: colorScheme.onPrimaryContainer,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Name & Email
                  Text(
                    user?.displayName ?? 'User',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?.email ?? 'No email',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Subscription Card
                  _buildSubscriptionCard(context),

                  const SizedBox(height: 24),

                  // Status Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildStatusRow(
                          context,
                          icon: Icons.verified_user_rounded,
                          label: 'Account Status',
                          value: 'Active',
                          valueColor: Colors.green,
                        ),
                        const Divider(height: 32),
                        _buildStatusRow(
                          context,
                          icon: Icons.sync_rounded,
                          label: 'Last Synced',
                          value: 'Just now',
                          valueColor: colorScheme.primary,
                        ),
                        const Divider(height: 32),
                        _buildStatusRow(
                          context,
                          icon: Icons.cloud_done_rounded,
                          label: 'Cloud Backup',
                          value: 'Enabled',
                          valueColor: Colors.blue,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Info Text
                  Text(
                    'Your data is securely synced with your Google Account.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String planName = 'Free Plan';
    String expiryText = '';
    Color cardColor = colorScheme.surfaceContainer;
    Color textColor = theme.textTheme.bodyLarge!.color!;
    IconData planIcon = Icons.free_breakfast_outlined;

    if (_subscription != null) {
      if (_subscription!.isPremium && !_subscription!.isSubscriptionExpired) {
        planName = _subscription!.subscriptionType == 'four_years'
            ? 'Premium (4 Years)'
            : 'Premium (Yearly)';
        cardColor = Colors.amber.shade100;
        textColor = Colors.brown.shade900;
        planIcon = Icons.workspace_premium_rounded;
        if (_subscription!.subscriptionExpiresAt != null) {
          expiryText =
              'Valid until ${DateFormat('MMM d, yyyy').format(_subscription!.subscriptionExpiresAt!)}';
        }
      } else if (_subscription!.isInTrial) {
        planName = 'Free Trial';
        cardColor = Colors.blue.shade50;
        textColor = Colors.blue.shade900;
        planIcon = Icons.timer_outlined;
        // expiryText = '${_subscription!.daysRemainingInTrial} days remaining';
      }
    }

    // Adjust colors for dark mode if needed
    if (theme.brightness == Brightness.dark) {
      if (cardColor == Colors.amber.shade100) {
        cardColor = Colors.amber.shade900.withOpacity(0.3);
        textColor = Colors.amber.shade100;
      } else if (cardColor == Colors.blue.shade50) {
        cardColor = Colors.blue.shade900.withOpacity(0.3);
        textColor = Colors.blue.shade100;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: textColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(planIcon, color: textColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      planName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (expiryText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: textColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 14,
                    color: textColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    expiryText,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
