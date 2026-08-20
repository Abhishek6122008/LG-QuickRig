import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../data/repositories/credentials_repository.dart';
import '../../services/copilot_service.dart';
import '../settings/settings_screen.dart';

/// Bottom-sheet chat for the Gemini Copilot, opened from the dashboard FAB.
class CopilotSheet extends StatefulWidget {
  /// Sent automatically on open if Copilot is already enabled and keyed —
  /// used by the dashboard's error banner to ask for a connection diagnosis.
  final String? initialPrompt;

  const CopilotSheet({super.key, this.initialPrompt});

  static Future<void> show(BuildContext context, {String? initialPrompt}) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => CopilotSheet(initialPrompt: initialPrompt),
      );

  @override
  State<CopilotSheet> createState() => _CopilotSheetState();
}

class _CopilotSheetState extends State<CopilotSheet> {
  final _copilot = sl<CopilotService>();
  final _credsRepo = sl<CredentialsRepository>();
  final _inputCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  bool _loadingState = true;
  bool _enabled = false;
  bool _hasKey = false;
  double _dailyCap = CredentialsRepository.defaultDailyCapUsd;
  bool _savingKey = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _keyCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final enabled = await _credsRepo.loadCopilotEnabled();
    final key = await _credsRepo.loadGeminiKey();
    final cap = await _credsRepo.loadDailyCapUsd();
    await _copilot.loadTodayUsage();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _hasKey = (key ?? '').trim().isNotEmpty;
      _dailyCap = cap;
      _loadingState = false;
    });
    final prompt = widget.initialPrompt;
    if (prompt != null && _enabled && _hasKey) _send(prompt);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) await _loadState();
  }

  Future<void> _saveKey() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) return;
    setState(() => _savingKey = true);
    await _credsRepo.saveGeminiKey(key);
    if (!mounted) return;
    setState(() {
      _hasKey = true;
      _savingKey = false;
    });
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _inputCtrl.text).trim();
    if (text.isEmpty || _busy) return;
    _inputCtrl.clear();
    setState(() {
      _busy = true;
      _error = null;
    });
    _scrollToEnd();
    try {
      await _copilot.send(text);
    } catch (e) {
      _error = e.toString();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  String? _usageLabel() {
    final today = _copilot.todayUsage;
    if (today == null) return null;
    final tokens = today.promptTokens + today.outputTokens;
    if (tokens == 0) return null;
    final spent = _copilot.todayCostUsd;
    return '~$tokens tokens · ~\$${spent.toStringAsFixed(4)} today '
        '· cap \$${_dailyCap.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final usage = _usageLabel();

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Copilot',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (usage != null)
                        Text(
                          usage,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Clear chat',
                    onPressed: (_busy || !_copilot.hasMessages)
                        ? null
                        : () => setState(_copilot.clear),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loadingState) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_enabled) {
      return _CenteredPrompt(
        icon: Icons.power_settings_new,
        message: 'Copilot is turned off.\nIt uses your own Gemini API '
            'credits, so it stays opt-in.',
        buttonLabel: 'Open Settings',
        onPressed: _openSettings,
      );
    }
    if (!_hasKey) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.vpn_key_outlined,
                size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            const Text(
              'Add your Gemini API key to start.\nFree at aistudio.google.com — no card required.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Gemini API key',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _saveKey(),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _savingKey ? null : _saveKey,
              child: _savingKey
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save key'),
            ),
          ],
        ),
      );
    }
    return _buildChat(context);
  }

  Widget _buildChat(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final msgs = _copilot.transcript;
    return Column(
      children: [
        Expanded(
          child: msgs.isEmpty
              ? Center(
                  child: Text(
                    'Try: "fly to the Colosseum,\npin it and orbit"',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: msgs.length + (_busy ? 1 : 0),
                  itemBuilder: (_, i) => i == msgs.length
                      ? const _TypingBubble()
                      : _Bubble(msg: msgs[i]),
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _error!,
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ask the rig anything…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.send),
                onPressed: _busy ? null : _send,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CenteredPrompt extends StatelessWidget {
  final IconData icon;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _CenteredPrompt({
    required this.icon,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final CopilotMessage msg;
  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color:
              isUser ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(msg.text),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
