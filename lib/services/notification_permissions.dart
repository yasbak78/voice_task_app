import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Handles notification permission requests and checks.
class NotificationPermissions {
  /// Request notification permission. Returns true if granted.
  static Future<bool> request() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }

    final status = await Permission.notification.status;
    if (status.isGranted) {
      return true;
    }

    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Check if notification permission is currently granted.
  static Future<bool> isGranted() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    final status = await Permission.notification.status;
    return status.isGranted;
  }
}
