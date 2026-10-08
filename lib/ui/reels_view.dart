import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/art.dart';
import '../game/slot_engine.dart';
import 'sprite_view.dart';

/// The slot frame with five spinning reels inside it.
///
/// The widget only animates. Which symbols land is decided elsewhere and
/// handed over via [ReelsViewState.spin].
class ReelsView extends StatefulWidget {
  const ReelsView({
    super.key,
    required this.width,
    required this.initial,
    this.onReelLanded,
  });

  final double width;
  final List<List<int>> initial;
  final void Function(int reel)? onReelLanded;

  /// Playfield bounds inside the cropped frame sprite, as fractions.
  static const gridLeft = 0.0913;
  static const gridRight = 0.9071;
  static const gridTop = 0.148;
  static const gridBottom = 0.882;

  static double heightFor(double width) => width / Art.I.frame.aspect;

  @override
  ReelsViewState createState() => ReelsViewState();
}

class ReelsViewState extends State<ReelsView> with TickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2500);
  static const _reels = SlotEngine.reels;
  static const _rows = SlotEngine.rows;
  static const _settle = 0.86; // fraction of a reel's run after which it has landed
  static const _overshoot = 0.32; // cells

  final _rng = Random();
  late final AnimationController _run;
  late final AnimationController _pulse;
  Completer<void>? _done;

  late List<List<int>> _strips;
  final _dist = List<double>.filled(_reels, 0);
  final _landed = List<bool>.filled(_reels, false);
  final _speed = List<double>.filled(_reels, 0); // cells per frame
  final _lastPos = List<double>.filled(_reels, 0);
  int _mask = 0;

  // Reel r runs from _begin[r] to _end[r] of the shared clock.
  static final _begin = List.generate(_reels, (r) => r * 0.035);
  static final _end = List.generate(_reels, (r) => 0.56 + r * 0.11);

  bool get spinning => _run.isAnimating;

  @override
  void initState() {
    super.initState();
    _strips = [for (final c in widget.initial) List<int>.of(c)];
    _run = AnimationController(vsync: this, duration: _total)
      ..addListener(_onTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 750))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _run.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Rolls the reels and lands on [target] (`target[reel][row]`).
  Future<void> spin(List<List<int>> target) {
    assert(_done == null, 'spin() while already spinning');
    _done = Completer<void>();
    _mask = 0;
    for (var r = 0; r < _reels; r++) {
      final fill = 10 + ((_end[r] - _begin[r]) * 24).round();
      final strip = <int>[
        ..._strips[r].take(_rows),
        for (var i = 0; i < fill; i++) _rng.nextInt(SlotEngine.symbolCount),
        ...target[r],
        _rng.nextInt(SlotEngine.symbolCount), // visible during the overshoot
      ];
      _strips[r] = strip;
      _dist[r] = (strip.length - 1 - _rows).toDouble();
      _landed[r] = false;
      _speed[r] = 0;
      _lastPos[r] = 0;
    }
    _run.forward(from: 0);
    return _done!.future;
  }

  /// Skips to the end; reels settle quickly.
  void quickStop() {
    if (!_run.isAnimating) return;
    _run.animateTo(1, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  void showWins(int mask) {
    setState(() => _mask = mask);
  }

  void _onTick() {
    for (var r = 0; r < _reels; r++) {
      final pos = _position(r);
      _speed[r] = (pos - _lastPos[r]).abs();
      _lastPos[r] = pos;
      if (!_landed[r] && _t(r) >= _settle) {
        _landed[r] = true;
        widget.onReelLanded?.call(r);
      }
    }
  }

  void _finish() {
    for (var r = 0; r < _reels; r++) {
      _strips[r] = _strips[r].sublist(_strips[r].length - 1 - _rows, _strips[r].length - 1);
      _dist[r] = 0;
      if (!_landed[r]) {
        _landed[r] = true;
        widget.onReelLanded?.call(r);
      }
    }
    final done = _done;
    _done = null;
    setState(() {});
    done?.complete();
  }

  double _t(int r) {
    final span = _end[r] - _begin[r];
    return ((_run.value - _begin[r]) / span).clamp(0.0, 1.0);
  }

  /// Top row position (in cells) of reel [r] in the strip.
  double _position(int r) {
    if (_dist[r] == 0) return 0;
    final t = _t(r);
    final d = _dist[r];
    if (t < _settle) {
      return (d + _overshoot) * Curves.easeInOutCubic.transform(t / _settle);
    }
    final back = Curves.easeOutCubic.transform((t - _settle) / (1 - _settle));
    return d + _overshoot * (1 - back);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = ReelsView.heightFor(w);
    final grid = Rect.fromLTRB(
      w * ReelsView.gridLeft,
      h * ReelsView.gridTop,
      w * ReelsView.gridRight,
      h * ReelsView.gridBottom,
    );
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        children: [
          Positioned.fill(child: SpriteView(Art.I.frame)),
          Positioned.fromRect(
            rect: grid,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _GridPainter(this, Listenable.merge([_run, _pulse])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.state, Listenable repaint) : super(repaint: repaint);

  final ReelsViewState state;

  static final _glow = Paint()
    ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 10)
    ..color = const Color(0xFFFF9A1F);

  @override
  void paint(Canvas canvas, Size size) {
    final reels = SlotEngine.reels;
    final rows = SlotEngine.rows;
    final cw = size.width / reels;
    final ch = size.height / rows;
    final side = min(cw, ch) * 0.94;
    final art = Art.I;
    final pulse = Curves.easeInOut.transform(state._pulse.value);
    final spinning = state.spinning;

    for (var r = 0; r < reels; r++) {
      final strip = state._strips[r];
      final pos = state._position(r);
      final speed = spinning ? state._speed[r] : 0.0;

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(r * cw + 2, 0, cw - 4, size.height));

      final first = pos.floor() - 1;
      for (var i = first; i < first + rows + 3; i++) {
        if (i < 0 || i >= strip.length) continue;
        final cy = (i - pos) * ch + ch / 2;
        final cx = r * cw + cw / 2;
        final sprite = art.symbol(strip[i]);

        var scale = 1.0;
        if (!spinning) {
          final row = i; // at rest the strip is exactly the visible rows
          if (row >= 0 && row < rows && (state._mask >> (r * rows + row)) & 1 == 1) {
            final rect = Rect.fromCenter(center: Offset(cx, cy), width: cw - 10, height: ch - 8);
            final rr = RRect.fromRectAndRadius(rect, const Radius.circular(10));
            canvas.drawRRect(rr, _glow..color = const Color(0xFFFF9A1F).withValues(alpha: 0.3 + 0.35 * pulse));
            canvas.drawRRect(
              rr,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.5
                ..color = const Color(0xFFFFD27A).withValues(alpha: 0.55 + 0.45 * pulse),
            );
            scale = 1 + 0.08 * pulse;
          }
        }
        final dst = Rect.fromCenter(center: Offset(cx, cy), width: side * scale, height: side * scale);
        final paint = Paint()..filterQuality = FilterQuality.medium;
        if (speed > 0.12) {
          // Cheap motion blur: faint copies above and below the symbol.
          final smear = ch * min(speed * 2.4, 0.5);
          paint.color = const Color(0x44FFFFFF);
          canvas.drawImageRect(sprite.image, sprite.src, dst.shift(Offset(0, -smear)), paint);
          canvas.drawImageRect(sprite.image, sprite.src, dst.shift(Offset(0, smear)), paint);
          paint.color = const Color(0xCCFFFFFF);
        }
        canvas.drawImageRect(sprite.image, sprite.src, dst, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => true;
}
