import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/art.dart';
import '../core/palette.dart';
import '../core/storage.dart';
import '../game/session.dart';
import '../game/slot_engine.dart';
import 'menu_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  // Keeps the screen on long enough to read even when decoding is instant.
  static const _minimum = Duration(milliseconds: 2600);

  late final AnimationController _clock;
  late final AnimationController _dots;
  double _loaded = 0;
  Session? _session;
  Object? _error;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: _minimum)..forward();
    _dots = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _clock.addStatusListener((_) => _maybeLeave());
    _boot();
  }

  Future<void> _boot() async {
    try {
      final store = await Storage.open();
      final engine = SlotEngine.open();
      await Art.load((p) {
        if (mounted) setState(() => _loaded = p);
      });
      _session = Session(store, engine);
      if (mounted) setState(() => _loaded = 1);
      _maybeLeave();
    } catch (e, st) {
      debugPrint('boot failed: $e\n$st');
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _maybeLeave() async {
    if (_leaving || !mounted) return;
    if (_session == null || !_clock.isCompleted) return;
    _leaving = true;
    // The game is portrait only; the loading art is the sole landscape screen.
    await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => MenuScreen(session: _session!),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _clock.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final landscape = mq.size.width > mq.size.height;
    final asset = landscape
        ? 'assets/images/loading/horizontal_loading_screen.webp'
        : 'assets/images/loading/vertical_loading_screen.webp';

    return Scaffold(
      backgroundColor: Palette.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(asset, fit: BoxFit.cover, filterQuality: FilterQuality.medium, gaplessPlayback: true),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: landscape ? 18 : 56),
                child: SizedBox(
                  width: landscape ? mq.size.width * 0.42 : mq.size.width * 0.72,
                  child: _error != null ? _failure() : _progress(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _failure() {
    return Text(
      'Something went wrong.\nPlease restart the app.',
      textAlign: TextAlign.center,
      style: Fonts.title(16),
    );
  }

  Widget _progress() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _dots,
          builder: (context, _) {
            final n = (_dots.value * 4).floor().clamp(0, 3);
            final style = Fonts.title(22);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mirror box on the left keeps the word visually centred.
                SizedBox(width: 26, child: Text('', style: style)),
                Text('Loading', style: style),
                SizedBox(
                  width: 26,
                  child: Text('.' * n, style: style),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            // Never run ahead of the real work.
            final value = _clock.value < _loaded ? _clock.value : _loaded;
            return _Bar(progress: value);
          },
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.progress});

  final double progress;

  static const height = 16.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xCC120A04),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: Palette.amber, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x88FF8A00), blurRadius: 10)],
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          // Explicit height on the fill; a missing one collapses it to zero.
          final fill = (box.maxWidth * progress.clamp(0.0, 1.0));
          return ClipRRect(
            borderRadius: BorderRadius.circular(height / 2),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: fill,
                  height: height - 3,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFD27A), Palette.ember, Color(0xFFB85500)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
