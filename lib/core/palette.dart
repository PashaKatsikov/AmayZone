import 'package:flutter/material.dart';

abstract final class Palette {
  static const ink = Color(0xFF0B0603);
  static const ember = Color(0xFFFF8A00);
  static const amber = Color(0xFFFFC25C);
  static const cream = Color(0xFFFFEBCB);
  static const rust = Color(0xFF7A2E00);
}

abstract final class Fonts {
  static const family = 'RussoOne';

  static TextStyle title(double size, {Color color = Palette.cream}) => TextStyle(
        fontFamily: family,
        fontSize: size,
        color: color,
        height: 1.05,
        shadows: const [
          Shadow(color: Color(0xCC000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      );
}
