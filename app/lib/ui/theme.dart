import 'package:flutter/material.dart';

import '../data/models.dart';

Color hexColor(String hex, {Color fallback = const Color(0xFF0F3D3E)}) {
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(0xFF000000 | v);
}

/// Platform theme (church picker, sign-in).
ThemeData platformTheme(Brightness brightness) => _build(
      const Color(0xFF3B2A7A),
      const Color(0xFFE0A526),
      brightness,
    );

/// A church's theme, built from its branding colours.
ThemeData churchTheme(Branding b, Brightness brightness) =>
    _build(hexColor(b.primaryColor), hexColor(b.accentColor, fallback: const Color(0xFFD4A72C)), brightness);

ThemeData _build(Color primary, Color accent, Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
    primary: brightness == Brightness.light ? primary : null,
    secondary: accent,
    tertiary: accent,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: AppBarTheme(
      backgroundColor: brightness == Brightness.light ? primary : scheme.surface,
      foregroundColor: brightness == Brightness.light ? Colors.white : scheme.onSurface,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(margin: EdgeInsets.zero, clipBehavior: Clip.antiAlias),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
  );
}
