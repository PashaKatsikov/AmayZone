import 'dart:async';

import 'package:flutter/material.dart';

import '../core/art.dart';
import '../core/format.dart';
import '../core/links.dart';
import '../core/palette.dart';
import '../game/session.dart';
import '../ui/dialogs.dart';
import '../ui/metal.dart';
import '../ui/sprite_view.dart';
import 'game_screen.dart';
import 'paytable_screen.dart';
import 'web_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.session});

  final Session session;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _breath;
  Timer? _ticker;

  Session get s => widget.session;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);
    // Drives the daily-bonus countdown.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !s.dailyReady) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _breath.dispose();
    super.dispose();
  }

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Future<void> _claimDaily() async {
    if (!s.claimDaily()) return;
    setState(() {});
    await showCard(
      context,
      title: 'DAILY BONUS',
      message: '+${groupDigits(Session.dailyAmount)} coins have been added to your balance.\nCome back tomorrow for more!',
      button: 'AWESOME',
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final art = Art.I;

    return Scaffold(
      backgroundColor: Palette.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CoverSprite(art.background),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0x00000000), Color(0x99000000)],
              ),
            ),
          ),
          SafeArea(
            child: ListenableBuilder(
              listenable: s,
              builder: (context, _) => Column(
                children: [
                  const SizedBox(height: 10),
                  ReadoutPlate(
                    caption: 'BALANCE',
                    width: w * 0.46,
                    value: Text(groupDigits(s.shownBalance), style: Fonts.title(22, color: Colors.white)),
                  ),
                  const Spacer(flex: 2),
                  AnimatedBuilder(
                    animation: _breath,
                    builder: (context, child) => Transform.scale(
                      scale: 1 + 0.025 * Curves.easeInOut.transform(_breath.value),
                      child: child,
                    ),
                    child: SpriteView(art.logo, width: w * 0.84),
                  ),
                  const Spacer(flex: 2),
                  PlateButton(
                    label: 'PLAY',
                    width: w * 0.68,
                    fontSize: 34,
                    onTap: () => _push(GameScreen(session: s)),
                  ),
                  const SizedBox(height: 10),
                  PlateButton(
                    label: 'DAILY BONUS',
                    caption: s.dailyReady
                        ? 'TAP TO COLLECT ${groupDigits(Session.dailyAmount)}'
                        : 'NEXT IN ${clock(s.dailyWait)}',
                    width: w * 0.68,
                    fontSize: 22,
                    onTap: s.dailyReady ? _claimDaily : null,
                  ),
                  const SizedBox(height: 10),
                  PlateButton(
                    label: 'HOW TO PLAY',
                    width: w * 0.68,
                    fontSize: 22,
                    onTap: () => _push(PaytableScreen(session: s)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      PlateButton(
                        label: 'PRIVACY POLICY',
                        width: w * 0.36,
                        fontSize: 15,
                        onTap: () => _push(const WebScreen(title: 'Privacy Policy', url: Links.privacyPolicy)),
                      ),
                      SizedBox(width: w * 0.02),
                      PlateButton(
                        label: 'SUPPORT',
                        width: w * 0.36,
                        fontSize: 15,
                        onTap: () => _push(const WebScreen(title: 'Support', url: Links.support)),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 6, 24, 12),
                    child: Text(
                      'For entertainment only. Coins have no cash value and\ncannot be exchanged for real money or prizes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Palette.cream.withValues(alpha: 0.7), fontSize: 11, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

