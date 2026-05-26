import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shows a Material 3 update dialog with version info, release notes,
/// and an "Update Now" button that opens the download URL.
///
/// The dialog is dismissible by tapping outside or pressing "Later".
Future<void> showUpdateDialog(
  BuildContext context, {
  required String version,
  required String releaseNotes,
  required String downloadUrl,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        icon: Icon(
          Icons.system_update_outlined,
          size: 48,
          color: Theme.of(dialogContext).colorScheme.primary,
        ),
        title: const Text('Update Available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version $version',
                style: Theme.of(dialogContext).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 12),
              const Text(
                'What\'s new:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                releaseNotes,
                style: Theme.of(dialogContext).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton.icon(
            onPressed: () async {
              // Extract file ID from any Drive URL format, then build direct
              // download URL — this triggers the APK download/installer.
              String apkUrl = downloadUrl;
              final idMatch = RegExp(r'/d/([a-zA-Z0-9_-]+)').firstMatch(downloadUrl);
              if (idMatch != null) {
                final fileId = idMatch.group(1);
                apkUrl = 'https://drive.google.com/uc?export=download&id=$fileId';
              }
              final uri = Uri.parse(apkUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Update Now'),
          ),
        ],
      );
    },
  );
}
