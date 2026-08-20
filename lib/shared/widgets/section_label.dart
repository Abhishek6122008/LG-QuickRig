import 'package:flutter/material.dart';

/// Small uppercase heading above a group of controls. Was private to the
/// settings screen; the Rig and Camera tabs need the same heading treatment.
class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
