import 'package:flutter/material.dart';

import '../core/art.dart';
import '../core/palette.dart';
import 'press_scale.dart';
import 'sprite_view.dart';

/// Metal plate with centred text, used for buttons across the menus.
class PlateButton extends StatelessWidget {
  const PlateButton({
    super.key,
    required this.label,
    required this.onTap,
    this.width = 240,
    this.fontSize = 20,
    this.caption,
  });

  final String label;
  final String? caption;
  final VoidCallback? onTap;
  final double width;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final sprite = Art.I.panel;
    final height = width / sprite.aspect;
    final enabled = onTap != null;
    return PressScale(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: SpriteView(sprite, tint: enabled ? null : dimmed)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: width * 0.1),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, style: Fonts.title(fontSize, color: enabled ? Palette.cream : Colors.white54)),
                  ),
                  if (caption != null)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        caption!,
                        style: Fonts.title(fontSize * 0.55, color: Palette.amber),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Non-interactive plate that shows a small caption over a value.
class ReadoutPlate extends StatelessWidget {
  const ReadoutPlate({super.key, required this.caption, required this.value, required this.width});

  final String caption;
  final Widget value;
  final double width;

  @override
  Widget build(BuildContext context) {
    final sprite = Art.I.panel;
    final height = width / sprite.aspect;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: SpriteView(sprite)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: width * 0.14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(caption, style: Fonts.title(width * 0.068, color: Palette.amber)),
                SizedBox(height: height * 0.02),
                FittedBox(fit: BoxFit.scaleDown, child: value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
