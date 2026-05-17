import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/stt/audio_recorder.dart';
import '../../providers/stt_providers.dart';
import '../../widgets/waveform_painter.dart';

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final List<double> _amplitudes = List.filled(50, 0.0);
  StreamSubscription? _ampSubscription;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startAmplitudeListener();
  }

  void _startAmplitudeListener() {
    final recorder = ref.read(audioRecorderProvider);
    _ampSubscription = recorder.amplitudeStream.listen((amp) {
      setState(() {
        _amplitudes.removeAt(0);
        _amplitudes.add(amp.current.abs());
      });
    });
  }

  @override
  void dispose() {
    _ampSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final recorder = ref.read(audioRecorderProvider);
    setState(() => _error = null);

    try {
      if (recorder.state == RecordingState.recording) {
        await recorder.stopRecording();
      } else {
        _amplitudes.fillRange(0, _amplitudes.length, 0.0);
        await recorder.startRecording();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recordingStateProvider);
    final duration = ref.watch(recordingDurationProvider);
    final transcriptionAsync = ref.watch(transcriptionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Voice Record')),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Duration display
            Text(
              _formatDuration(duration),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            
            // Waveform
            SizedBox(
              height: 100,
              width: double.infinity,
              child: CustomPaint(
                painter: WaveformPainter(
                  amplitudes: _amplitudes,
                  state: state,
                ),
              ),
            ),
            
            // State indicator
            _buildStateIndicator(state),
            
            // Transcript result
            if (transcriptionAsync != null && transcriptionAsync.hasValue)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    transcriptionAsync.value!,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            
            // Error display
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // Mic button
            GestureDetector(
              onTapDown: (_) => _toggleRecording(),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: state == RecordingState.recording
                      ? Colors.red
                      : Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (state == RecordingState.recording
                              ? Colors.red
                              : Theme.of(context).primaryColor)
                          .withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  state == RecordingState.recording
                      ? Icons.stop
                      : Icons.mic,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStateIndicator(RecordingState state) {
    String text;
    switch (state) {
      case RecordingState.idle:
        text = 'Tap mic to start recording';
      case RecordingState.recording:
        text = 'Recording...';
      case RecordingState.processing:
        text = 'Processing audio...';
      case RecordingState.done:
        text = 'Done';
      case RecordingState.error:
        text = 'Error';
    }
    
    return Text(
      text,
      style: TextStyle(
        color: state == RecordingState.error ? Colors.red : Colors.grey[600],
        fontSize: 16,
      ),
    );
  }
}
