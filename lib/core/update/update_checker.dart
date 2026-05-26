import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Google Drive file ID for version.json.
const String versionJsonFileId = '1MsRU5krtw9u9s9T_jhOhDtK3pVnSRkdO';

/// Parses a version string like "1.0.5" into a list of ints [1, 0, 5].
List<int> _parseVersion(String v) {
  return v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
}

/// Compares two semantic versions. Returns >0 if a>b, <0 if a<b, 0 if equal.
int _compareVersions(String a, String b) {
  final partsA = _parseVersion(a);
  final partsB = _parseVersion(b);
  final maxLen = partsA.length > partsB.length ? partsA.length : partsB.length;
  for (int i = 0; i < maxLen; i++) {
    final va = i < partsA.length ? partsA[i] : 0;
    final vb = i < partsB.length ? partsB[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}

/// Represents update information fetched from the remote version.json.
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

/// Service class that checks for app updates by fetching a remote version.json.
class UpdateChecker {
  /// Fetches the remote version.json and returns [UpdateInfo] if an update
  /// is available (remote version > installed version), or null otherwise.
  ///
  /// Handles network failures, malformed JSON, and timeouts (10s) gracefully.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      // Get current installed version
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.5"

      final directUrl = 'https://drive.google.com/uc?export=download&id=$versionJsonFileId';
      final url = Uri.parse(directUrl);
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Support both 'version' and 'latest_version' keys for backward compat
      final version = (data['latest_version'] ?? data['version']) as String?;
      final downloadUrl = data['download_url'] as String?;
      final releaseNotes = data['release_notes'] as String?;

      if (version == null || downloadUrl == null) {
        return null;
      }

      // Only return update info if remote version is strictly greater
      if (_compareVersions(version, currentVersion) <= 0) {
        return null;
      }

      // Pass the original download URL directly — the dialog will convert
      // to uc?export=download for the actual APK download trigger.
      return UpdateInfo(
        version: version,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes ?? '',
      );
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }
}
