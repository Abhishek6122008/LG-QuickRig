import 'package:flutter/material.dart';

import 'app_accents.dart';
import 'app_spacing.dart';

/// The brand seed. Every scheme colour in both themes derives from this one
/// value via [ColorScheme.fromSeed].
const _seed = Color(0xFF1A73E8);

ThemeData get lightTheme => _build(Brightness.light);
ThemeData get darkTheme => _build(Brightness.dark);

ThemeData _build(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final isLight = brightness == Brightness.light;

  // Light keeps the exact greys the app shipped with, so the re-skin is not
  // also a silent palette change. Dark defers to the seeded scheme.
  final surface = isLight ? const Color(0xFFF8F9FA) : scheme.surface;
  final cardColor = isLight ? Colors.white : scheme.surfaceContainerLow;
  final cardBorder =
      isLight ? const Color(0xFFE0E3E7) : scheme.outlineVariant;

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: surface,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
        side: BorderSide(color: cardBorder),
      ),
    ),
    // The shell renders one of these depending on window width; theming both
    // here keeps the two paths from drifting apart.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surface,
      elevation: 0,
    ),
    extensions: [isLight ? AppAccents.light : AppAccents.dark],
  );
}
