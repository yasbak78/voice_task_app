import 'dart:math';
import 'package:flutter/material.dart';
import '../core/stt/audio_recorder.dart';
import '../core/theme/app_spacing.dart';

/// Painter for a single waveform bar with animated amplitude.
class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final RecordingState state;
  final Color barColor;

  WaveformPainter({
    required this.amplitudes,
    required this.state,
    required this.barColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = barColor;

    final barWidth = size.width / amplitudes.length;
    const barGap = 2.0;
    final maxBarHeight = size.height * 0.8;
    final centerY = size.height / 2;

    for (int i = 0; i < amplitudes.length; i++) {
      final amplitude = amplitudes[i].clamp(0.0, 1.0);
      final barHeight = amplitude * maxBarHeight;

      final x = i * barWidth + barGap / 2;
      final y = centerY - barHeight / 2;
      final width = barWidth - barGap;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, width, barHeight),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return amplitudes != oldDelegate.amplitudes ||
        state != oldDelegate.state;
  }
}

/// Animated waveform that pulses during recording.
/// Uses an AnimationController to drive smooth amplitude changes.
class AnimatedWaveform extends StatefulWidget {
  final bool isRecording;
  final Color? barColor;
  final double? height;

  const AnimatedWaveform({
    super.key,
    required this.isRecording,
    this.barColor,
    this.height = 80,
  });

  @override
  State<AnimatedWaveform> createState() => _AnimatedWaveformState();
}

class _AnimatedWaveformState extends State<AnimatedWaveform>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _amplitudes = List.filled(32, 0.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _controller.addListener(_updateAmplitudes);

    if (widget.isRecording) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
        // Animate to flat
        _animateToFlat();
      }
    }
  }

  void _animateToFlat() {
    // Set all amplitudes to 0 and trigger a repaint
    for (int i = 0; i < _amplitudes.length; i++) {
      _amplitudes[i] = 0.0;
    }
    setState(() {});
  }

  void _updateAmplitudes() {
    if (!widget.isRecording) return;

    final t = _controller.value;
    setState(() {
      for (int i = 0; i < _amplitudes.length; i++) {
        // Create a wave pattern: each bar has a different phase offset
        final phaseOffset = (i / _amplitudes.length) * 2 * 3.14159;
        // Combine multiple sine waves for organic feel
        final wave1 = (0.5 + 0.5 * sin(t * 2 * 3.14159 + phaseOffset));
        final wave2 =
            (0.5 + 0.5 * sin(t * 3.14159 * 1.5 + phaseOffset * 0.7));
        final wave3 =
            (0.5 + 0.5 * sin(t * 3.14159 * 2.3 + phaseOffset * 1.3));
        _amplitudes[i] = (wave1 * 0.4 + wave2 * 0.35 + wave3 * 0.25) * 0.9;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.barColor ?? theme.colorScheme.primary;

    return Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: CustomPaint(
        painter: WaveformPainter(
          amplitudes: _amplitudes,
          state: widget.isRecording
              ? RecordingState.recording
              : RecordingState.idle,
          barColor: color,
        ),
        size: Size(double.infinity, widget.height!),
      ),
    );
  }
}
