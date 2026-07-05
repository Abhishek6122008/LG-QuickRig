import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/di/service_locator.dart';
import '../../core/ssh/ssh_credentials.dart';
import '../../data/repositories/credentials_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repo = sl<CredentialsRepository>();
  final _formKey = GlobalKey<FormState>();

  final _hostCtrl = TextEditingController(text: LGDefaults.host);
  final _portCtrl = TextEditingController(text: LGDefaults.port.toString());
  final _userCtrl = TextEditingController(text: LGDefaults.username);
  final _passCtrl = TextEditingController();
  final _nodeCtrl = TextEditingController(text: '3');

  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;

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
    } catch (_) {
      // Secure storage unavailable — start from defaults instead of
      // spinning forever.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final creds = SSHCredentials(
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      username: _userCtrl.text.trim(),
      password: _passCtrl.text.isEmpty ? _savedPassword : _passCtrl.text,
      nodeCount: int.parse(_nodeCtrl.text.trim()),
    );

    await _repo.save(creds);

    if (!mounted) return;
    Navigator.pop(context, creds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSH Settings'),
        actions: [
          TextButton(
            onPressed: (_loading || _saving) ? null : _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _SectionLabel('LG Master Node'),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 16),
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
                            if (n == null || n < 1 || n > 65535) {
                              return 'Invalid port';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
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
                            if (n == null || n < 1 || n > 20) {
                              return '1–20 nodes';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('Credentials'),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 16),
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
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: (_loading || _saving) ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save & Connect'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}
