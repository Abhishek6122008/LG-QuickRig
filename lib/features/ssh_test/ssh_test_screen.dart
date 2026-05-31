import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/ssh/ssh_client.dart';
import '../../core/ssh/ssh_credentials.dart';
import '../../data/repositories/credentials_repository.dart';
import '../../shared/widgets/connection_status_badge.dart';
import '../settings/settings_screen.dart';
import 'ssh_test_controller.dart';

/// Developer console for sending raw SSH commands to the LG master node.
///
/// Not part of the production UI — reached from the Dashboard's SSH Console
/// tile. Shares the singleton [LGSSHClient] with [DashboardScreen], so a
/// connection established here persists when navigating back.
class SSHTestScreen extends StatefulWidget {
  const SSHTestScreen({super.key});

  @override
  State<SSHTestScreen> createState() => _SSHTestScreenState();
}

class _SSHTestScreenState extends State<SSHTestScreen> {
  final _controller = SSHTestController();
  final _scrollCtrl = ScrollController();
  final _commandCtrl = TextEditingController();

  // Form fields — pre-filled from active connection or saved credentials.
  final _hostCtrl = TextEditingController(text: LGDefaults.host);
  final _portCtrl = TextEditingController(text: LGDefaults.port.toString());
  final _userCtrl = TextEditingController(text: LGDefaults.username);
  final _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prefillCredentials();
  }

  /// Pre-fills connection fields from the active session or stored credentials.
  Future<void> _prefillCredentials() async {
    // Prefer the live connection — avoids a storage round-trip.
    final active = sl<LGSSHClient>().credentials;
    if (active != null) {
      _applyToFields(active);
      return;
    }
    final saved = await sl<CredentialsRepository>().load();
    if (saved != null && mounted) _applyToFields(saved);
  }

  void _applyToFields(SSHCredentials c) {
    _hostCtrl.text = c.host;
    _portCtrl.text = c.port.toString();
    _userCtrl.text = c.username;
    if (c.password.isNotEmpty) _passCtrl.text = c.password;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _commandCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        if (_controller.log.isNotEmpty) _scrollToBottom();

        final connected = _controller.isConnected;
        final busy = _controller.isBusy;

        return Scaffold(
          appBar: AppBar(
            title: const Text('SSH Console'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: ConnectionStatusBadge(state: _controller.connectionState),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'SSH Settings',
                onPressed: () => _openSettings(context),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Connection ───────────────────────────────────────────────
                _SectionLabel('Connection'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _Field(
                        label: 'Host',
                        ctrl: _hostCtrl,
                        enabled: !connected && !busy,
                        hint: '192.168.2.2',
                        type: TextInputType.url,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Field(
                        label: 'Port',
                        ctrl: _portCtrl,
                        enabled: !connected && !busy,
                        hint: '22',
                        type: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Username',
                        ctrl: _userCtrl,
                        enabled: !connected && !busy,
                        hint: 'lg',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Field(
                        label: 'Password',
                        ctrl: _passCtrl,
                        enabled: !connected && !busy,
                        obscure: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : connected
                          ? _controller.disconnect
                          : _connect,
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
                    backgroundColor: connected ? Colors.redAccent : null,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Command ──────────────────────────────────────────────────
                _SectionLabel('Command'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commandCtrl,
                        enabled: connected && !busy,
                        onSubmitted: (_) => _runCommand(),
                        decoration: const InputDecoration(
                          hintText: 'e.g.  echo hello  |  df -h',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: (connected && !busy) ? _runCommand : null,
                      child: const Text('Run'),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Output log ───────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionLabel('Output'),
                    TextButton.icon(
                      onPressed:
                          _controller.log.isEmpty ? null : _controller.clearLog,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Clear'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _LogView(
                    log: _controller.log,
                    scrollCtrl: _scrollCtrl,
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

  void _connect() {
    _controller.connect(
      SSHCredentials(
        host: _hostCtrl.text.trim(),
        port: int.tryParse(_portCtrl.text) ?? LGDefaults.port,
        username: _userCtrl.text.trim(),
        password: _passCtrl.text,
      ),
    );
  }

  void _runCommand() {
    _controller.executeCommand(_commandCtrl.text);
  }

  Future<void> _openSettings(BuildContext context) async {
    final saved = await Navigator.push<SSHCredentials>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (saved != null && mounted) {
      _applyToFields(saved);
    }
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
// Local helpers
// ─────────────────────────────────────────────────────────────────────────────

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

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool enabled;
  final String? hint;
  final bool obscure;
  final TextInputType? type;

  const _Field({
    required this.label,
    required this.ctrl,
    required this.enabled,
    this.hint,
    this.obscure = false,
    this.type,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}

class _LogView extends StatelessWidget {
  final List<LogEntry> log;
  final ScrollController scrollCtrl;

  const _LogView({required this.log, required this.scrollCtrl});

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
