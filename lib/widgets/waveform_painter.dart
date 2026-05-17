import 'package:flutter/material.dart';
import '../core/stt/audio_recorder.dart';

class WaveformPainter extends CustomPainter {
  final List<double> amplitudes;
  final RecordingState state;

  WaveformPainter({
    required this.amplitudes,
    required this.state,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty) return;

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = _getBarColor();

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

  Color _getBarColor() {
    switch (state) {
      case RecordingState.recording:
        return Colors.redAccent;
      case RecordingState.processing:
        return Colors.orange;
      case RecordingState.done:
        return Colors.green;
      case RecordingState.error:
        return Colors.red;
      case RecordingState.idle:
        return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return amplitudes != oldDelegate.amplitudes ||
           state != oldDelegate.state;
  }
}
