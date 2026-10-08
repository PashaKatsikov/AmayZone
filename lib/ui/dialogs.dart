import 'package:flutter/material.dart';

import '../core/art.dart';
import '../core/palette.dart';
import 'metal.dart';
import 'press_scale.dart';
import 'sprite_view.dart';

/// Modal card in the game's style. Resolves when the player taps the button.
Future<void> showCard(
  BuildContext context, {
  required String title,
  String? message,
  Widget? body,
  required String button,
  bool startSprite = false,
  bool dismissible = false,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: title,
    barrierColor: const Color(0xB3000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, _) {
      return Center(
        child: _Card(
          title: title,
          message: message,
          body: body,
          button: button,
          startSprite: startSprite,
        ),
      );
    },
    transitionBuilder: (_, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.message,
    required this.body,
    required this.button,
    required this.startSprite,
  });

  final String title;
  final String? message;
  final Widget? body;
  final String button;
  final bool startSprite;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * 0.86).clamp(0.0, 420.0);
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2A190B), Color(0xFF110A05)],
          ),
          border: Border.all(color: Palette.ember, width: 2.5),
          boxShadow: const [BoxShadow(color: Color(0x99FF8A00), blurRadius: 28, spreadRadius: 1)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Fonts.title(28, color: Palette.amber),
            ),
            if (message != null) ...[
              const SizedBox(height: 14),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Palette.cream, fontSize: 16, height: 1.35),
              ),
            ],
            if (body != null) ...[const SizedBox(height: 14), body!],
            const SizedBox(height: 22),
            if (startSprite)
              PressScale(
                onTap: () => Navigator.of(context).pop(),
                child: SpriteView(Art.I.startButton, width: width * 0.62),
              )
            else
              PlateButton(label: button, width: width * 0.62, fontSize: 20, onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}
