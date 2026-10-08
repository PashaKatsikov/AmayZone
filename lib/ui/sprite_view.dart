import 'package:flutter/material.dart';

import '../core/art.dart';

/// Draws a [Sprite] scaled to fill its box. Give it a size with the right
/// aspect (see [Sprite.aspect]) or let [SpriteView.sized] derive one.
class SpriteView extends StatelessWidget {
  const SpriteView(this.sprite, {super.key, this.width, this.height, this.opacity = 1, this.tint});

  final Sprite sprite;
  final double? width;
  final double? height;
  final double opacity;
  final ColorFilter? tint;

  @override
  Widget build(BuildContext context) {
    var w = width;
    var h = height;
    if (w == null && h != null) w = h * sprite.aspect;
    if (h == null && w != null) h = w / sprite.aspect;
    return CustomPaint(
      size: Size(w ?? sprite.src.width, h ?? sprite.src.height),
      painter: _SpritePainter(sprite, opacity, tint),
    );
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.sprite, this.opacity, this.tint);

  final Sprite sprite;
  final double opacity;
  final ColorFilter? tint;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true
      ..color = Color.fromRGBO(255, 255, 255, opacity);
    if (tint != null) paint.colorFilter = tint;
    canvas.drawImageRect(sprite.image, sprite.src, Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(_SpritePainter old) =>
      old.sprite.image != sprite.image ||
      old.sprite.src != sprite.src ||
      old.opacity != opacity ||
      old.tint != tint;
}

/// Fills the available space with [sprite], cropping the overflow
/// (like `BoxFit.cover`).
class CoverSprite extends StatelessWidget {
  const CoverSprite(this.sprite, {super.key});

  final Sprite sprite;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SpriteView(sprite),
        ),
      ),
    );
  }
}

/// Greyed-out look for disabled controls.
const dimmed = ColorFilter.matrix(<double>[
  0.35, 0.35, 0.10, 0, 0,
  0.35, 0.35, 0.10, 0, 0,
  0.35, 0.35, 0.10, 0, 0,
  0, 0, 0, 1, 0,
]);
