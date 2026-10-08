import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

/// Mirrors `SpinResult` from rust/slot_core. Layout must stay in sync.
final class _SpinResult extends Struct {
  @Array(20)
  external Array<Uint8> grid;

  @Uint32()
  external int winMask;

  @Uint64()
  external int win;

  @Uint8()
  external int freeSpins;

  @Uint8()
  external int scatters;

  @Uint8()
  external int bestRun;

  @Uint8()
  external int pad;
}

typedef _InitC = Int32 Function();
typedef _InitDart = int Function();
typedef _SpinC = Int32 Function(Uint64, Uint32, Pointer<_SpinResult>);
typedef _SpinDart = int Function(int, int, Pointer<_SpinResult>);
typedef _PayC = Uint32 Function(Uint32, Uint32);
typedef _PayDart = int Function(int, int);
typedef _OneArgC = Uint32 Function(Uint32);
typedef _OneArgDart = int Function(int);
typedef _NoArgC = Uint32 Function();
typedef _NoArgDart = int Function();

class SpinOutcome {
  SpinOutcome({
    required this.columns,
    required this.winMask,
    required this.win,
    required this.freeSpins,
    required this.scatters,
    required this.bestRun,
  });

  /// `columns[reel][row]`, symbol ids.
  final List<List<int>> columns;
  final int winMask;
  final int win;
  final int freeSpins;
  final int scatters;
  final int bestRun;

  bool isWinning(int reel, int row) => (winMask >> (reel * SlotEngine.rows + row)) & 1 == 1;
}

class SlotEngineException implements Exception {
  SlotEngineException(this.message);
  final String message;
  @override
  String toString() => 'SlotEngineException: $message';
}

/// Dart face of the native math core. All outcomes are produced natively.
class SlotEngine {
  SlotEngine._(this._spin, this._pay, this._freeSpins, this._freeMult) {
    _out = calloc<_SpinResult>();
  }

  static const reels = 5;
  static const rows = 4;
  static const symbolCount = 14;
  static const wild = 12;
  static const bonus = 13;

  final _SpinDart _spin;
  final _PayDart _pay;
  final _OneArgDart _freeSpins;
  final _NoArgDart _freeMult;
  late final Pointer<_SpinResult> _out;

  static SlotEngine open() {
    final lib = DynamicLibrary.open(Platform.isAndroid ? 'libslot_core.so' : 'slot_core.dll');
    final init = lib.lookupFunction<_InitC, _InitDart>('az_init');
    if (init() != 0) {
      throw SlotEngineException('math model failed to initialise');
    }
    return SlotEngine._(
      lib.lookupFunction<_SpinC, _SpinDart>('az_spin'),
      lib.lookupFunction<_PayC, _PayDart>('az_pay'),
      lib.lookupFunction<_OneArgC, _OneArgDart>('az_free_spins'),
      lib.lookupFunction<_NoArgC, _NoArgDart>('az_free_multiplier'),
    );
  }

  SpinOutcome spin(int bet, {required bool free}) {
    final code = _spin(bet, free ? 1 : 0, _out);
    if (code != 0) throw SlotEngineException('spin failed ($code)');
    final r = _out.ref;
    final columns = List.generate(
      reels,
      (reel) => List.generate(rows, (row) => r.grid[reel * rows + row]),
      growable: false,
    );
    return SpinOutcome(
      columns: columns,
      winMask: r.winMask,
      win: r.win,
      freeSpins: r.freeSpins,
      scatters: r.scatters,
      bestRun: r.bestRun,
    );
  }

  /// Pay per way for [count] (3..5) matching reels, in thousandths of the bet.
  int pay(int symbol, int count) => _pay(symbol, count);

  int freeSpinsFor(int scatters) => _freeSpins(scatters);

  int get freeMultiplier => _freeMult();

  void dispose() => calloc.free(_out);
}
