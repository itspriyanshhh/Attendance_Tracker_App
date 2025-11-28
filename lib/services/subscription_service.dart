import 'package:attendance_management/models/subscription_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SubscriptionService {
  static SubscriptionService? _instance;
  static SubscriptionService get instance =>
      _instance ??= SubscriptionService._();
  SubscriptionService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user's subscription data
  Future<SubscriptionModel?> getSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return SubscriptionModel.fromFirestore(data);
    } catch (e) {
      print('Error fetching subscription: $e');
      return null;
    }
  }

  /// Initialize subscription for new users
  /// Sets signUpDate and trialEndsAt (90 days from now)
  Future<void> initializeNewUserSubscription() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      // Only initialize if user document doesn't have signUpDate
      if (!doc.exists || doc.data()?['signUpDate'] == null) {
        final now = DateTime.now();
        final trialEnd = now.add(const Duration(days: 90)); // 3 months trial

        await docRef.set({
          'signUpDate': Timestamp.fromDate(now),
          'trialEndsAt': Timestamp.fromDate(trialEnd),
          'isPremium': false,
        }, SetOptions(merge: true));

        print('Initialized subscription for new user: trial ends $trialEnd');
      }
    } catch (e) {
      print('Error initializing subscription: $e');
      rethrow;
    }
  }

  /// Check if user has access to a specific feature
  /// Features: 'analytics', 'pdf_export', 'bunk_calculator', 'timetable'
  Future<bool> hasFeatureAccess(String feature) async {
    final subscription = await getSubscription();
    if (subscription == null) return false;

    // User has access if in trial OR has valid premium subscription
    return subscription.hasAccess;
  }

  /// Activate premium subscription after successful payment
  Future<void> activateSubscription({
    required String subscriptionType,
    required String paymentId,
    required String orderId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('No user logged in');

    try {
      final now = DateTime.now();
      DateTime expiresAt;

      // Calculate expiry based on subscription type
      if (subscriptionType == 'yearly') {
        expiresAt = now.add(const Duration(days: 365));
      } else if (subscriptionType == 'four_years') {
        expiresAt = now.add(const Duration(days: 365 * 4));
      } else {
        throw Exception('Invalid subscription type: $subscriptionType');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'isPremium': true,
        'subscriptionType': subscriptionType,
        'subscriptionExpiresAt': Timestamp.fromDate(expiresAt),
        'paymentId': paymentId,
        'orderId': orderId,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('Subscription activated: $subscriptionType until $expiresAt');
    } catch (e) {
      print('Error activating subscription: $e');
      rethrow;
    }
  }

  /// Restore subscription (for cross-device sync)
  /// This fetches the latest subscription data from Firestore
  Future<SubscriptionModel?> restoreSubscription() async {
    return await getSubscription();
  }
}
