import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Collects crash reports and device diagnostics for local sharing.
class CrashReporter {
  static const String _dirName = 'crash_reports';
  static const String _logPrefix = 'crash_';

  static Future<Directory> _crashDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Format a crash entry with timestamp, device info, and stack trace.
  static Future<String> _formatReport({
    required String title,
    required String stackTrace,
    String? additionalContext,
  }) async {
    final now = DateTime.now().toUtc();
    String deviceInfo = '';
    try {
      deviceInfo = [
        'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'Model: ${Platform.localHostname}',
      ].join('\n');
    } catch (_) {}

    String appVersion = 'unknown';
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version} (${info.buildNumber})';
    } catch (_) {}

    final buffer = StringBuffer();
    buffer.writeln('=== Voice Tasks Crash Report ===');
    buffer.writeln('Date: ${now.toString()}');
    buffer.writeln('App Version: $appVersion');
    buffer.writeln('');
    buffer.writeln('--- Device Info ---');
    buffer.writeln(deviceInfo);
    buffer.writeln('');
    buffer.writeln('--- Error ---');
    buffer.writeln(title);
    buffer.writeln('');
    buffer.writeln('--- Stack Trace ---');
    buffer.writeln(stackTrace);
    if (additionalContext != null && additionalContext.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('--- Context ---');
      buffer.writeln(additionalContext);
    }
    return buffer.toString();
  }

  /// Save a crash report to disk. Returns the file path.
  static Future<String> saveReport({
    required String title,
    required String stackTrace,
    String? context,
  }) async {
    final dir = await _crashDir();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final file = File('${dir.path}/$_logPrefix$timestamp.txt');
    final report = await _formatReport(
      title: title,
      stackTrace: stackTrace,
      additionalContext: context,
    );
    await file.writeAsString(report);
    return file.path;
  }

  /// Get list of crash report files, newest first.
  static Future<List<File>> listReports() async {
    final dir = await _crashDir();
    if (!await dir.exists()) return [];
    final files = await dir.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.contains(_logPrefix))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
  }

  /// Get the most recent crash report file, if any.
  static Future<File?> latestReport() async {
    final reports = await listReports();
    return reports.isNotEmpty ? reports.first : null;
  }

  /// Delete all crash reports.
  static Future<void> clearReports() async {
    final dir = await _crashDir();
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Get total number of crash reports.
  static Future<int> reportCount() async {
    final reports = await listReports();
    return reports.length;
  }

  /// Save a crash report and immediately share it via the device share sheet.
  /// This is the primary action for the "Save Report" button on crash screens.
  static Future<ShareResult> saveAndShare({
    required String title,
    required String stackTrace,
    String? context,
  }) async {
    final path = await saveReport(
      title: title,
      stackTrace: stackTrace,
      context: context,
    );
    return Share.shareXFiles(
      [XFile(path)],
      subject: 'Voice Tasks Crash Report',
      text: 'Crash report for Voice Tasks app.',
    );
  }
}
