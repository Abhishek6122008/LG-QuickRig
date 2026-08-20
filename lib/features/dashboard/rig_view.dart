import 'package:flutter/material.dart';

import '../../core/theme/app_accents.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/action_tile.dart';
import '../../shared/widgets/busy_button.dart';
import '../copilot/copilot_sheet.dart';
import '../lg_commands/image_overlay_dialog.dart';
import 'dashboard_controller.dart';

/// The Rig tab: connection state and the destructive/maintenance actions.
/// Camera work lives in its own tab so this grid stays scannable.
class RigView extends StatelessWidget {
  final DashboardController ctrl;

  const RigView({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xxl),
      children: [
        _ConnectionCard(ctrl: ctrl),
        if (ctrl.lastError != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ErrorBanner(message: ctrl.lastError!),
        ],
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Quick Actions',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.md),
        ActionTileGrid(
          enabled: ctrl.isConnected && !ctrl.isBusy,
          tiles: _tiles(context),
        ),
        if (ctrl.lastActionLabel != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _LastActionBar(
            label: ctrl.lastActionLabel!,
            time: ctrl.lastActionTime,
          ),
        ],
      ],
    );
  }

  List<ActionTileConfig> _tiles(BuildContext context) {
    final a = context.accents;
    final nodes = ctrl.credentials?.nodeCount ?? 1;

    return [
      ActionTileConfig(
        label: 'Reboot',
        icon: Icons.restart_alt,
        color: a.orange,
        onTap: () => _confirmAndRun(
          context,
          title: 'Reboot LG?',
          body: 'This will reboot all $nodes node(s). The SSH connection '
              'will be lost until they come back online.',
          action: ctrl.reboot,
        ),
      ),
      ActionTileConfig(
        label: 'Restart Services',
        icon: Icons.refresh_rounded,
        color: a.blue,
        onTap: ctrl.restartServices,
      ),
      ActionTileConfig(
        label: 'Shutdown',
        icon: Icons.power_settings_new,
        color: a.red,
        onTap: () => _confirmAndRun(
          context,
          title: 'Shutdown LG?',
          body: 'This will power off all $nodes node(s).',
          action: ctrl.shutdown,
        ),
      ),
      ActionTileConfig(
        label: 'Sync',
        icon: Icons.sync,
        color: a.teal,
        onTap: ctrl.sync,
      ),
      ActionTileConfig(
        label: 'Blank Screens',
        icon: Icons.tv_off_outlined,
        color: a.grey,
        onTap: ctrl.blankScreens,
      ),
      ActionTileConfig(
        label: 'Clean KML',
        icon: Icons.delete_sweep_outlined,
        color: a.purple,
        // No confirm: it only removes what this app put on the rig.
        onTap: ctrl.cleanKML,
      ),
      ActionTileConfig(
        label: 'Overlay',
        icon: Icons.add_photo_alternate_outlined,
        color: a.blue,
        onTap: () => ImageOverlayDialog.show(context),
      ),
      ActionTileConfig(
        label: 'KML Test',
        icon: Icons.science_outlined,
        color: a.green,
        onTap: ctrl.kmlTest,
      ),
    ];
  }

  Future<void> _confirmAndRun(
    BuildContext context, {
    required String title,
    required String body,
    required Future<void> Function() action,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: ctx.accents.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) await action();
  }
}

class _ConnectionCard extends StatelessWidget {
  final DashboardController ctrl;

  const _ConnectionCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final connected = ctrl.isConnected;
    final busy = ctrl.isBusy || ctrl.isAutoConnecting;
    final creds = ctrl.credentials;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              connected && creds != null
                  ? '${creds.username}@${creds.host}  ·  '
                      '${creds.nodeCount} node${creds.nodeCount != 1 ? 's' : ''}'
                  : ctrl.isAutoConnecting
                      ? 'Connecting…'
                      : 'Not connected — tap Connect or open Settings',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: connected
                        ? context.accents.connected
                        : scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: BusyButton(
                busy: busy,
                onPressed: connected ? ctrl.disconnect : ctrl.connect,
                icon: Icon(connected ? Icons.link_off : Icons.link),
                label: Text(
                  busy
                      ? (connected ? 'Disconnecting…' : 'Connecting…')
                      : (connected ? 'Disconnect' : 'Connect'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: connected ? context.accents.red : null,
                  foregroundColor: connected ? Colors.white : null,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final a = context.accents;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: a.errorBg,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: a.errorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: a.errorFg, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: a.errorFg, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.auto_awesome, color: a.errorFg, size: 18),
            tooltip: 'Diagnose with Copilot',
            visualDensity: VisualDensity.compact,
            onPressed: () => CopilotSheet.show(
              context,
              initialPrompt: 'Diagnose this Liquid Galaxy connection error '
                  'and suggest how to fix it: "$message"',
            ),
          ),
        ],
      ),
    );
  }
}

class _LastActionBar extends StatelessWidget {
  final String label;
  final DateTime? time;

  const _LastActionBar({required this.label, this.time});

  @override
  Widget build(BuildContext context) {
    final t = time;
    final timeStr = t != null
        ? '${t.hour.toString().padLeft(2, '0')}:'
            '${t.minute.toString().padLeft(2, '0')}:'
            '${t.second.toString().padLeft(2, '0')}'
        : '';

    return Text(
      'Last action: $label${timeStr.isNotEmpty ? '  ·  $timeStr' : ''}',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      textAlign: TextAlign.center,
    );
  }
}
