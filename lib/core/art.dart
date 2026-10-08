import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// A rectangular region of a decoded image.
class Sprite {
  const Sprite(this.image, this.src);

  final ui.Image image;
  final ui.Rect src;

  double get aspect => src.width / src.height;
}

/// All raster art used by the game, decoded once during the loading screen.
class Art {
  Art._(this._images);

  final Map<String, ui.Image> _images;

  static Art? _instance;
  static Art get I => _instance!;
  static bool get ready => _instance != null;

  static const _symbolFiles = [
    '10', 'j', 'q', 'k', 'a', 'cherry', 'bell', 'bar', 'diamonds', 'chips',
    'crown', 'amazoncoin', 'wild', 'bonus',
  ];

  static const _root = 'assets/images';
  static const _files = <String, String>{
    'background': '$_root/backgrounds/background_game.webp',
    'logo': '$_root/branding/game_name.webp',
    'frame': '$_root/frame/slot_frame_asset.webp',
    'buttons': '$_root/ui/buttons_game_asset.webp',
    'bet_panel': '$_root/ui/button_bet_asset.webp',
    'bet_arrows': '$_root/ui/button_bet_asset2.webp',
    'start': '$_root/ui/button_start_asset.webp',
  };

  /// Decodes everything. [onProgress] receives values in 0..1.
  static Future<void> load(void Function(double) onProgress) async {
    final jobs = <String, String>{
      ..._files,
      for (var i = 0; i < _symbolFiles.length; i++)
        'symbol_$i': '$_root/symbols/${_symbolFiles[i]}_slot_asset.webp',
    };
    final decoded = <String, ui.Image>{};
    var done = 0;
    for (final entry in jobs.entries) {
      decoded[entry.key] = await _decode(entry.value);
      onProgress(++done / jobs.length);
    }
    _instance = Art._(decoded);
  }

  static Future<ui.Image> _decode(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  ui.Image _img(String key) => _images[key]!;

  Sprite symbol(int id) {
    final img = _img('symbol_$id');
    return Sprite(img, ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
  }

  Sprite get background => _whole('background');

  // Source rectangles below are the opaque bounds measured from the sheets.
  Sprite get logo => Sprite(_img('logo'), const ui.Rect.fromLTRB(3, 144, 511, 364));
  Sprite get frame => Sprite(_img('frame'), const ui.Rect.fromLTRB(4, 5, 1274, 971));
  Sprite get gear => Sprite(_img('buttons'), const ui.Rect.fromLTRB(80, 97, 281, 293));
  Sprite get spin => Sprite(_img('buttons'), const ui.Rect.fromLTRB(298, 61, 570, 321));
  Sprite get auto => Sprite(_img('buttons'), const ui.Rect.fromLTRB(586, 97, 786, 293));
  Sprite get panel => Sprite(_img('bet_panel'), const ui.Rect.fromLTRB(130, 50, 469, 200));
  Sprite get arrowLeft => Sprite(_img('bet_arrows'), const ui.Rect.fromLTRB(38, 44, 131, 150));
  Sprite get arrowRight => Sprite(_img('bet_arrows'), const ui.Rect.fromLTRB(157, 44, 250, 151));
  Sprite get startButton => Sprite(_img('start'), const ui.Rect.fromLTRB(55, 22, 563, 241));

  Sprite _whole(String key) {
    final img = _img(key);
    return Sprite(img, ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()));
  }
}
