import 'package:flutter/material.dart';

import '../../core/ssh/ssh_credentials.dart';
import '../../shared/widgets/connection_status_badge.dart';
import '../settings/settings_screen.dart';
import 'dashboard_controller.dart';

/// The app's landing page.
///
/// Shows the LG connection state, a connect/disconnect button, and a grid of
/// quick-action tiles for the most common LG operations.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _ctrl = DashboardController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        return Scaffold(
          appBar: _buildAppBar(),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ConnectionCard(
                ctrl: _ctrl,
                onConnect: _connect,
                onDisconnect: _ctrl.disconnect,
              ),
              if (_ctrl.lastError != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: _ctrl.lastError!),
              ],
              const SizedBox(height: 24),
              _QuickActionsGrid(
                ctrl: _ctrl,
                onReboot: () => _confirmAndRun(
                  context,
                  title: 'Reboot LG?',
                  body:
                      'This will reboot all ${_ctrl.credentials?.nodeCount ?? 1} node(s). '
                      'The SSH connection will be lost until they come back online.',
                  action: _ctrl.reboot,
                ),
                onShutdown: () => _confirmAndRun(
                  context,
                  title: 'Shutdown LG?',
                  body:
                      'This will power off all ${_ctrl.credentials?.nodeCount ?? 1} node(s).',
                  action: _ctrl.shutdown,
                ),
                onRestart: _ctrl.restartServices,
                onSync: _ctrl.sync,
                onBlankScreens: _ctrl.blankScreens,
                onCleanKML: _ctrl.cleanKML,
              ),
              if (_ctrl.lastActionLabel != null) ...[
                const SizedBox(height: 20),
                _LastActionBar(
                  label: _ctrl.lastActionLabel!,
                  time: _ctrl.lastActionTime,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    final busy = _ctrl.isBusy || _ctrl.isAutoConnecting;
    return AppBar(
      title: const Text(
        'LG QuickRig',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      actions: [
        if (busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: ConnectionStatusBadge(state: _ctrl.connectionState),
            ),
          ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'SSH Settings',
          onPressed: _openSettings,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _connect() => _ctrl.connect();

  Future<void> _openSettings() async {
    final saved = await Navigator.push<SSHCredentials>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (saved != null && mounted) {
      await _ctrl.connect(creds: saved);
    }
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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await action();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ConnectionCard extends StatelessWidget {
  final DashboardController ctrl;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const _ConnectionCard({
    required this.ctrl,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final connected = ctrl.isConnected;
    final busy = ctrl.isBusy || ctrl.isAutoConnecting;
    final creds = ctrl.credentials;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              connected && creds != null
                  ? '${creds.username}@${creds.host}  ·  '
                    '${creds.nodeCount} node${creds.nodeCount != 1 ? 's' : ''}'
                  : ctrl.isAutoConnecting
                      ? 'Connecting…'
                      : 'Not connected — tap Connect or open Settings',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: connected
                        ? const Color(0xFF1E8E3E)
                        : scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy
                    ? null
                    : connected
                        ? onDisconnect
                        : onConnect,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(connected ? Icons.link_off : Icons.link),
                label: Text(
                  busy
                      ? (connected ? 'Disconnecting…' : 'Connecting…')
                      : (connected ? 'Disconnect' : 'Connect'),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: connected ? Colors.red : null,
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

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE8E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF4C7C3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC5221F), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFC5221F), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions grid ────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final DashboardController ctrl;
  final VoidCallback onReboot;
  final VoidCallback onShutdown;
  final VoidCallback onRestart;
  final VoidCallback onSync;
  final VoidCallback onBlankScreens;
  final VoidCallback onCleanKML;

  const _QuickActionsGrid({
    required this.ctrl,
    required this.onReboot,
    required this.onShutdown,
    required this.onRestart,
    required this.onSync,
    required this.onBlankScreens,
    required this.onCleanKML,
  });

  @override
  Widget build(BuildContext context) {
    final connected = ctrl.isConnected;
    final busy = ctrl.isBusy;

    final tiles = [
      _TileConfig(
        label: 'Reboot',
        icon: Icons.restart_alt,
        color: const Color(0xFFE8710A),
        onTap: onReboot,
      ),
      _TileConfig(
        label: 'Restart Services',
        icon: Icons.refresh_rounded,
        color: const Color(0xFF1A73E8),
        onTap: onRestart,
      ),
      _TileConfig(
        label: 'Shutdown',
        icon: Icons.power_settings_new,
        color: const Color(0xFFD93025),
        onTap: onShutdown,
      ),
      _TileConfig(
        label: 'Sync',
        icon: Icons.sync,
        color: const Color(0xFF12A4AF),
        onTap: onSync,
      ),
      _TileConfig(
        label: 'Blank Screens',
        icon: Icons.tv_off_outlined,
        color: const Color(0xFF5F6368),
        onTap: onBlankScreens,
      ),
      _TileConfig(
        label: 'Clean KML',
        icon: Icons.delete_sweep_outlined,
        color: const Color(0xFF9334E6),
        onTap: onCleanKML,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: tiles.map((t) {
            final enabled = !busy && connected;
            return _ActionTile(config: t, enabled: enabled);
          }).toList(),
        ),
      ],
    );
  }
}

class _TileConfig {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TileConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _ActionTile extends StatelessWidget {
  final _TileConfig config;
  final bool enabled;

  const _ActionTile({required this.config, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconColor = enabled ? config.color : scheme.onSurface.withValues(alpha: 0.26);
    final labelColor = enabled ? scheme.onSurface : scheme.onSurface.withValues(alpha: 0.38);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? config.onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: enabled
                      ? config.color.withValues(alpha: 0.12)
                      : scheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(config.icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
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

// ── Last action footer ────────────────────────────────────────────────────────

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
