import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/palette.dart';
import '../screens/loading_screen.dart';

class AmayZoneApp extends StatelessWidget {
  const AmayZoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amay Zone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Palette.ember,
          brightness: Brightness.dark,
        ),
        fontFamily: Fonts.family,
        splashFactory: NoSplash.splashFactory,
      ),
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Palette.ink,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        // Layout is tuned to the art; system font scaling would break it.
        child: MediaQuery.withNoTextScaling(child: child!),
      ),
      home: const LoadingScreen(),
    );
  }
}

