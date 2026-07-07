import 'package:shared_preferences/shared_preferences.dart';

/// Centralized singleton that holds the user's attendance threshold.
///
/// All screens read [threshold] instead of hard-coding 75%.
/// The value is persisted via SharedPreferences under the same key
/// that NotificationService already uses ('attendance_threshold').
class ThresholdService {
  ThresholdService._();
  static final ThresholdService instance = ThresholdService._();

  static const String _prefKey = 'attendance_threshold';
  static const double defaultThreshold = 75.0;

  /// The current threshold, cached in memory after [init].
  double threshold = defaultThreshold;

  /// Load the saved threshold from SharedPreferences.
  /// Call once at app startup (before runApp).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    threshold = prefs.getDouble(_prefKey) ?? defaultThreshold;
  }

  /// Update the threshold both in memory and in SharedPreferences.
  Future<void> setThreshold(double value) async {
    threshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefKey, value);
  }
}
