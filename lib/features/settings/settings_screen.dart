import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/ssh/ssh_credentials.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/repositories/credentials_repository.dart';
import '../../shared/widgets/busy_button.dart';
import '../../shared/widgets/section_label.dart';
import 'widget_buttons_dialog.dart';

/// Settings as a pushable route. Pops with the saved credentials, which is how
/// the Copilot sheet's "Open Settings" path triggers a reconnect.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SSH Settings')),
      body: SettingsView(
        onSaved: (creds) => Navigator.pop(context, creds),
      ),
    );
  }
}

/// The settings body, without a Scaffold — the app shell hosts this directly
/// as a tab, and [SettingsScreen] wraps it for the pushed-route case.
class SettingsView extends StatefulWidget {
  final ValueChanged<SSHCredentials> onSaved;

  const SettingsView({super.key, required this.onSaved});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _repo = sl<CredentialsRepository>();
  final _formKey = GlobalKey<FormState>();

  final _hostCtrl = TextEditingController(text: LGDefaults.host);
  final _portCtrl = TextEditingController(text: LGDefaults.port.toString());
  final _userCtrl = TextEditingController(text: LGDefaults.username);
  final _passCtrl = TextEditingController();
  final _nodeCtrl = TextEditingController(text: '3');
  final _geminiCtrl = TextEditingController();
  final _capCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;
  bool _copilotEnabled = false;
  bool _hasGeminiKey = false;
  String? _saveError;

  // Saved password is never shown in the field; keep it so an edit that
  // leaves the field blank doesn't wipe it.
  String _savedPassword = '';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    _nodeCtrl.dispose();
    _geminiCtrl.dispose();
    _capCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    try {
      final creds = await _repo.load();
      if (!mounted) return;
      if (creds != null) {
        _hostCtrl.text = creds.host;
        _portCtrl.text = creds.port.toString();
        _userCtrl.text = creds.username;
        _nodeCtrl.text = creds.nodeCount.toString();
        _savedPassword = creds.password;
      }
      _copilotEnabled = await _repo.loadCopilotEnabled();
      _hasGeminiKey = (await _repo.loadGeminiKey() ?? '').trim().isNotEmpty;
      _capCtrl.text = (await _repo.loadDailyCapUsd()).toStringAsFixed(2);
    } catch (_) {
      // Secure storage unavailable — start from defaults instead of
      // spinning forever.
      _capCtrl.text =
          CredentialsRepository.defaultDailyCapUsd.toStringAsFixed(2);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    final creds = SSHCredentials(
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text.isEmpty ? _savedPassword : _passCtrl.text,
      nodeCount: int.parse(_nodeCtrl.text.trim()),
    );

    // Previously unguarded: a keystore/libsecret write failure left _saving
    // true forever, disabling the Save button with no way back.
    try {
      await _repo.save(creds);

      final geminiKey = _geminiCtrl.text.trim();
      if (geminiKey.isNotEmpty) await _repo.saveGeminiKey(geminiKey);
      await _repo.saveCopilotEnabled(_copilotEnabled);

      final cap = double.tryParse(_capCtrl.text.trim());
      if (cap != null) await _repo.saveDailyCapUsd(cap);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'Could not save settings: $e';
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _saving = false);
    widget.onSaved(creds);
  }

  Future<void> _removeGeminiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Gemini key?'),
        content: const Text(
          'Copilot will stop working until you add a key again. Your SSH '
          'credentials are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _repo.deleteGeminiKey();
      if (mounted) {
        setState(() {
          _hasGeminiKey = false;
          _geminiCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _saveError = 'Could not remove key: $e');
    }
  }

  Future<void> _addQuickSettingsTile() async {
    String message;
    try {
      final ok = await platformCommandsChannel
              .invokeMethod<bool>('requestAddTile') ??
          false;
      message = ok
          ? 'Check the prompt to add the tile.'
          : 'Not supported here — pull down the shade, edit your tiles, and '
              'add LG QuickRig by hand.';
    } catch (_) {
      message = 'Could not ask the system. Pull down the shade, edit your '
          'tiles, and add LG QuickRig by hand.';
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pinWidget(String which) async {
    var pinned = false;
    try {
      pinned = await platformCommandsChannel
              .invokeMethod<bool>('pinWidget', {'widget': which}) ??
          false;
    } catch (_) {}
    if (!pinned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Launcher refused — long-press your home screen → Widgets → '
          'LG QuickRig.',
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionLabel('LG Master Node'),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _hostCtrl,
            decoration: const InputDecoration(
              labelText: 'Host / IP address',
              hintText: '192.168.2.2',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.dns_outlined),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _portCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '22',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 65535) return 'Invalid port';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextFormField(
                  controller: _nodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Node count',
                    hintText: '3',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n < 1 || n > 20) return '1–20 nodes';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('Credentials'),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _userCtrl,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'lg',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextFormField(
            controller: _passCtrl,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText:
                  'Stored securely. Leave blank to keep the saved password.',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionLabel('Copilot (optional)'),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _copilotEnabled,
            onChanged: (v) => setState(() => _copilotEnabled = v),
            title: const Text('Enable Copilot'),
            subtitle: const Text(
              'AI assistant that spends YOUR Gemini API credits, not '
              'anyone else\'s. Free tier covers casual use — a '
              'typical message costs roughly 700–1500 tokens '
              '(~\$0.001–\$0.003 on the paid tier).',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _geminiCtrl,
            decoration: InputDecoration(
              labelText: 'Gemini API key',
              helperText: _hasGeminiKey
                  ? 'A key is saved. Leave blank to keep it.'
                  : 'Free at aistudio.google.com.',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.auto_awesome_outlined),
            ),
            obscureText: true,
            textInputAction: TextInputAction.next,
          ),
          if (_hasGeminiKey)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saving ? null : _removeGeminiKey,
                icon: const Icon(Icons.key_off_outlined, size: 18),
                label: const Text('Remove saved key'),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _capCtrl,
            decoration: const InputDecoration(
              labelText: 'Daily AI budget (USD)',
              helperText: 'Copilot refuses to send once the day\'s estimated '
                  'spend reaches this. Resets at local midnight.',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.savings_outlined),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _save(),
            validator: (v) {
              final d = double.tryParse((v ?? '').trim());
              if (d == null || d <= 0) return 'Enter an amount above 0';
              return null;
            },
          ),
          if (Platform.isAndroid) ...[
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel('Home screen & shade'),
            const SizedBox(height: AppSpacing.xs),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dashboard_customize_outlined),
              title: const Text('Command Bar (4×1)'),
              subtitle: const Text('Your 4 chosen actions'),
              onTap: () => _pinWidget('home'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.monitor_heart_outlined),
              title: const Text('Live Status (2×2)'),
              subtitle: const Text('Connection status + 3 chosen actions'),
              onTap: () => _pinWidget('status'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune),
              title: const Text('Customize widget buttons'),
              subtitle: const Text('Choose the actions both widgets show'),
              onTap: () => WidgetButtonsDialog.show(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_to_home_screen),
              title: const Text('Add Quick Settings tile'),
              subtitle: const Text('Rig status in the notification shade'),
              onTap: _addQuickSettingsTile,
            ),
          ],
          if (_saveError != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              _saveError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          BusyButton(
            busy: _saving,
            onPressed: _save,
            label: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }
}
