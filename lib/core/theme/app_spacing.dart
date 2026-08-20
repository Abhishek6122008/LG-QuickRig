/// The spacing and radius scales. Before this file both were ad-hoc literals
/// scattered across the widget tree — radii alone ran 10/12/14/16/20 with no
/// rule about which meant what.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Three steps, by role — not by pixel value. Pick the role, not the number.
class AppRadius {
  AppRadius._();

  /// Icon chips, small inline affordances.
  static const double small = 10;

  /// Banners, chat bubbles, input surfaces.
  static const double medium = 14;

  /// Cards and anything card-sized.
  static const double large = 16;

  /// Pills — status badges. Any value past half the height reads the same.
  static const double pill = 999;
}
