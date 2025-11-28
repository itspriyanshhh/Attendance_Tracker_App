import 'package:attendance_management/models/subscription_model.dart';
import 'package:attendance_management/services/razorpay_service.dart';
import 'package:attendance_management/services/subscription_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  SubscriptionModel? _subscription;
  bool _isLoading = true;
  bool _isProcessingYearly = false;
  bool _isProcessingFourYears = false;

  @override
  void initState() {
    super.initState();
    RazorpayService.instance.initialize();
    _loadSubscription();
  }

  @override
  void dispose() {
    RazorpayService.instance.dispose();
    super.dispose();
  }

  Future<void> _loadSubscription() async {
    final subscription = await SubscriptionService.instance.getSubscription();
    setState(() {
      _subscription = subscription;
      _isLoading = false;
    });
  }

  Future<void> _purchaseYearly() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isProcessingYearly = true);

    try {
      await RazorpayService.instance.purchaseYearlySubscription(
        userEmail: user.email ?? '',
        userPhone: user.phoneNumber ?? '',
        onSuccess: (response) {
          setState(() => _isProcessingYearly = false);
          _showSuccessDialog();
        },
        onFailure: (response) {
          setState(() => _isProcessingYearly = false);
          _showErrorDialog(response.message ?? 'Payment failed');
        },
      );
    } catch (e) {
      setState(() => _isProcessingYearly = false);
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _purchaseFourYears() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isProcessingFourYears = true);

    try {
      await RazorpayService.instance.purchaseFourYearsSubscription(
        userEmail: user.email ?? '',
        userPhone: user.phoneNumber ?? '',
        onSuccess: (response) {
          setState(() => _isProcessingFourYears = false);
          _showSuccessDialog();
        },
        onFailure: (response) {
          setState(() => _isProcessingFourYears = false);
          _showErrorDialog(response.message ?? 'Payment failed');
        },
      );
    } catch (e) {
      setState(() => _isProcessingFourYears = false);
      _showErrorDialog(e.toString());
    }
  }

  Future<void> _restorePurchase() async {
    setState(() => _isLoading = true);
    try {
      final subscription = await SubscriptionService.instance
          .restoreSubscription();
      setState(() {
        _subscription = subscription;
        _isLoading = false;
      });

      if (subscription?.isPremium == true) {
        _showSuccessDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No active subscription found',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog(e.toString());
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text(
              'Success!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(
          'Your subscription is now active. Enjoy all premium features!',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, true); // Return to previous screen
            },
            child: Text('Continue', style: GoogleFonts.poppins()),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Text(
              'Error',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: GoogleFonts.poppins()),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Upgrade to Premium',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trial Status
                    if (_subscription != null && _subscription!.isInTrial)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.schedule, color: Colors.white, size: 40),
                            SizedBox(height: 12),
                            Text(
                              'Trial Active',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${_subscription!.daysRemainingInTrial} days remaining',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          border: Border.all(color: Colors.red, width: 2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.lock_clock, color: Colors.red, size: 40),
                            SizedBox(height: 12),
                            Text(
                              'Trial Expired',
                              style: GoogleFonts.poppins(
                                color: Colors.red,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Subscribe to continue using premium features',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                color: theme.colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                    SizedBox(height: 32),

                    // Features List
                    Text(
                      'Premium Features',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildFeatureItem(
                      Icons.analytics,
                      'Advanced Analytics Dashboard',
                    ),
                    _buildFeatureItem(
                      Icons.picture_as_pdf,
                      'PDF Export & Reports',
                    ),
                    _buildFeatureItem(Icons.calculate, 'Smart Bunk Calculator'),
                    _buildFeatureItem(
                      Icons.calendar_month,
                      'Class Timetable Management',
                    ),
                    _buildFeatureItem(
                      Icons.cloud_sync,
                      'Cloud Sync Across Devices',
                    ),

                    SizedBox(height: 32),

                    // Pricing Cards
                    Text(
                      'Choose Your Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),

                    // Yearly Plan
                    _buildPricingCard(
                      title: 'Yearly',
                      price: '₹99',
                      period: '/year',
                      features: ['All premium features', 'Priority support'],
                      isRecommended: false,
                      isProcessing: _isProcessingYearly,
                      onTap: _purchaseYearly,
                      colorScheme: colorScheme,
                    ),

                    SizedBox(height: 16),

                    // 4-Year Plan (Best Value)
                    _buildPricingCard(
                      title: '4 Years',
                      price: '₹199',
                      period: '/4 years',
                      features: [
                        'All premium features',
                        'Priority support',
                        'Best value - Save 50%',
                      ],
                      isRecommended: true,
                      isProcessing: _isProcessingFourYears,
                      onTap: _purchaseFourYears,
                      colorScheme: colorScheme,
                    ),

                    SizedBox(height: 24),

                    // Restore Purchase Button
                    Center(
                      child: TextButton.icon(
                        onPressed: _restorePurchase,
                        icon: Icon(Icons.restore),
                        label: Text(
                          'Restore Purchase',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    ),

                    SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.green, size: 20),
          ),
          SizedBox(width: 16),
          Expanded(child: Text(text, style: GoogleFonts.poppins(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String period,
    required List<String> features,
    required bool isRecommended,
    required bool isProcessing,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isRecommended ? colorScheme.primary : Colors.grey.shade300,
          width: isRecommended ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          if (isRecommended)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(17),
                  topRight: Radius.circular(17),
                ),
              ),
              child: Text(
                'RECOMMENDED',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    Text(
                      period,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                ...features.map(
                  (feature) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 20),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: isProcessing ? null : onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: isRecommended
                          ? colorScheme.primary
                          : Colors.grey,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isProcessing
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Subscribe Now',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
