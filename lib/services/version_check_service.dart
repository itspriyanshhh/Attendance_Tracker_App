import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service to check app version and enforce updates
class VersionCheckService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Compare two version strings (e.g., "1.2.3")
  /// Returns:
  ///   1 if v1 > v2
  ///   0 if v1 == v2
  ///  -1 if v1 < v2
  static int compareVersions(String v1, String v2) {
    List<int> v1Parts = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> v2Parts = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // Ensure both have 3 parts
    while (v1Parts.length < 3) {
      v1Parts.add(0);
    }
    while (v2Parts.length < 3) {
      v2Parts.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (v1Parts[i] > v2Parts[i]) return 1;
      if (v1Parts[i] < v2Parts[i]) return -1;
    }
    return 0;
  }

  /// Check if update is required
  /// Returns a map with update information
  static Future<Map<String, dynamic>> checkForUpdate() async {
    try {
      print('🔍 [VERSION CHECK] Starting version check...');

      // Get current app version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;
      print('📱 [VERSION CHECK] Current app version: $currentVersion');

      // Fetch minimum required version from Firestore
      print('🔥 [VERSION CHECK] Fetching version from Firestore...');
      DocumentSnapshot doc = await _firestore
          .collection('app_config')
          .doc('version_control')
          .get();

      if (!doc.exists) {
        print('❌ [VERSION CHECK] Firestore document does NOT exist!');
        print(
          '⚠️  Create document: app_config/version_control in Firebase Console',
        );
        return {
          'updateRequired': false,
          'currentVersion': currentVersion,
          'error': 'Firestore document not found',
        };
      }

      print('✅ [VERSION CHECK] Firestore document found!');
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      print('📄 [VERSION CHECK] Firebase data: $data');

      String minRequiredVersion = data['min_required_version'] ?? '1.0.0';
      bool forceUpdate = data['force_update'] ?? false;
      String updateMessage =
          data['update_message'] ??
          'A new version is available. Please update to continue using Attendify.';

      print('🔢 [VERSION CHECK] Min required version: $minRequiredVersion');
      print('🔐 [VERSION CHECK] Force update enabled: $forceUpdate');

      // Compare versions
      int comparison = compareVersions(currentVersion, minRequiredVersion);
      bool needsUpdate = comparison < 0; // Current version is older

      print('⚖️  [VERSION CHECK] Version comparison result: $comparison');
      print('   Current: $currentVersion vs Required: $minRequiredVersion');
      print('   Needs update: $needsUpdate');
      print('   Will show dialog: ${needsUpdate && forceUpdate}');

      final result = {
        'updateRequired': needsUpdate && forceUpdate,
        'currentVersion': currentVersion,
        'minRequiredVersion': minRequiredVersion,
        'latestVersion': data['latest_version'] ?? minRequiredVersion,
        'message': updateMessage,
        'forceUpdate': forceUpdate,
      };

      print('📦 [VERSION CHECK] Final result: $result');
      return result;
    } catch (e) {
      print('❌ [VERSION CHECK] ERROR: $e');
      print('💡 Possible causes:');
      print('   1. Firebase not initialized');
      print('   2. google-services.json package name mismatch');
      print('   3. No internet connection');
      print('   4. Firestore rules blocking access');
      // On error, don't block users
      return {'updateRequired': false, 'error': e.toString()};
    }
  }

  /// Open Play Store for app update
  static Future<void> openPlayStore() async {
    const String packageName = 'com.priyanshhh.attendify';
    final Uri playStoreUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$packageName',
    );

    try {
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
      } else {
        print('Could not launch Play Store');
      }
    } catch (e) {
      print('Error opening Play Store: $e');
    }
  }
}
