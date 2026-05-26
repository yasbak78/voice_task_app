import 'package:flutter/material.dart';
import '../../core/haptics/app_haptics.dart';
import '../core/theme/app_spacing.dart';

/// A wrapper that adds tap-down scale animation + ripple to any child widget.
/// Scales down to [pressedScale] on tap down, returns to 1.0 on tap up.
/// Includes InkWell for Material ripple effect.
class ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;
  final Duration duration;
  final BorderRadius? borderRadius;

  const ScaleOnTap({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.95,
    this.duration = const Duration(milliseconds: 150),
    this.borderRadius,
  });

  @override
  State<ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<ScaleOnTap>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: 1.0,
    );
    _animation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.reverse();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.forward();
    AppHaptics.tap();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Transform.scale(
            scale: _animation.value,
            child: child,
          );
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(AppSpacing.radiusLg),
            onTap: widget.onTap,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
