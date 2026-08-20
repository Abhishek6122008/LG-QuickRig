import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// One tappable action in a grid: coloured icon chip + label.
class ActionTileConfig {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// Per-tile override. Most tiles need the rig connected; Stop Orbit is the
  /// exception — it has to stay reachable precisely when things are wrong.
  final bool Function(bool gridEnabled)? enabledWhen;

  const ActionTileConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabledWhen,
  });
}

class ActionTile extends StatelessWidget {
  final ActionTileConfig config;
  final bool enabled;

  const ActionTile({
    super.key,
    required this.config,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor =
        enabled ? config.color : scheme.onSurface.withValues(alpha: 0.26);
    final labelColor =
        enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.38);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? config.onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: enabled
                      ? config.color.withValues(alpha: 0.12)
                      : scheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Icon(config.icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  config.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Width-driven grid of [ActionTile]s. The old dashboard hardcoded two
/// columns, which on a maximised Linux window stretched each tile across half
/// the screen.
class ActionTileGrid extends StatelessWidget {
  final List<ActionTileConfig> tiles;

  /// Whether the rig is reachable — individual tiles may opt out via
  /// [ActionTileConfig.enabledWhen].
  final bool enabled;

  const ActionTileGrid({
    super.key,
    required this.tiles,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ~260px per tile keeps the label on one line at the default text
        // scale; clamped so a phone never drops to one column.
        final columns = (constraints.maxWidth / 260).floor().clamp(2, 4);

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: 2.2,
          children: [
            for (final t in tiles)
              ActionTile(
                config: t,
                enabled: t.enabledWhen?.call(enabled) ?? enabled,
              ),
          ],
        );
      },
    );
  }
}
