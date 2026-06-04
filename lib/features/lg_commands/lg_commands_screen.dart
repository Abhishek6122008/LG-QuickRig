import 'package:flutter/material.dart';

import '../../shared/widgets/connection_status_badge.dart';
import 'lg_commands_controller.dart';

/// A preset-commands panel for the Liquid Galaxy cluster.
///
/// Shows connection status at the top, system command buttons, directional
/// navigation controls, a camera/orbit panel, and an auto-scrolling output log.
/// Destructive commands (Reboot / Shutdown) require confirmation before firing.
class LGCommandsScreen extends StatefulWidget {
  const LGCommandsScreen({super.key});

  @override
  State<LGCommandsScreen> createState() => _LGCommandsScreenState();
}

class _LGCommandsScreenState extends State<LGCommandsScreen> {
  final _ctrl = LGCommandsController();
  final _scrollCtrl = ScrollController();

  // Camera / orbit fields
  final _latCtrl = TextEditingController(text: '0');
  final _lngCtrl = TextEditingController(text: '0');
  final _rangeCtrl = TextEditingController(text: '10000');
  final _tiltCtrl = TextEditingController(text: '45');

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _rangeCtrl.dispose();
    _tiltCtrl.dispose();
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
                Expanded(
                  child: ListView(
                    children: [
                      _CommandButtons(ctrl: _ctrl, onTap: _handleCommand),
                      const SizedBox(height: 20),
                      _NavigationPad(ctrl: _ctrl),
                      const SizedBox(height: 20),
                      _CameraOrbitPanel(
                        ctrl: _ctrl,
                        latCtrl: _latCtrl,
                        lngCtrl: _lngCtrl,
                        rangeCtrl: _rangeCtrl,
                        tiltCtrl: _tiltCtrl,
                        onFlyTo: _flyTo,
                        onOrbitPlay: _orbitPlay,
                        onOrbitStop: _ctrl.orbitStop,
                      ),
                      const SizedBox(height: 20),
                      _OutputHeader(ctrl: _ctrl),
                      const SizedBox(height: 8),
                      _LogPanel(log: _ctrl.log, scrollCtrl: _scrollCtrl),
                    ],
                  ),
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

  void _flyTo() {
    final lat = double.tryParse(_latCtrl.text) ?? 0;
    final lng = double.tryParse(_lngCtrl.text) ?? 0;
    final range = double.tryParse(_rangeCtrl.text) ?? 10000;
    final tilt = double.tryParse(_tiltCtrl.text) ?? 0;
    _ctrl.flyTo(lat: lat, lng: lng, range: range, tilt: tilt);
  }

  void _orbitPlay() {
    final lat = double.tryParse(_latCtrl.text) ?? 0;
    final lng = double.tryParse(_lngCtrl.text) ?? 0;
    final range = double.tryParse(_rangeCtrl.text) ?? 10000;
    final tilt = double.tryParse(_tiltCtrl.text) ?? 45;
    _ctrl.orbitPlay(lat: lat, lng: lng, range: range, tilt: tilt);
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
              Icons.lan_outlined,
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

// ── System command button definitions ─────────────────────────────────────────

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
        _SectionLabel('Commands'),
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

// ── Directional navigation pad ────────────────────────────────────────────────

class _NavigationPad extends StatelessWidget {
  final LGCommandsController ctrl;
  const _NavigationPad({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final enabled = ctrl.isConnected && !ctrl.isBusy;
    final color = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Navigation'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              children: [
                // Up
                _NavButton(
                  icon: Icons.keyboard_arrow_up,
                  tooltip: 'Move Up',
                  enabled: enabled,
                  color: color,
                  onTap: ctrl.moveUp,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Rotate Left
                    _NavButton(
                      icon: Icons.rotate_left,
                      tooltip: 'Rotate Left',
                      enabled: enabled,
                      color: color,
                      onTap: ctrl.rotateLeft,
                    ),
                    const SizedBox(width: 8),
                    // Center placeholder
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.public, color: Colors.white24, size: 22),
                    ),
                    const SizedBox(width: 8),
                    // Rotate Right
                    _NavButton(
                      icon: Icons.rotate_right,
                      tooltip: 'Rotate Right',
                      enabled: enabled,
                      color: color,
                      onTap: ctrl.rotateRight,
                    ),
                  ],
                ),
                // Down
                _NavButton(
                  icon: Icons.keyboard_arrow_down,
                  tooltip: 'Move Down',
                  enabled: enabled,
                  color: color,
                  onTap: ctrl.moveDown,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? color.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(
              icon,
              color: enabled ? color : Colors.white24,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Camera / Orbit panel ──────────────────────────────────────────────────────

class _CameraOrbitPanel extends StatelessWidget {
  final LGCommandsController ctrl;
  final TextEditingController latCtrl;
  final TextEditingController lngCtrl;
  final TextEditingController rangeCtrl;
  final TextEditingController tiltCtrl;
  final VoidCallback onFlyTo;
  final VoidCallback onOrbitPlay;
  final VoidCallback onOrbitStop;

  const _CameraOrbitPanel({
    required this.ctrl,
    required this.latCtrl,
    required this.lngCtrl,
    required this.rangeCtrl,
    required this.tiltCtrl,
    required this.onFlyTo,
    required this.onOrbitPlay,
    required this.onOrbitStop,
  });

  @override
  Widget build(BuildContext context) {
    final connected = ctrl.isConnected;
    final busy = ctrl.isBusy;
    final orbitPlaying = ctrl.isOrbitPlaying;
    final canAct = connected && !busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel('Camera / Orbit'),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CoordField(
                        label: 'Latitude',
                        ctrl: latCtrl,
                        enabled: canAct,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CoordField(
                        label: 'Longitude',
                        ctrl: lngCtrl,
                        enabled: canAct,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _CoordField(
                        label: 'Range (m)',
                        ctrl: rangeCtrl,
                        enabled: canAct,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CoordField(
                        label: 'Tilt (°)',
                        ctrl: tiltCtrl,
                        enabled: canAct,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: canAct ? onFlyTo : null,
                        icon: const Icon(Icons.flight_takeoff, size: 16),
                        label: const Text('Fly To'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: orbitPlaying
                          ? FilledButton.icon(
                              onPressed: onOrbitStop,
                              icon: const Icon(Icons.stop, size: 16),
                              label: const Text('Stop Orbit'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: canAct ? onOrbitPlay : null,
                              icon: const Icon(Icons.rotate_right, size: 16),
                              label: const Text('Start Orbit'),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CoordField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool enabled;

  const _CoordField({
    required this.label,
    required this.ctrl,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
    );
  }
}

// ── Output section header ──────────────────────────────────────────────────────

class _OutputHeader extends StatelessWidget {
  final LGCommandsController ctrl;
  const _OutputHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _SectionLabel('Output'),
        TextButton.icon(
          onPressed: ctrl.log.isEmpty ? null : ctrl.clearLog,
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Clear'),
        ),
      ],
    );
  }
}

// ── Log panel ──────────────────────────────────────────────────────────────────

class _LogPanel extends StatelessWidget {
  final List<LGCommandEntry> log;
  final ScrollController scrollCtrl;

  const _LogPanel({required this.log, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
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

// ── Shared section label ───────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
    );
  }
}
