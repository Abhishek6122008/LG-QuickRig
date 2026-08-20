import 'package:flutter/material.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/action_tile.dart';
import '../../shared/widgets/section_label.dart';
import '../dashboard/dashboard_controller.dart';
import 'camera_action_dialog.dart';
import 'image_overlay_dialog.dart';

/// The Camera tab.
///
/// Before this existed, Fly To and Orbit were reachable only from an Android
/// home-screen widget or the Linux tray — so on a phone with no widget placed,
/// or under GNOME (which hides tray icons by default), the app's two headline
/// camera features had no entry point at all. Stop Orbit had none anywhere
/// except the Copilot tool, which meant a running orbit could not be stopped
/// without a Gemini API key.
class CameraView extends StatelessWidget {
  final DashboardController ctrl;

  const CameraView({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final a = context.accents;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xxl),
      children: [
        const SectionLabel('Camera'),
        const SizedBox(height: AppSpacing.md),
        ActionTileGrid(
          enabled: ctrl.isConnected && !ctrl.isBusy,
          tiles: [
            ActionTileConfig(
              label: 'Fly To',
              icon: Icons.my_location,
              color: a.blue,
              onTap: () => CameraActionDialog.show(context, 'flyto'),
            ),
            ActionTileConfig(
              label: 'Orbit',
              icon: Icons.rotate_right,
              color: a.teal,
              onTap: () => CameraActionDialog.show(context, 'orbit'),
            ),
            ActionTileConfig(
              label: 'Stop Orbit',
              icon: Icons.stop_circle_outlined,
              color: a.red,
              // Always tappable. Gating this on the connection would recreate
              // the bug it exists to fix, and gating it on isOrbitPlaying
              // would go stale — the orbit ends itself after 60 steps without
              // notifying anyone. Stopping nothing is harmless.
              enabledWhen: (_) => true,
              onTap: ctrl.stopOrbit,
            ),
            ActionTileConfig(
              label: 'Drop Pin',
              icon: Icons.place_outlined,
              color: a.orange,
              onTap: () => ImageOverlayDialog.show(context),
            ),
            ActionTileConfig(
              label: 'Overlay',
              icon: Icons.add_photo_alternate_outlined,
              color: a.purple,
              onTap: () => ImageOverlayDialog.show(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          ctrl.isConnected
              ? 'Pins and overlays share one dialog — pick a marker chip for a '
                  'pin, or Image for a ground overlay.'
              : 'Not connected. Connect from the Rig tab first — Stop Orbit '
                  'still works offline.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
