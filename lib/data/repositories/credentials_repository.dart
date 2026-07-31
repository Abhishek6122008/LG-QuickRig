import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants.dart';
import '../../core/ssh/ssh_credentials.dart';

class CredentialsRepository {
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,

    resetOnError: true,
  );

  final _storage = const FlutterSecureStorage(aOptions: _androidOptions);

  static const _kHost = 'lg_cred_host';
  static const _kPort = 'lg_cred_port';
  static const _kUsername = 'lg_cred_username';
  static const _kPassword = 'lg_cred_password';
  static const _kNodeCount = 'lg_cred_node_count';

  // Not part of SSHCredentials on purpose — it isn't an SSH credential and
  // must not be mirrored to the Android widgets.
  static const _kGeminiKey = 'gemini_api_key';
  static const _kCopilotEnabled = 'copilot_enabled';

  Future<SSHCredentials?> load() async {
    final host = await _storage.read(key: _kHost);
    if (host == null || host.isEmpty) return null;

    final creds = SSHCredentials(
      host: host,
      port: int.tryParse(
            await _storage.read(key: _kPort) ?? '',
          ) ??
          LGDefaults.port,
      username:
          await _storage.read(key: _kUsername) ?? LGDefaults.username,
      password: await _storage.read(key: _kPassword) ?? '',
      nodeCount: int.tryParse(
            await _storage.read(key: _kNodeCount) ?? '',
          ) ??
          3,
    );

    await _mirrorToWidgets(creds);
    return creds;
  }

  Future<void> save(SSHCredentials creds) async {
    await Future.wait([
      _storage.write(key: _kHost, value: creds.host),
      _storage.write(key: _kPort, value: creds.port.toString()),
      _storage.write(key: _kUsername, value: creds.username),
      _storage.write(key: _kPassword, value: creds.password),
      _storage.write(key: _kNodeCount, value: creds.nodeCount.toString()),
    ]);
    await _mirrorToWidgets(creds);
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kHost),
      _storage.delete(key: _kPort),
      _storage.delete(key: _kUsername),
      _storage.delete(key: _kPassword),
      _storage.delete(key: _kNodeCount),
    ]);

    if (!kIsWeb && Platform.isAndroid) {
      try {
        await platformCommandsChannel.invokeMethod('clearCredentials');
      } catch (_) {}
    }
  }

  Future<void> _mirrorToWidgets(SSHCredentials creds) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await platformCommandsChannel.invokeMethod('saveCredentials', {
        'host': creds.host,
        'port': creds.port.toString(),
        'username': creds.username,
        'password': creds.password,
        'nodeCount': creds.nodeCount.toString(),
      });
    } catch (_) {}
  }

  Future<String?> loadGeminiKey() => _storage.read(key: _kGeminiKey);

  Future<void> saveGeminiKey(String key) =>
      _storage.write(key: _kGeminiKey, value: key);

  // Off by default — Copilot spends the user's own API credits, so it's an
  // opt-in, not something that starts calling out on first launch.
  Future<bool> loadCopilotEnabled() async =>
      (await _storage.read(key: _kCopilotEnabled)) == 'true';

  Future<void> saveCopilotEnabled(bool enabled) =>
      _storage.write(key: _kCopilotEnabled, value: enabled.toString());
}
