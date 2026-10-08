import 'dart:async';

import 'package:flutter/material.dart';

import '../core/art.dart';
import '../core/format.dart';
import '../core/links.dart';
import '../core/palette.dart';
import '../game/session.dart';
import '../game/slot_engine.dart';
import '../ui/dialogs.dart';
import '../ui/metal.dart';
import '../ui/press_scale.dart';
import '../ui/reels_view.dart';
import '../ui/sprite_view.dart';
import 'paytable_screen.dart';
import 'web_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.session});

  final Session session;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _reels = GlobalKey<ReelsViewState>();

  bool _busy = false; // a round is in progress (reels + win presentation)
  bool _rolling = false; // reels are physically moving
  bool _auto = false;
  int _lastWin = 0;
  int _winSerial = 0;
  _Celebration? _celebration;

  Session get s => widget.session;

  @override
  void initState() {
    super.initState();
    if (s.inFreeSpins) {
      // The app was closed in the middle of a feature; pick it up again.
      WidgetsBinding.instance.addPostFrameCallback((_) => _resumeFeature());
    }
  }

  // --- round flow ----------------------------------------------------------

  Future<bool> _pause(int ms) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    return mounted;
  }

  Future<void> _resumeFeature() async {
    if (!mounted) return;
    await showCard(
      context,
      title: 'FREE SPINS',
      message: '${s.freeSpinsLeft} free spins are waiting for you.\nAll wins are multiplied by ${s.engine.freeMultiplier}.',
      button: 'START',
      startSprite: true,
    );
    if (mounted) _round();
  }

  void _onSpinPressed() {
    if (_rolling) {
      _reels.currentState?.quickStop();
      return;
    }
    if (_busy) return;
    _round();
  }

  void _toggleAuto() {
    setState(() => _auto = !_auto);
    if (_auto && !_busy) _round();
  }

  Future<void> _round() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      while (mounted) {
        final wasFree = s.inFreeSpins;
        final outcome = await _playOne();
        if (outcome == null || !mounted) break;

        if (outcome.freeSpins > 0) {
          await _announceFeature(outcome.freeSpins, retrigger: wasFree);
          if (!mounted) break;
        }
        if (wasFree && !s.inFreeSpins) {
          final total = s.closeFeature();
          await showCard(
            context,
            title: 'FREE SPINS COMPLETE',
            message: total > 0
                ? 'The feature paid ${groupDigits(total)} coins in total.'
                : 'No wins this time. Better luck next round!',
            button: 'COLLECT',
          );
          if (!mounted) break;
        }
        if (s.inFreeSpins) {
          if (!await _pause(500)) break;
          continue;
        }
        if (_auto && !s.broke) {
          if (!await _pause(450)) break;
          continue;
        }
        break;
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _auto = false;
        });
        if (s.broke) _offerRefill();
      }
    }
  }

  /// One spin, from stake to win presentation. Null when the player can't pay.
  Future<SpinOutcome?> _playOne() async {
    final outcome = s.spin();
    if (outcome == null) return null;

    setState(() {
      _lastWin = 0;
      _rolling = true;
    });
    await _reels.currentState!.spin(outcome.columns);
    if (!mounted) return outcome;
    s.revealWin();
    setState(() => _rolling = false);

    if (outcome.win > 0) {
      s.thump();
      _reels.currentState!.showWins(outcome.winMask);
      setState(() {
        _lastWin = outcome.win;
        _winSerial++;
      });
      final tier = _Celebration.forWin(outcome.win, s.bet);
      if (tier != null) {
        setState(() => _celebration = tier.withAmount(outcome.win));
        await _pause(2300);
        if (mounted) setState(() => _celebration = null);
      } else {
        await _pause(900);
      }
    } else {
      await _pause(220);
    }
    return outcome;
  }

  Future<void> _announceFeature(int count, {required bool retrigger}) async {
    s.thump();
    if (retrigger) {
      await showCard(
        context,
        title: 'MORE FREE SPINS',
        message: '+$count free spins added!',
        button: 'GREAT',
      );
    } else {
      await showCard(
        context,
        title: 'FREE SPINS',
        message: 'You won $count free spins!\nAll wins are multiplied by ${s.engine.freeMultiplier}.',
        button: 'START',
        startSprite: true,
      );
    }
  }

  Future<void> _offerRefill() async {
    if (!mounted) return;
    await showCard(
      context,
      title: 'OUT OF COINS',
      message: 'Here are ${groupDigits(Session.refillAmount)} free coins so you can keep playing.',
      button: 'COLLECT',
    );
    s.grant(Session.refillAmount);
  }

  void _openSettings() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Settings',
      barrierColor: const Color(0xB3000000),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, _) => _SettingsCard(
        session: s,
        onMenu: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).pop();
        },
        onGuide: () => Navigator.of(ctx).push(
          MaterialPageRoute<void>(builder: (_) => PaytableScreen(session: s)),
        ),
        onWeb: (title, url) => Navigator.of(ctx).push(
          MaterialPageRoute<void>(builder: (_) => WebScreen(title: title, url: url)),
        ),
      ),
      transitionBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
    );
  }

  // --- view ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final art = Art.I;

    return PopScope(
      // Leaving mid-spin would orphan the animation, so the system back
      // button is ignored until the round settles.
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: Palette.ink,
        body: Stack(
          fit: StackFit.expand,
          children: [
            CoverSprite(art.background),
            SafeArea(
              child: ListenableBuilder(
                listenable: s,
                builder: (context, _) => Column(
                  children: [
                    _topBar(w),
                    _hud(w),
                    _featureBanner(),
                    Expanded(
                      child: Center(
                        child: ReelsView(
                          key: _reels,
                          width: w - 16,
                          initial: s.grid,
                          onReelLanded: (_) => s.tick(),
                        ),
                      ),
                    ),
                    _betRow(w),
                    const SizedBox(height: 6),
                    _controls(w),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            if (_celebration != null)
              Positioned.fill(child: IgnorePointer(child: _CelebrationView(celebration: _celebration!))),
          ],
        ),
      ),
    );
  }

  Widget _topBar(double w) {
    final art = Art.I;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          PressScale(
            onTap: _busy ? null : _openSettings,
            child: SpriteView(art.gear, width: 54, tint: _busy ? dimmed : null),
          ),
          SpriteView(art.logo, width: w * 0.42),
          const SizedBox(width: 54),
        ],
      ),
    );
  }

  Widget _hud(double w) {
    final panelW = w * 0.44;
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ReadoutPlate(
            caption: 'BALANCE',
            width: panelW,
            value: Text(groupDigits(s.shownBalance), style: Fonts.title(panelW * 0.13, color: Colors.white)),
          ),
          SizedBox(width: w * 0.03),
          ReadoutPlate(
            caption: 'WIN',
            width: panelW,
            value: TweenAnimationBuilder<double>(
              key: ValueKey(_winSerial),
              tween: Tween(begin: 0, end: _lastWin.toDouble()),
              duration: Duration(milliseconds: _lastWin > 0 ? 800 : 1),
              curve: Curves.easeOut,
              builder: (_, v, _) => Text(
                groupDigits(v.round()),
                style: Fonts.title(panelW * 0.13, color: _lastWin > 0 ? Palette.amber : Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureBanner() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: s.shownFreeLeft > 0
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xDD1A0F07),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Palette.ember, width: 1.6),
                  boxShadow: const [BoxShadow(color: Color(0x66FF8A00), blurRadius: 12)],
                ),
                child: Text(
                  'FREE SPINS ${s.shownFreeLeft} LEFT  |  x${s.engine.freeMultiplier}  |  WON ${groupDigits(s.shownFreeWin)}',
                  style: Fonts.title(13, color: Palette.amber),
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }

  Widget _betRow(double w) {
    final locked = _busy || s.inFreeSpins;
    final art = Art.I;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PressScale(
          onTap: locked || !s.canLowerBet ? null : s.lowerBet,
          child: SpriteView(art.arrowLeft, width: 52, tint: locked || !s.canLowerBet ? dimmed : null),
        ),
        const SizedBox(width: 6),
        ReadoutPlate(
          caption: 'BET',
          width: w * 0.4,
          value: Text(groupDigits(s.bet), style: Fonts.title(w * 0.4 * 0.13, color: Colors.white)),
        ),
        const SizedBox(width: 6),
        PressScale(
          onTap: locked || !s.canRaiseBet ? null : s.raiseBet,
          child: SpriteView(art.arrowRight, width: 52, tint: locked || !s.canRaiseBet ? dimmed : null),
        ),
      ],
    );
  }

  Widget _controls(double w) {
    final art = Art.I;
    final spinSize = (w * 0.34).clamp(96.0, 150.0);
    final canSpin = _rolling || !_busy;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: w * 0.27,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PressScale(
                onTap: s.inFreeSpins ? null : _toggleAuto,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: _auto
                        ? const [BoxShadow(color: Color(0xCCFF8A00), blurRadius: 22, spreadRadius: 2)]
                        : null,
                  ),
                  child: SpriteView(art.auto, width: 66, tint: s.inFreeSpins ? dimmed : null),
                ),
              ),
              const SizedBox(height: 2),
              Text(_auto ? 'STOP' : 'AUTO', style: Fonts.title(12, color: _auto ? Palette.amber : Palette.cream)),
            ],
          ),
        ),
        PressScale(
          onTap: canSpin ? _onSpinPressed : null,
          depth: 0.9,
          child: SpriteView(art.spin, width: spinSize, tint: _busy ? dimmed : null),
        ),
        SizedBox(
          width: w * 0.27,
          child: Center(
            child: PlateButton(
              label: 'MAX BET',
              width: w * 0.25,
              fontSize: 14,
              onTap: _busy || s.inFreeSpins ? null : s.maxBet,
            ),
          ),
        ),
      ],
    );
  }
}

// --- big win overlay -------------------------------------------------------

class _Celebration {
  const _Celebration(this.title, this.amount);

  final String title;
  final int amount;

  _Celebration withAmount(int a) => _Celebration(title, a);

  static _Celebration? forWin(int win, int bet) {
    final x = win / bet;
    if (x >= 50) return const _Celebration('EPIC WIN', 0);
    if (x >= 25) return const _Celebration('MEGA WIN', 0);
    if (x >= 10) return const _Celebration('BIG WIN', 0);
    if (x >= 5) return const _Celebration('GREAT WIN', 0);
    return null;
  }
}

class _CelebrationView extends StatelessWidget {
  const _CelebrationView({required this.celebration});

  final _Celebration celebration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, t, child) => ColoredBox(
        color: Colors.black.withValues(alpha: 0.55 * t.clamp(0, 1)),
        child: Center(child: Transform.scale(scale: 0.4 + 0.6 * t, child: child)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFF1C2), Palette.ember],
            ).createShader(r),
            child: Text(
              celebration.title,
              style: Fonts.title(54, color: Colors.white).copyWith(
                shadows: const [Shadow(color: Color(0xFFFF6A00), blurRadius: 24)],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(groupDigits(celebration.amount), style: Fonts.title(40, color: Colors.white)),
        ],
      ),
    );
  }
}

// --- settings --------------------------------------------------------------

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.session,
    required this.onMenu,
    required this.onGuide,
    required this.onWeb,
  });

  final Session session;
  final VoidCallback onMenu;
  final VoidCallback onGuide;
  final void Function(String title, String url) onWeb;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * 0.86).clamp(0.0, 400.0);
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: width,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2A190B), Color(0xFF110A05)],
            ),
            border: Border.all(color: Palette.ember, width: 2.5),
            boxShadow: const [BoxShadow(color: Color(0x99FF8A00), blurRadius: 28)],
          ),
          child: ListenableBuilder(
            listenable: session,
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('SETTINGS', style: Fonts.title(26, color: Palette.amber)),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  value: session.haptics,
                  onChanged: (v) => session.haptics = v,
                  activeThumbColor: Palette.amber,
                  activeTrackColor: Palette.rust,
                  title: Text('Vibration', style: Fonts.title(17)),
                ),
                const SizedBox(height: 6),
                PlateButton(label: 'HOW TO PLAY', width: width * 0.7, fontSize: 18, onTap: onGuide),
                const SizedBox(height: 8),
                PlateButton(
                  label: 'PRIVACY POLICY',
                  width: width * 0.7,
                  fontSize: 18,
                  onTap: () => onWeb('Privacy Policy', Links.privacyPolicy),
                ),
                const SizedBox(height: 8),
                PlateButton(
                  label: 'SUPPORT',
                  width: width * 0.7,
                  fontSize: 18,
                  onTap: () => onWeb('Support', Links.support),
                ),
                const SizedBox(height: 8),
                PlateButton(label: 'MAIN MENU', width: width * 0.7, fontSize: 18, onTap: onMenu),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('CLOSE', style: Fonts.title(16, color: Palette.amber)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
