import 'package:flutter/material.dart';

/// Shimmer loading effect widget — used during voice processing state.
/// Shows an animated gradient sweep across a placeholder shape.
class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.shape,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _animation = Tween<double>(begin: -2.0, end: 2.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest;
    final highlightColor = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: 0.5);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: widget.shape ??
                RoundedRectangleBorder(
                  borderRadius:
                      widget.borderRadius ?? BorderRadius.circular(8),
                ),
            gradient: LinearGradient(
              begin: Alignment(_animation.value, 0),
              end: Alignment(_animation.value + 0.5, 0),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer effect for a list of placeholder tiles.
class ShimmerTileList extends StatelessWidget {
  final int count;
  final double itemHeight;

  const ShimmerTileList({
    super.key,
    this.count = 3,
    this.itemHeight = 72,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final titleWidth = 120.0 + (index % 3) * 40;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ShimmerLoading(width: 24, height: 24, shape: CircleBorder()),
                  const SizedBox(width: 12),
                  ShimmerLoading(
                    width: titleWidth,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ShimmerLoading(
                width: 60 + (index % 2) * 30,
                height: 12,
                borderRadius: BorderRadius.circular(6),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Shimmer loading overlay for voice processing state.
/// Can be shown as an overlay on top of any widget.
class ProcessingOverlay extends StatelessWidget {
  final Widget child;
  final bool isProcessing;
  final String? processingText;

  const ProcessingOverlay({
    super.key,
    required this.child,
    required this.isProcessing,
    this.processingText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        child,
        if (isProcessing)
          Container(
            color: theme.colorScheme.surface.withValues(alpha: 0.85),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    processingText ?? 'Processing...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
