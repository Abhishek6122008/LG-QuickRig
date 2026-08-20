import 'package:flutter/material.dart';

/// The brand accents that are *not* derivable from the seeded [ColorScheme]:
/// the per-action tile hues, the connection-state colours, and the error
/// banner. Previously these were `Color(0xFF…)` literals repeated across six
/// widget files, which is why the app could only ever be light-themed.
///
/// A [ThemeExtension] is the native mechanism for this — it rides on
/// `Theme.of(context)` and gets the light/dark swap for free, so call sites
/// never branch on brightness themselves.
@immutable
class AppAccents extends ThemeExtension<AppAccents> {
  // Action tiles.
  final Color blue;
  final Color green;
  final Color red;
  final Color orange;
  final Color teal;
  final Color grey;
  final Color purple;
  final Color yellow;

  // Connection states.
  final Color connected;
  final Color connecting;
  final Color disconnecting;
  final Color disconnected;

  // Error banner.
  final Color errorBg;
  final Color errorBorder;
  final Color errorFg;

  const AppAccents({
    required this.blue,
    required this.green,
    required this.red,
    required this.orange,
    required this.teal,
    required this.grey,
    required this.purple,
    required this.yellow,
    required this.connected,
    required this.connecting,
    required this.disconnecting,
    required this.disconnected,
    required this.errorBg,
    required this.errorBorder,
    required this.errorFg,
  });

  /// The original palette, unchanged — these are the exact hues the app
  /// shipped with, just named.
  static const light = AppAccents(
    blue: Color(0xFF1A73E8),
    green: Color(0xFF1E8E3E),
    red: Color(0xFFD93025),
    orange: Color(0xFFE8710A),
    teal: Color(0xFF12A4AF),
    grey: Color(0xFF5F6368),
    purple: Color(0xFF9334E6),
    yellow: Color(0xFFF9AB00),
    connected: Color(0xFF1E8E3E),
    connecting: Color(0xFFE8710A),
    disconnecting: Color(0xFFE8710A),
    disconnected: Color(0xFFD93025),
    errorBg: Color(0xFFFCE8E6),
    errorBorder: Color(0xFFF4C7C3),
    errorFg: Color(0xFFC5221F),
  );

  /// Google's own Material dark-surface counterparts of the light hues above.
  /// The light values are mid-tone by design and drop to ~2:1 contrast on a
  /// dark surface, so they cannot simply be reused.
  static const dark = AppAccents(
    blue: Color(0xFF8AB4F8),
    green: Color(0xFF81C995),
    red: Color(0xFFF28B82),
    orange: Color(0xFFFCAD70),
    teal: Color(0xFF78D9E1),
    grey: Color(0xFFBDC1C6),
    purple: Color(0xFFD7AEFB),
    yellow: Color(0xFFFDD663),
    connected: Color(0xFF81C995),
    connecting: Color(0xFFFCAD70),
    disconnecting: Color(0xFFFCAD70),
    disconnected: Color(0xFFF28B82),
    errorBg: Color(0xFF3B1F1D),
    errorBorder: Color(0xFF5C2B27),
    errorFg: Color(0xFFF28B82),
  );

  @override
  AppAccents copyWith({
    Color? blue,
    Color? green,
    Color? red,
    Color? orange,
    Color? teal,
    Color? grey,
    Color? purple,
    Color? yellow,
    Color? connected,
    Color? connecting,
    Color? disconnecting,
    Color? disconnected,
    Color? errorBg,
    Color? errorBorder,
    Color? errorFg,
  }) {
    return AppAccents(
      blue: blue ?? this.blue,
      green: green ?? this.green,
      red: red ?? this.red,
      orange: orange ?? this.orange,
      teal: teal ?? this.teal,
      grey: grey ?? this.grey,
      purple: purple ?? this.purple,
      yellow: yellow ?? this.yellow,
      connected: connected ?? this.connected,
      connecting: connecting ?? this.connecting,
      disconnecting: disconnecting ?? this.disconnecting,
      disconnected: disconnected ?? this.disconnected,
      errorBg: errorBg ?? this.errorBg,
      errorBorder: errorBorder ?? this.errorBorder,
      errorFg: errorFg ?? this.errorFg,
    );
  }

  @override
  AppAccents lerp(ThemeExtension<AppAccents>? other, double t) {
    if (other is! AppAccents) return this;
    return AppAccents(
      blue: Color.lerp(blue, other.blue, t)!,
      green: Color.lerp(green, other.green, t)!,
      red: Color.lerp(red, other.red, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      grey: Color.lerp(grey, other.grey, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      yellow: Color.lerp(yellow, other.yellow, t)!,
      connected: Color.lerp(connected, other.connected, t)!,
      connecting: Color.lerp(connecting, other.connecting, t)!,
      disconnecting: Color.lerp(disconnecting, other.disconnecting, t)!,
      disconnected: Color.lerp(disconnected, other.disconnected, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      errorFg: Color.lerp(errorFg, other.errorFg, t)!,
    );
  }
}

/// `context.accents.red` — shorter than the `Theme.of(context).extension<…>()!`
/// dance at every call site.
extension AppAccentsX on BuildContext {
  AppAccents get accents => Theme.of(this).extension<AppAccents>()!;
}
