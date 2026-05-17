import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voice_task_app/core/stt/audio_recorder.dart';
import 'package:voice_task_app/core/stt/wav_converter.dart';
import 'package:voice_task_app/core/stt/whisper_service.dart';
import 'package:voice_task_app/screens/preview/preview_screen.dart';

/// Voice recording screen with real-time recording and transcription.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  static const route = '/record';

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final AudioRecorderService _recorder = AudioRecorderService();
  final WhisperService _whisperService = WhisperService();
  Timer? _timer;
  bool _isProcessing = false;
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _whisperService.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_recorder.state == RecordingState.recording) {
      await _stopRecording();
    } else if (_recorder.state == RecordingState.idle ||
        _recorder.state == RecordingState.done ||
        _recorder.state == RecordingState.error) {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
      _isProcessing = false;
    });

    try {
      await _recorder.startRecording();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Microphone access denied');
      }
    }
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    setState(() => _isProcessing = true);

    try {
      final path = await _recorder.stopRecording();
      if (path == null) {
        setState(() {
          _isProcessing = false;
          _error = 'No audio recorded';
        });
        return;
      }

      // Convert to whisper.cpp format (16kHz mono 16-bit WAV)
      final wavPath = await WavConverter.convertToWhisperFormat(path);

      // Transcribe using whisper.cpp FFI
      final transcription = await _whisperService.transcribe(wavPath);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      // Handle no speech detected
      if (transcription.isEmpty || transcription.contains('[No speech')) {
        setState(() => _error = 'No speech detected. Try again.');
        return;
      }

      // Navigate to preview with transcription for review
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        PreviewScreen.route,
        arguments: transcription,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _error = 'Transcription failed: $e';
      });
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Task'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Timer display
            Text(
              _formatDuration(_recorder.duration),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
            const SizedBox(height: 16),

            // State indicator
            _buildStateIndicator(),
            const SizedBox(height: 48),

            // Record button (disabled while processing)
            GestureDetector(
              onTap: _isProcessing ? null : _toggleRecording,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isProcessing
                      ? Colors.grey.withOpacity(0.3)
                      : _recorder.state == RecordingState.recording
                          ? Colors.red.withOpacity(0.1)
                          : Colors.grey.shade100,
                  border: Border.all(
                    color: _isProcessing
                        ? Colors.grey
                        : _recorder.state == RecordingState.recording
                            ? Colors.red
                            : Colors.grey.shade300,
                    width: _recorder.state == RecordingState.recording ? 4 : 2,
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : Icon(
                        _recorder.state == RecordingState.recording
                            ? Icons.stop
                            : Icons.mic,
                        size: 48,
                        color: _recorder.state == RecordingState.recording
                            ? Colors.red
                            : Colors.grey.shade700,
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // Status text
            Text(
              _isProcessing
                  ? 'Transcribing...'
                  : _recorder.state == RecordingState.recording
                      ? 'Tap to stop'
                      : 'Tap to record',
              style: TextStyle(
                color: _isProcessing
                    ? Colors.indigo
                    : Colors.grey.shade600,
                fontSize: 16,
              ),
            ),

            if (_recorder.state == RecordingState.error || _error != null) ...[
              const SizedBox(height: 24),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _error ?? 'Recording failed. Try again.',
                  style: TextStyle(color: Colors.red.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStateIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _stateDot(RecordingState.idle, 'Ready'),
        _stateDot(RecordingState.recording, 'Recording'),
        _stateDot(RecordingState.processing, 'Processing'),
      ],
    );
  }

  Widget _stateDot(RecordingState state, String label) {
    final isActive = _recorder.state == state ||
        (_isProcessing && state == RecordingState.processing);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? (state == RecordingState.recording
                      ? Colors.red
                      : Colors.indigo)
                  : Colors.grey.shade300,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? Colors.indigo : Colors.grey.shade500,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
