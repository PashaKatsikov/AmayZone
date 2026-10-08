import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/storage.dart';
import 'slot_engine.dart';

/// Everything that lives for the duration of the app: balance, bet, bonus
/// state. Screens listen to it; the engine decides every result.
class Session extends ChangeNotifier {
  Session(this._store, this.engine) {
    _balance = _store.balance;
    _betIndex = _store.betIndex.clamp(0, bets.length - 1);
    _haptics = _store.haptics;
    _freeLeft = _store.freeSpinsLeft;
    _freeWin = _store.freeSpinsWin;
    _freeBet = _store.freeSpinsBet;
    _shownFreeLeft = _freeLeft;
    _shownFreeWin = _freeWin;
    _grid = _randomGrid();
  }

  static const bets = [100, 200, 500, 1000, 2000, 5000, 10000, 25000];
  static const refillAmount = 5000;
  static const dailyAmount = 2500;
  static const dailyCooldown = Duration(hours: 24);

  final Storage _store;
  final SlotEngine engine;
  final _rng = Random();

  late int _balance;
  late int _betIndex;
  late bool _haptics;
  late int _freeLeft;
  late int _freeWin;
  late int _freeBet;
  late List<List<int>> _grid;
  int _pendingWin = 0;
  // Feature counters as displayed; they follow the real ones once reels stop.
  late int _shownFreeLeft;
  late int _shownFreeWin;

  /// What the player sees. A win is already stored but only shown once the
  /// reels have stopped.
  int get shownBalance => _balance - _pendingWin;
  int get bet => inFreeSpins && _freeBet > 0 ? _freeBet : bets[_betIndex];
  int get betIndex => _betIndex;
  bool get haptics => _haptics;
  bool get inFreeSpins => _freeLeft > 0;
  int get freeSpinsLeft => _freeLeft;
  int get freeSpinsWin => _freeWin;
  int get shownFreeLeft => _shownFreeLeft;
  int get shownFreeWin => _shownFreeWin;
  List<List<int>> get grid => _grid;

  bool get canRaiseBet => _betIndex < bets.length - 1;
  bool get canLowerBet => _betIndex > 0;

  void raiseBet() {
    if (!canRaiseBet) return;
    _betIndex++;
    _store.betIndex = _betIndex;
    notifyListeners();
  }

  void lowerBet() {
    if (!canLowerBet) return;
    _betIndex--;
    _store.betIndex = _betIndex;
    notifyListeners();
  }

  void maxBet() {
    final affordable = bets.lastIndexWhere((b) => b <= _balance);
    _betIndex = affordable < 0 ? 0 : affordable;
    _store.betIndex = _betIndex;
    notifyListeners();
  }

  set haptics(bool v) {
    _haptics = v;
    _store.haptics = v;
    notifyListeners();
  }

  void tick() {
    if (_haptics) HapticFeedback.selectionClick();
  }

  void thump() {
    if (_haptics) HapticFeedback.mediumImpact();
  }

  /// True when the player cannot pay for even the smallest bet.
  bool get broke => !inFreeSpins && _balance < bets.first;

  /// Plays a round on the native core. Returns null if the bet isn't covered.
  /// The stake is taken and the win is booked immediately (so a crash can't
  /// eat a result); the win only becomes visible via [revealWin].
  SpinOutcome? spin() {
    final free = inFreeSpins;
    if (!free) {
      if (_balance < bets.first) return null;
      // Step the bet down instead of refusing when funds are short.
      while (bets[_betIndex] > _balance) {
        _betIndex--;
      }
      _store.betIndex = _betIndex;
    }
    final stake = bet;
    final outcome = engine.spin(stake, free: free);

    if (free) {
      _freeLeft--;
      _freeWin += outcome.win;
    } else {
      _balance -= stake;
      _freeBet = stake;
      _freeWin = 0;
    }
    if (outcome.freeSpins > 0) {
      _freeLeft += outcome.freeSpins;
    }
    _balance += outcome.win;
    _pendingWin = outcome.win;
    _grid = outcome.columns;
    _persist();
    notifyListeners();
    return outcome;
  }

  /// Called when the reels have stopped.
  void revealWin() {
    _pendingWin = 0;
    _shownFreeLeft = _freeLeft;
    _shownFreeWin = _freeWin;
    notifyListeners();
  }

  /// Finishes the free-spin feature and returns what it paid in total.
  int closeFeature() {
    final total = _freeWin;
    _freeWin = 0;
    _freeBet = 0;
    _shownFreeWin = 0;
    _persist();
    notifyListeners();
    return total;
  }

  void grant(int coins) {
    _balance += coins;
    _persist();
    notifyListeners();
  }

  // --- daily bonus ---------------------------------------------------------

  Duration get dailyWait {
    final last = _store.lastDailyClaim;
    if (last == null) return Duration.zero;
    final left = last.add(dailyCooldown).difference(DateTime.now());
    // A clock set back past the cooldown shouldn't lock the bonus for days.
    if (left > dailyCooldown) return Duration.zero;
    return left.isNegative ? Duration.zero : left;
  }

  bool get dailyReady => dailyWait == Duration.zero;

  bool claimDaily() {
    if (!dailyReady) return false;
    _store.lastDailyClaim = DateTime.now();
    grant(dailyAmount);
    return true;
  }

  // --- helpers -------------------------------------------------------------

  List<List<int>> _randomGrid() => List.generate(
        SlotEngine.reels,
        (_) => List.generate(SlotEngine.rows, (_) => _rng.nextInt(SlotEngine.wild)),
      );

  void _persist() {
    _store.balance = _balance;
    _store.freeSpinsLeft = _freeLeft;
    _store.freeSpinsWin = _freeWin;
    _store.freeSpinsBet = _freeBet;
  }
}
