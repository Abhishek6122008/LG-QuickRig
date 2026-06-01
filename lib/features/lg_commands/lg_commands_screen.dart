import 'package:flutter/material.dart';

import '../../shared/widgets/connection_status_badge.dart';
import 'lg_commands_controller.dart';

/// A preset-commands panel for the Liquid Galaxy cluster.
///
/// Shows connection status at the top, one button per LG command, and an
/// auto-scrolling output log below. Destructive commands (Reboot / Shutdown)
/// require confirmation before firing.
class LGCommandsScreen extends StatefulWidget {
  const LGCommandsScreen({super.key});

  @override
  State<LGCommandsScreen> createState() => _LGCommandsScreenState();
}

class _LGCommandsScreenState extends State<LGCommandsScreen> {
  final _ctrl = LGCommandsController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        if (_ctrl.log.isNotEmpty) _scrollToBottom();

        return Scaffold(
          appBar: AppBar(
            title: const Text('LG Commands'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: ConnectionStatusBadge(state: _ctrl.connectionState),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusCard(ctrl: _ctrl),
                const SizedBox(height: 16),
                _CommandButtons(ctrl: _ctrl, onTap: _handleCommand),
                const SizedBox(height: 16),
                _OutputHeader(ctrl: _ctrl),
                const SizedBox(height: 8),
                Expanded(
                  child: _LogPanel(log: _ctrl.log, scrollCtrl: _scrollCtrl),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _handleCommand(String label, Future<void> Function() action) {
    if (label == 'Reboot' || label == 'Shutdown') {
      _confirmThenRun(label, action);
    } else {
      action();
    }
  }

  Future<void> _confirmThenRun(
    String label,
    Future<void> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$label LG?'),
        content: Text(
          label == 'Reboot'
              ? 'This will reboot all nodes. The SSH connection will be lost '
                'until they come back online.'
              : 'This will power off all nodes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) action();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final LGCommandsController ctrl;
  const _StatusCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final connected = ctrl.isConnected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              connected ? Icons.lan_outlined : Icons.lan_outlined,
              color: connected ? Colors.greenAccent : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                connected
                    ? 'Connected — ready to send commands'
                    : 'Not connected — go to Dashboard to connect',
                style: TextStyle(
                  color: connected ? Colors.greenAccent : Colors.white54,
                  fontSize: 13,
                ),
              ),
            ),
            if (ctrl.isBusy)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Command button definitions ─────────────────────────────────────────────

class _CmdConfig {
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() action;

  const _CmdConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.action,
  });
}

class _CommandButtons extends StatelessWidget {
  final LGCommandsController ctrl;
  final void Function(String label, Future<void> Function() action) onTap;

  const _CommandButtons({required this.ctrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cmds = [
      _CmdConfig(
        label: 'Reboot',
        icon: Icons.restart_alt,
        color: Colors.orange,
        action: ctrl.reboot,
      ),
      _CmdConfig(
        label: 'Shutdown',
        icon: Icons.power_settings_new,
        color: Colors.redAccent,
        action: ctrl.shutdown,
      ),
      _CmdConfig(
        label: 'Sync',
        icon: Icons.sync,
        color: Colors.tealAccent,
        action: ctrl.sync,
      ),
      _CmdConfig(
        label: 'Restart Slaves',
        icon: Icons.refresh_rounded,
        color: Colors.blueAccent,
        action: ctrl.restartSlaves,
      ),
      _CmdConfig(
        label: 'Blank Screens',
        icon: Icons.tv_off_outlined,
        color: Colors.grey,
        action: ctrl.blankScreens,
      ),
    ];

    final enabled = ctrl.isConnected && !ctrl.isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Commands',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.4,
          children: cmds.map((c) {
            final active = ctrl.activeCommand == c.label;
            final iconColor = enabled ? c.color : Colors.white24;
            final labelColor = enabled ? Colors.white : Colors.white38;

            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? () => onTap(c.label, c.action) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: enabled
                              ? c.color.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: active
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: c.color,
                                ),
                              )
                            : Icon(c.icon, color: iconColor, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.label,
                          style: TextStyle(
                            fontSize: 12,
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
          }).toList(),
        ),
      ],
    );
  }
}

// ── Output section header ──────────────────────────────────────────────────

class _OutputHeader extends StatelessWidget {
  final LGCommandsController ctrl;
  const _OutputHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Output',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.6,
              ),
        ),
        TextButton.icon(
          onPressed: ctrl.log.isEmpty ? null : ctrl.clearLog,
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Clear'),
        ),
      ],
    );
  }
}

// ── Log panel ──────────────────────────────────────────────────────────────

class _LogPanel extends StatelessWidget {
  final List<LGCommandEntry> log;
  final ScrollController scrollCtrl;

  const _LogPanel({required this.log, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: log.isEmpty
          ? const Center(
              child: Text(
                'No output yet.',
                style: TextStyle(
                  color: Colors.white38,
                  fontFamily: 'monospace',
                ),
              ),
            )
          : ListView.builder(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: log.length,
              itemBuilder: (_, i) {
                final e = log[i];
                final t = e.timestamp;
                final ts =
                    '${t.hour.toString().padLeft(2, '0')}:'
                    '${t.minute.toString().padLeft(2, '0')}:'
                    '${t.second.toString().padLeft(2, '0')}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: '$ts ',
                          style: const TextStyle(color: Colors.white30),
                        ),
                        TextSpan(
                          text: '${e.label} ',
                          style: TextStyle(
                            color: e.isError
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: e.text,
                          style: TextStyle(
                            color: e.isError ? Colors.red[200] : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
