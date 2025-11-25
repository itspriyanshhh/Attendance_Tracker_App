class SafeBunkCalculator {
  /// Calculates the new global attendance percentage if the user misses future classes.
  ///
  /// [totalPointsHeld]: Current total weighted sessions held.
  /// [totalPointsAttended]: Current total weighted sessions attended.
  /// [lecturesToMiss]: Number of lectures (1 point) the user plans to miss.
  /// [labsToMiss]: Number of labs (2 points) the user plans to miss.
  static double calculateNewGlobalPercentage(
    int totalPointsHeld,
    int totalPointsAttended,
    int lecturesToMiss,
    int labsToMiss,
  ) {
    int additionalHeld = (lecturesToMiss * 1) + (labsToMiss * 2);
    // Attended points don't increase when you miss classes
    int newTotalHeld = totalPointsHeld + additionalHeld;

    if (newTotalHeld == 0) return 0.0;

    return (totalPointsAttended / newTotalHeld) * 100;
  }

  /// Calculates how many consecutive sessions (of a specific weight) need to be attended
  /// to reach the [targetPercentage].
  ///
  /// [totalPointsHeld]: Current total weighted sessions held.
  /// [totalPointsAttended]: Current total weighted sessions attended.
  /// [targetPercentage]: The target percentage (e.g., 75.0).
  /// [sessionWeight]: Weight of the session to attend (default 1 for Lecture).
  static int calculateSessionsToRecover(
    int totalPointsHeld,
    int totalPointsAttended,
    double targetPercentage, {
    int sessionWeight = 1,
  }) {
    // Formula:
    // (Attended + x*W) / (Held + x*W) >= Target/100
    // Let T = Target/100
    // Attended + xW >= T(Held + xW)
    // Attended + xW >= T*Held + T*xW
    // xW - T*xW >= T*Held - Attended
    // xW(1 - T) >= T*Held - Attended
    // x >= (T*Held - Attended) / (W(1 - T))

    double t = targetPercentage / 100.0;

    // If current percentage is already above target, return 0
    if (totalPointsHeld > 0 && (totalPointsAttended / totalPointsHeld) >= t) {
      return 0;
    }

    double numerator = (t * totalPointsHeld) - totalPointsAttended;
    double denominator = sessionWeight * (1 - t);

    if (denominator <= 0) {
      // This mathematically shouldn't happen for reasonable targets (< 100%)
      // If target is 100%, denominator is 0. You can never reach 100% if you've missed any.
      return -1; // Impossible
    }

    double result = numerator / denominator;
    return result.ceil(); // Round up to the next whole session
  }

  /// Returns a status message based on the percentage.
  static String getStatusMessage(double percentage) {
    if (percentage >= 75) {
      return "Safe";
    } else if (percentage >= 65) {
      return "Warning";
    } else {
      return "Danger Zone";
    }
  }
}
