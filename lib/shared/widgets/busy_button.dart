import 'package:flutter/material.dart';

/// A [FilledButton] that swaps its label for a spinner while [busy].
///
/// This exact 18×18 `CircularProgressIndicator(strokeWidth: 2)` block was
/// copy-pasted into five files, each with its own idea of the spinner's
/// colour — one of which hardcoded white and so went invisible the moment a
/// dark theme existed. The spinner here follows the button's own foreground.
class BusyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  final Widget label;

  /// When set, renders as [FilledButton.icon] and the spinner replaces the
  /// icon rather than the label — so the button keeps its width while working.
  final Widget? icon;

  final ButtonStyle? style;

  const BusyButton({
    super.key,
    required this.busy,
    required this.onPressed,
    required this.label,
    this.icon,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );

    // A busy button is not tappable, whatever the caller passed.
    final onTap = busy ? null : onPressed;

    if (icon != null) {
      return FilledButton.icon(
        onPressed: onTap,
        style: style,
        icon: busy ? spinner : icon!,
        label: label,
      );
    }

    return FilledButton(
      onPressed: onTap,
      style: style,
      child: busy ? spinner : label,
    );
  }
}
