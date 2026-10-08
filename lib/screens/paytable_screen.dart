import 'package:flutter/material.dart';

import '../core/art.dart';
import '../core/format.dart';
import '../core/palette.dart';
import '../game/session.dart';
import '../game/slot_engine.dart';
import '../ui/sprite_view.dart';

class PaytableScreen extends StatelessWidget {
  const PaytableScreen({super.key, required this.session});

  final Session session;

  // Highest paying first; ids match the native symbol table.
  static const _order = [11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0];
  static const _names = {
    0: '10', 1: 'J', 2: 'Q', 3: 'K', 4: 'A', 5: 'Cherry', 6: 'Bell', 7: 'Bar',
    8: 'Diamond', 9: 'Chips', 10: 'Crown', 11: 'Coin',
  };

  @override
  Widget build(BuildContext context) {
    final e = session.engine;
    final bet = Session.bets[session.betIndex];
    final art = Art.I;

    return Scaffold(
      backgroundColor: Palette.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CoverSprite(art.background),
          const ColoredBox(color: Color(0xB3000000)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, color: Palette.amber, size: 28),
                        tooltip: 'Back',
                      ),
                      Text('HOW TO PLAY', style: Fonts.title(24, color: Palette.amber)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                    children: [
                      _rules(e),
                      const SizedBox(height: 18),
                      Text(
                        'PAYS PER WAY  |  BET ${groupDigits(bet)}',
                        style: Fonts.title(15, color: Palette.amber),
                      ),
                      const SizedBox(height: 8),
                      for (final id in _order) _payRow(id, e, bet),
                      const SizedBox(height: 14),
                      _special(
                        SlotEngine.wild,
                        'WILD',
                        'Appears on reels 2, 3 and 4. Substitutes for every symbol except Bonus.',
                      ),
                      _special(
                        SlotEngine.bonus,
                        'BONUS',
                        '3, 4 or 5 Bonus symbols anywhere on the reels pay '
                            '${_x(e.pay(13, 3))}x, ${_x(e.pay(13, 4))}x and ${_x(e.pay(13, 5))}x your bet and award '
                            '${e.freeSpinsFor(3)}, ${e.freeSpinsFor(4)} or ${e.freeSpinsFor(5)} free spins. '
                            'Every free spin win is multiplied by ${e.freeMultiplier}. Free spins can be retriggered.',
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'This game is for entertainment purposes only. It offers no real money gambling '
                        'and no way to win real money or prizes. Coins have no cash value.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Palette.cream.withValues(alpha: 0.65), fontSize: 12, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _x(int thousandths) {
    final v = thousandths / 1000;
    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  Widget _rules(SlotEngine e) {
    const style = TextStyle(color: Palette.cream, fontSize: 14.5, height: 1.4);
    return _Frame(
      child: const Text(
        'Spin the 5 reels and match symbols on neighbouring reels, starting from the leftmost reel. '
        '1,024 ways to win: every matching symbol on a reel counts, and the number of ways multiplies the pay.\n\n'
        'Use the arrows to set your bet, then press the spin button. Tap it again while the reels are '
        'turning to stop them quicker. The play button starts autoplay.',
        style: style,
      ),
    );
  }

  Widget _payRow(int id, SlotEngine e, int bet) {
    String coins(int n) => groupDigits(e.pay(id, n) * bet ~/ 1000);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _Frame(
        child: Row(
          children: [
            SpriteView(Art.I.symbol(id), width: 54),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_names[id]!.toUpperCase(), style: Fonts.title(14, color: Palette.amber)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      for (final n in [3, 4, 5]) ...[
                        Text('$n', style: const TextStyle(color: Palette.amber, fontSize: 13)),
                        const Text(' = ', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        Text(coins(n), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 14),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _special(int id, String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _Frame(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SpriteView(Art.I.symbol(id), width: 64),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Fonts.title(16, color: Palette.amber)),
                  const SizedBox(height: 4),
                  Text(text, style: const TextStyle(color: Palette.cream, fontSize: 13.5, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xCC1A0F07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.ember.withValues(alpha: 0.7), width: 1.4),
      ),
      child: child,
    );
  }
}

