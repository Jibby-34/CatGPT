import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;

class AdMobUtils {
  /// Get the AdMob App ID based on platform
  static String getAppId() {
    // App ID is the same for both platforms
    return 'ca-app-pub-6076315103458124~4607662796';
  }

  /// Get the Banner Ad Unit ID based on build mode and platform
  static String getBannerAdUnitId() {
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Google test banner ad unit ID
    } else {
      // Check platform and use appropriate ad unit ID
      if (Platform.isAndroid) {
        return const String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-8779910258241973/8973110065');
      } else if (Platform.isIOS) {
        return const String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-8779910258241973/9965802154');
      } else {
        // Fallback for other platforms
        return const String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-8779910258241973/8973110065');
      }
    }
  }

  /// Get the Rewarded Ad Unit ID based on build mode and platform
  static String getRewardedAdUnitId() {
    if (kDebugMode) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Google test rewarded ad unit ID
    } else {
      // Check platform and use appropriate ad unit ID
      if (Platform.isAndroid) {
        return const String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-8779910258241973/3872170088');
      } else if (Platform.isIOS) {
        return const String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-8779910258241973/3820030354');
      } else {
        // Fallback for other platforms
        return const String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-8779910258241973/3872170088');
      }
    }
  }

  /// Get the current platform name
  static String getPlatform() {
    if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isIOS) {
      return 'iOS';
    } else {
      return 'Unknown';
    }
  }

  /// Get the current build mode
  static String getBuildMode() {
    return kDebugMode ? 'DEBUG' : 'RELEASE';
  }
}




