import 'package:package_info_plus/package_info_plus.dart';

/// Returns the current app version string (e.g., "1.0.4").
Future<String> getCurrentVersion() async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version;
}

/// Compares two semver strings and returns true if [remoteVersion] is greater
/// than [localVersion]. Handles major.minor.patch as integers.
///
/// Example: isSemverGreater("1.2.0", "1.1.0") → true
///          isSemverGreater("1.0.4", "1.0.4") → false
///          isSemverGreater("2.0.0", "1.9.9") → true
bool isSemverGreater(String remoteVersion, String localVersion) {
  final remoteParts = _parseSemver(remoteVersion);
  final localParts = _parseSemver(localVersion);

  if (remoteParts == null || localParts == null) return false;

  // Compare major
  if (remoteParts[0] > localParts[0]) return true;
  if (remoteParts[0] < localParts[0]) return false;

  // Compare minor
  if (remoteParts[1] > localParts[1]) return true;
  if (remoteParts[1] < localParts[1]) return false;

  // Compare patch
  if (remoteParts[2] > localParts[2]) return true;
  if (remoteParts[2] < localParts[2]) return false;

  // Equal versions — no update needed
  return false;
}

/// Checks if an update is available by comparing [remoteVersion] against
/// the current app version.
Future<bool> isUpdateAvailable({required String remoteVersion}) async {
  final localVersion = await getCurrentVersion();
  return isSemverGreater(remoteVersion, localVersion);
}

/// Parse a semver string into [major, minor, patch] integers.
/// Returns null if parsing fails.
List<int>? _parseSemver(String version) {
  try {
    // Strip any build metadata (e.g., "1.0.4+5" → "1.0.4")
    final cleanVersion = version.split('+').first;
    final parts = cleanVersion.split('.');
    if (parts.length < 3) return null;
    return [
      int.parse(parts[0].trim()),
      int.parse(parts[1].trim()),
      int.parse(parts[2].trim()),
    ];
  } catch (_) {
    return null;
  }
}
