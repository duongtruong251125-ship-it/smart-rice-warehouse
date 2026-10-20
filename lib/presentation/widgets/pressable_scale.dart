import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget hỗ trợ hiệu ứng thu nhỏ nhẹ nhàng (Scale Press) khi người dùng nhấn/chạm
/// Tạo cảm giác xúc giác (tactile feeling) chân thật, tự nhiên và mượt mà.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleFactor = 0.98,
    this.duration = const Duration(milliseconds: 180),
    this.enableHaptic = true,
    this.borderRadius,
    this.semanticLabel,
    this.minTouchTargetSize = 44.0,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final Duration duration;
  final bool enableHaptic;
  final BorderRadius? borderRadius;
  final String? semanticLabel;
  final double minTouchTargetSize;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      reverseDuration: widget.duration,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
  }

  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (widget.enableHaptic) {
      HapticFeedback.selectionClick();
    }
    if (!_reducedMotion && mounted) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (!_reducedMotion && mounted) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (!_reducedMotion && mounted) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    final content = _reducedMotion
        ? widget.child
        : AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                alignment: Alignment.center,
                child: child,
              );
            },
            child: widget.child,
          );

    return Semantics(
      button: true,
      enabled: true,
      label: widget.semanticLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: widget.minTouchTargetSize,
          minWidth: widget.minTouchTargetSize,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: content,
        ),
      ),
    );
  }
}
