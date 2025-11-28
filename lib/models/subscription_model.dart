import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a user's subscription status
class SubscriptionModel {
  /// Whether user currently has an active premium subscription
  final bool isPremium;

  /// Type of subscription: 'yearly' or 'four_years'
  final String? subscriptionType;

  /// When the subscription expires (null if no subscription)
  final DateTime? subscriptionExpiresAt;

  /// When the user first signed up (used to calculate trial)
  final DateTime? signUpDate;

  /// When the 3-month trial period ends
  final DateTime? trialEndsAt;

  /// Razorpay payment ID for the subscription
  final String? paymentId;

  /// Razorpay order ID (if applicable)
  final String? orderId;

  SubscriptionModel({
    required this.isPremium,
    this.subscriptionType,
    this.subscriptionExpiresAt,
    this.signUpDate,
    this.trialEndsAt,
    this.paymentId,
    this.orderId,
  });

  /// Create from Firestore document
  factory SubscriptionModel.fromFirestore(Map<String, dynamic> data) {
    return SubscriptionModel(
      isPremium: data['isPremium'] ?? false,
      subscriptionType: data['subscriptionType'],
      subscriptionExpiresAt: data['subscriptionExpiresAt'] != null
          ? (data['subscriptionExpiresAt'] as Timestamp).toDate()
          : null,
      signUpDate: data['signUpDate'] != null
          ? (data['signUpDate'] as Timestamp).toDate()
          : null,
      trialEndsAt: data['trialEndsAt'] != null
          ? (data['trialEndsAt'] as Timestamp).toDate()
          : null,
      paymentId: data['paymentId'],
      orderId: data['orderId'],
    );
  }

  /// Convert to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'isPremium': isPremium,
      'subscriptionType': subscriptionType,
      'subscriptionExpiresAt': subscriptionExpiresAt != null
          ? Timestamp.fromDate(subscriptionExpiresAt!)
          : null,
      'signUpDate': signUpDate != null ? Timestamp.fromDate(signUpDate!) : null,
      'trialEndsAt': trialEndsAt != null
          ? Timestamp.fromDate(trialEndsAt!)
          : null,
      'paymentId': paymentId,
      'orderId': orderId,
    };
  }

  /// Check if user is currently in trial period
  bool get isInTrial {
    if (trialEndsAt == null) return false;
    return DateTime.now().isBefore(trialEndsAt!);
  }

  /// Check if subscription has expired
  bool get isSubscriptionExpired {
    if (!isPremium || subscriptionExpiresAt == null) return false;
    return DateTime.now().isAfter(subscriptionExpiresAt!);
  }

  /// Check if user has access to premium features
  bool get hasAccess {
    // Access if in trial OR has valid premium subscription
    return isInTrial || (isPremium && !isSubscriptionExpired);
  }

  /// Get days remaining in trial
  int get daysRemainingInTrial {
    if (trialEndsAt == null) return 0;
    final diff = trialEndsAt!.difference(DateTime.now());
    return diff.isNegative ? 0 : diff.inDays;
  }

  SubscriptionModel copyWith({
    bool? isPremium,
    String? subscriptionType,
    DateTime? subscriptionExpiresAt,
    DateTime? signUpDate,
    DateTime? trialEndsAt,
    String? paymentId,
    String? orderId,
  }) {
    return SubscriptionModel(
      isPremium: isPremium ?? this.isPremium,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      subscriptionExpiresAt:
          subscriptionExpiresAt ?? this.subscriptionExpiresAt,
      signUpDate: signUpDate ?? this.signUpDate,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      paymentId: paymentId ?? this.paymentId,
      orderId: orderId ?? this.orderId,
    );
  }
}
