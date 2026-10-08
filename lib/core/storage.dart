import 'package:shared_preferences/shared_preferences.dart';

/// Thin typed wrapper over SharedPreferences for everything we persist.
class Storage {
  Storage._(this._p);

  final SharedPreferences _p;

  static Future<Storage> open() async => Storage._(await SharedPreferences.getInstance());

  static const startingBalance = 10000;

  int get balance => _p.getInt('balance') ?? startingBalance;
  set balance(int v) => _p.setInt('balance', v);

  int get betIndex => _p.getInt('bet_index') ?? 1;
  set betIndex(int v) => _p.setInt('bet_index', v);

  bool get haptics => _p.getBool('haptics') ?? true;
  set haptics(bool v) => _p.setBool('haptics', v);

  /// Free spins that were won but not played yet (app killed mid-feature).
  int get freeSpinsLeft => _p.getInt('fs_left') ?? 0;
  set freeSpinsLeft(int v) => _p.setInt('fs_left', v);

  int get freeSpinsWin => _p.getInt('fs_win') ?? 0;
  set freeSpinsWin(int v) => _p.setInt('fs_win', v);

  int get freeSpinsBet => _p.getInt('fs_bet') ?? 0;
  set freeSpinsBet(int v) => _p.setInt('fs_bet', v);

  DateTime? get lastDailyClaim {
    final ms = _p.getInt('daily_claim');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  set lastDailyClaim(DateTime? v) {
    if (v == null) {
      _p.remove('daily_claim');
    } else {
      _p.setInt('daily_claim', v.millisecondsSinceEpoch);
    }
  }
}
