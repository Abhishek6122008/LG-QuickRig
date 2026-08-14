import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/ssh/ssh_credentials.dart';
import '../../shared/widgets/connection_status_badge.dart';
import '../copilot/copilot_sheet.dart';
import '../lg_commands/image_overlay_dialog.dart';
import '../settings/settings_screen.dart';
import 'dashboard_controller.dart';

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
          floatingActionButton: FloatingActionButton(
            tooltip: 'Copilot',
            onPressed: () => CopilotSheet.show(context),
            child: const Icon(Icons.auto_awesome),
          ),
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
                onImageOverlay: () => ImageOverlayDialog.show(context),
                onKmlTest: _ctrl.kmlTest,
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
        if (Platform.isAndroid)
          IconButton(
            icon: const Icon(Icons.widgets_outlined),
            tooltip: 'Add widget to home screen',
            onPressed: _showWidgetPicker,
          ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'SSH Settings',
          onPressed: _openSettings,
        ),
      ],
    );
  }

  Future<void> _showWidgetPicker() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Command Bar (4×1)'),
              subtitle: const Text('Your 4 chosen actions — customize below'),
              onTap: () => Navigator.pop(ctx, 'home'),
            ),
            ListTile(
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('Live Status (2×2)'),
              subtitle: const Text(
                  'Connection status + your 3 chosen actions'),
              onTap: () => Navigator.pop(ctx, 'status'),
            ),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Customize widget buttons'),
              subtitle: const Text('Choose the actions both widgets show'),
              onTap: () => Navigator.pop(ctx, 'customize'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !mounted) return;

    if (choice == 'customize') {
      await _WidgetButtonsDialog.show(context);
      return;
    }

    var pinned = false;
    try {
      pinned = await platformCommandsChannel
              .invokeMethod<bool>('pinWidget', {'widget': choice}) ??
          false;
    } catch (_) {}
    if (!pinned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Launcher refused — long-press your home screen → Widgets → LG QuickRig.',
        ),
      ));
    }
  }

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
          IconButton(
            icon: const Icon(Icons.auto_awesome,
                color: Color(0xFFC5221F), size: 18),
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

class _QuickActionsGrid extends StatelessWidget {
  final DashboardController ctrl;
  final VoidCallback onReboot;
  final VoidCallback onShutdown;
  final VoidCallback onRestart;
  final VoidCallback onSync;
  final VoidCallback onBlankScreens;
  final VoidCallback onCleanKML;
  final VoidCallback onImageOverlay;
  final VoidCallback onKmlTest;

  const _QuickActionsGrid({
    required this.ctrl,
    required this.onReboot,
    required this.onShutdown,
    required this.onRestart,
    required this.onSync,
    required this.onBlankScreens,
    required this.onCleanKML,
    required this.onImageOverlay,
    required this.onKmlTest,
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
      _TileConfig(
        label: 'Overlay',
        icon: Icons.add_photo_alternate_outlined,
        color: const Color(0xFF1A73E8),
        onTap: onImageOverlay,
      ),
      _TileConfig(
        label: 'KML Test',
        icon: Icons.science_outlined,
        color: const Color(0xFF1E8E3E),
        onTap: onKmlTest,
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

/// Picks the four actions shown on the Command Bar home widget.
/// Keys must match the action catalog in LGHomeWidgetProvider.kt.
class _WidgetButtonsDialog extends StatefulWidget {
  const _WidgetButtonsDialog();

  static const actions = {
    'clean': 'Clean KML',
    'relaunch': 'Relaunch',
    'reboot': 'Reboot',
    'shutdown': 'Shutdown',
    'sync': 'Sync',
    'blank': 'Blank Screens',
    'overlay': 'Image Overlay',
    'flyto': 'Fly To',
    'orbit': 'Orbit',
    'pin': 'Drop Pin',
  };

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const _WidgetButtonsDialog(),
    );
  }

  @override
  State<_WidgetButtonsDialog> createState() => _WidgetButtonsDialogState();
}

class _WidgetButtonsDialogState extends State<_WidgetButtonsDialog> {
  List<String> _home = ['clean', 'relaunch', 'reboot', 'shutdown'];
  List<String> _status = ['flyto', 'orbit', 'overlay'];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final home = await platformCommandsChannel
          .invokeListMethod<String>('getWidgetButtons', {'widget': 'home'});
      if (home != null && home.length == 4) _home = List.of(home);
      final status = await platformCommandsChannel
          .invokeListMethod<String>('getWidgetButtons', {'widget': 'status'});
      if (status != null && status.length == 3) _status = List.of(status);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await platformCommandsChannel.invokeMethod(
          'saveWidgetButtons', {'widget': 'home', 'buttons': _home});
      await platformCommandsChannel.invokeMethod(
          'saveWidgetButtons', {'widget': 'status', 'buttons': _status});
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Widget> _section(String title, List<String> keys) => [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ),
        ...List.generate(keys.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: DropdownButtonFormField<String>(
              initialValue: keys[i],
              decoration: InputDecoration(
                labelText: 'Button ${i + 1}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: _WidgetButtonsDialog.actions.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged:
                  _saving ? null : (v) => setState(() => keys[i] = v!),
            ),
          );
        }),
      ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Widget buttons'),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._section('Command Bar (4×1)', _home),
                  const SizedBox(height: 8),
                  ..._section('Live Status (2×2)', _status),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: (_loading || _saving) ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Apply'),
        ),
      ],
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
