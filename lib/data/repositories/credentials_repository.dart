import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  static const _platformChannel =
      MethodChannel('com.liqtech.lg_quickrig/commands');

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
        await _platformChannel.invokeMethod('clearCredentials');
      } catch (_) {}
    }
  }

  Future<void> _mirrorToWidgets(SSHCredentials creds) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _platformChannel.invokeMethod('saveCredentials', {
        'host': creds.host,
        'port': creds.port.toString(),
        'username': creds.username,
        'password': creds.password,
        'nodeCount': creds.nodeCount.toString(),
      });
    } catch (_) {}
  }

  Future<bool> hasCredentials() async {
    final host = await _storage.read(key: _kHost);
    return host != null && host.isNotEmpty;
  }
}
