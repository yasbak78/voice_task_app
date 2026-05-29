import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:voice_task_app/core/haptics/app_haptics.dart';
import 'package:voice_task_app/services/update_service.dart';
enum _UpdateState {
  checking,
  noUpdate,
  available,
  downloading,
  readyToInstall,
  error,
}

/// Shows an update check flow: check → show release notes → download → install.
Future<void> showUpdateDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const _UpdateDialog(),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog();

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  _UpdateState _state = _UpdateState.checking;
  ReleaseInfo? _releaseInfo;
  int _received = 0;
  int _total = 0;
  String _error = '';
  String? _downloadedPath;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _state = _UpdateState.checking);
    try {
      final info = await UpdateService.checkForUpdate();
      if (!mounted) return;

      if (info == null) {
        setState(() => _state = _UpdateState.noUpdate);
      } else {
        setState(() {
          _releaseInfo = info;
          _state = _UpdateState.available;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _state = _UpdateState.error;
      });
    }
  }

  Future<void> _download() async {
    if (_releaseInfo == null) return;
    setState(() {
      _state = _UpdateState.downloading;
      _received = 0;
      _total = _releaseInfo!.downloadSize;
    });

    try {
      final path = await UpdateService.downloadApk(
        url: _releaseInfo!.downloadUrl,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _received = received;
              _total = total;
            });
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _downloadedPath = path;
        _state = _UpdateState.readyToInstall;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Download failed: $e';
        _state = _UpdateState.error;
      });
    }
  }

  Future<void> _install() async {
    if (_downloadedPath == null) return;
    AppHaptics.tap();
    final result = await UpdateService.installApk(_downloadedPath!);
    if (!mounted) return;
    // Close the dialog after triggering the install
    if (result.type == ResultType.done) {
      if (context.mounted) Navigator.of(context).pop();
    } else if (result.message == 'PERMISSION_REQUIRED') {
      // User was sent to settings to grant permission; show guidance
      if (!mounted) return;
      setState(() {
        _error = 'Enable "Allow from this source" in Settings, then tap Install again.';
        _state = _UpdateState.readyToInstall;
      });
    } else {
      setState(() {
        _error = 'Install failed: ${result.message}';
        _state = _UpdateState.error;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: switch (_state) {
        _UpdateState.checking => const Text('Checking for updates...'),
        _UpdateState.noUpdate => const Text('Up to Date'),
        _UpdateState.available => Text('Update to v${_releaseInfo!.version}'),
        _UpdateState.downloading => const Text('Downloading Update...'),
        _UpdateState.readyToInstall => const Text('Update Ready'),
        _UpdateState.error => const Text('Update Error'),
      },
      content: SizedBox(
        width: double.maxFinite,
        child: switch (_state) {
          _UpdateState.checking => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Checking GitHub Releases...'),
              ],
            ),
          _UpdateState.noUpdate => const Text(
              'You\'re running the latest version. No updates available.',
            ),
          _UpdateState.available => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Version ${_releaseInfo!.version} is available',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (_releaseInfo!.releaseNotes.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Text(
                        _releaseInfo!.releaseNotes,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                if (_releaseInfo!.downloadSize > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Download size: ${_formatBytes(_releaseInfo!.downloadSize)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
              ],
            ),
          _UpdateState.downloading => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: _total > 0 ? _received / _total : null,
                  minHeight: 8,
                ),
                const SizedBox(height: 12),
                Text(
                  _total > 0
                      ? '${_formatBytes(_received)} / ${_formatBytes(_total)}'
                      : 'Downloading...',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          _UpdateState.readyToInstall => const Text(
              'Download complete. Tap "Install" to update the app.',
            ),
          _UpdateState.error => Text(
              _error.isNotEmpty ? _error : 'An unknown error occurred.',
              style: const TextStyle(color: Colors.red),
            ),
        },
      ),
      actions: [
        if (_state == _UpdateState.noUpdate || _state == _UpdateState.error)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        if (_state == _UpdateState.available) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: _download,
            child: const Text('Download'),
          ),
        ],
        if (_state == _UpdateState.readyToInstall) ...[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: _install,
            child: const Text('Install'),
          ),
        ],
      ],
    );
  }
}
