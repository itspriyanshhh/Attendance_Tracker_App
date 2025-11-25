import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_management/services/safe_bunk_calculator.dart';

void main() {
  group('SafeBunkCalculator', () {
    test('calculateNewGlobalPercentage - Lecture Impact', () {
      // 10/10 attended (100%). Miss 1 lecture (1pt).
      // New Held = 10 + 1 = 11. Attended = 10.
      // 10/11 = 90.909%
      double result = SafeBunkCalculator.calculateNewGlobalPercentage(
        10,
        10,
        1,
        0,
      );
      expect(result, closeTo(90.909, 0.001));
    });

    test('calculateNewGlobalPercentage - Lab Impact', () {
      // 10/10 attended (100%). Miss 1 lab (2pts).
      // New Held = 10 + 2 = 12. Attended = 10.
      // 10/12 = 83.333%
      double result = SafeBunkCalculator.calculateNewGlobalPercentage(
        10,
        10,
        0,
        1,
      );
      expect(result, closeTo(83.333, 0.001));
    });

    test('calculateSessionsToRecover - Simple Case', () {
      // 5/10 (50%). Target 75%.
      // (5 + x)/(10 + x) >= 0.75
      // 5 + x >= 7.5 + 0.75x
      // 0.25x >= 2.5
      // x >= 10
      int result = SafeBunkCalculator.calculateSessionsToRecover(10, 5, 75.0);
      expect(result, 10);
    });

    test('calculateSessionsToRecover - Already Safe', () {
      // 8/10 (80%). Target 75%.
      int result = SafeBunkCalculator.calculateSessionsToRecover(10, 8, 75.0);
      expect(result, 0);
    });

    test('calculateSessionsToRecover - Impossible Target', () {
      // 5/10 (50%). Target 100%.
      // Impossible to reach 100% if you've already missed classes.
      // The function returns -1 for impossible cases (denominator <= 0).
      int result = SafeBunkCalculator.calculateSessionsToRecover(10, 5, 100.0);
      expect(result, -1);
    });
  });
}
