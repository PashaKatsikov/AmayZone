import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Tap target with a short squash animation. No ink, no material needed.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap, this.depth = 0.93});

  final Widget child;
  final VoidCallback? onTap;
  final double depth;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v || !mounted) return;
    // When onTap flips to null mid-press, the gesture detector cancels the
    // tap while the framework is still building; defer the rebuild then.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _down != v) setState(() => _down = v);
      });
      return;
    }
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.depth : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
