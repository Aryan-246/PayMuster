import 'package:flutter/material.dart';
import '../../theme/paymuster_tokens.dart';

class PMSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final BoxShape shape;

  const PMSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  factory PMSkeleton.text({
    required double width,
    double height = 16,
    Key? key,
  }) {
    return PMSkeleton(
      key: key,
      width: width,
      height: height,
      borderRadius: PMRadius.sm,
    );
  }

  factory PMSkeleton.circular({
    required double size,
    Key? key,
  }) {
    return PMSkeleton(
      key: key,
      width: size,
      height: size,
      shape: BoxShape.circle,
    );
  }

  @override
  State<PMSkeleton> createState() => _PMSkeletonState();
}

class _PMSkeletonState extends State<PMSkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseColor = isDark ? PMColors.bgSurfaceDark : PMColors.bgSurfaceLight;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: baseColor,
              shape: widget.shape,
              borderRadius: widget.shape == BoxShape.circle ? null : (widget.borderRadius ?? PMRadius.md),
            ),
          ),
        );
      },
    );
  }
}
