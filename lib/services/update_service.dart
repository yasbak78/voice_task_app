import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:flutter/services.dart';

class ReleaseInfo {
  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final int downloadSize;

  const ReleaseInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.downloadSize,
  });
}

class UpdateService {
  static const String githubOwner = 'yasbak78';
  static const String githubRepo = 'voice_task_app';
  static const String releasesUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
  static const String _apkFileName = 'voice_task_app_update.apk';

  /// Compare two semver strings. Returns:
  ///  1 if a > b, -1 if a < b, 0 if equal
  static int compareVersions(String a, String b) {
    final aParts = a.split('.').map(int.tryParse).toList();
    final bParts = b.split('.').map(int.tryParse).toList();

    for (var i = 0; i < 3; i++) {
      final av = i < aParts.length ? (aParts[i] ?? 0) : 0;
      final bv = i < bParts.length ? (bParts[i] ?? 0) : 0;
      if (av > bv) return 1;
      if (av < bv) return -1;
    }
    return 0;
  }

  /// Check GitHub Releases for a newer version.
  /// Returns null if no update available or if repo doesn't exist yet.
  static Future<ReleaseInfo?> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      final response = await http
          .get(
            Uri.parse(releasesUrl),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 10));

      // 404 means no releases yet — not an error
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final body = json['body'] as String? ?? '';
      final assets = json['assets'] as List<dynamic>? ?? [];

      // Strip leading 'v' from tag (e.g., "v1.0.7" → "1.0.7")
      final releaseVersion = tagName.startsWith('v') ? tagName.substring(1) : tagName;

      // Find the APK asset
      String? downloadUrl;
      int downloadSize = 0;
      for (final asset in assets) {
        final name = (asset as Map<String, dynamic>)['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = asset['browser_download_url'] as String?;
          downloadSize = asset['size'] as int? ?? 0;
          break;
        }
      }

      if (downloadUrl == null) return null;

      // Compare versions
      final cmp = compareVersions(releaseVersion, currentVersion);
      if (cmp <= 0) return null; // No newer version

      return ReleaseInfo(
        version: releaseVersion,
        releaseNotes: body,
        downloadUrl: downloadUrl,
        downloadSize: downloadSize,
      );
    } catch (_) {
      // Network error, timeout, parse error — return null
      return null;
    }
  }

  /// Download APK with progress callbacks using streaming (memory-efficient).
  /// Returns the local file path.
  static Future<String> downloadApk({
    required String url,
    required void Function(int received, int total) onProgress,
  }) async {
    // Use cache directory — FileProvider can reliably share cache files with
    // the system PackageInstaller, unlike Android 11+ app-external directories.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$_apkFileName');
    if (file.existsSync()) await file.delete();

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final streamedResponse = await client.send(request).timeout(
            const Duration(minutes: 5),
          );

      final contentLength = streamedResponse.contentLength ?? 0;
      int received = 0;

      final sink = file.openWrite();
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress(received, contentLength > 0 ? contentLength : received);
      }
      await sink.flush();
      await sink.close();

      return file.path;
    } catch (e) {
      if (file.existsSync()) await file.delete();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Trigger Android package installer using native intent.
  /// Returns 'PERMISSION_REQUIRED' if the user needs to grant install permission.
  static Future<OpenResult> installApk(String filePath) async {
    const platform = MethodChannel('voice_task_app/installer');
    try {
      // Check if we have permission to install unknown apps
      final hasPermission = await platform.invokeMethod<bool>('checkInstallPermission') ?? false;
      if (!hasPermission) {
        // Open settings for the user to grant permission, then retry
        await platform.invokeMethod('openInstallSettings');
        return OpenResult(
          type: ResultType.error,
          message: 'PERMISSION_REQUIRED',
        );
      }

      await platform.invokeMethod('installApk', {'filePath': filePath});
      return OpenResult(type: ResultType.done, message: 'Install triggered');
    } on PlatformException {
      // Fallback to open_file if platform channel fails
      return OpenFile.open(filePath);
    }
  }
}
