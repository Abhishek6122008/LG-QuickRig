import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/constants.dart';
import '../../core/ssh/ssh_credentials.dart';

/// Persists [SSHCredentials] in the platform's secure enclave:
///   Android → EncryptedSharedPreferences (Keystore-backed, API 23+)
///   iOS     → Keychain
///   Linux   → libsecret / keyring
///
/// All five fields (host, port, username, password, nodeCount) are stored.
/// The password is protected by the same encryption as the other fields —
/// no separate handling is required.
class CredentialsRepository {
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
    // Clears corrupted storage rather than crash-looping (e.g. after emulator hard-kill).
    resetOnError: true,
  );

  final _storage = const FlutterSecureStorage(aOptions: _androidOptions);

  // Storage keys — prefixed to avoid collisions with other plugins.
  static const _kHost = 'lg_cred_host';
  static const _kPort = 'lg_cred_port';
  static const _kUsername = 'lg_cred_username';
  static const _kPassword = 'lg_cred_password';
  static const _kNodeCount = 'lg_cred_node_count';

  /// Returns saved credentials, or [null] if none have been saved yet.
  Future<SSHCredentials?> load() async {
    final host = await _storage.read(key: _kHost);
    if (host == null || host.isEmpty) return null;

    return SSHCredentials(
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
  }

  /// Persists [creds] to secure storage, overwriting any previous values.
  Future<void> save(SSHCredentials creds) async {
    await Future.wait([
      _storage.write(key: _kHost, value: creds.host),
      _storage.write(key: _kPort, value: creds.port.toString()),
      _storage.write(key: _kUsername, value: creds.username),
      _storage.write(key: _kPassword, value: creds.password),
      _storage.write(key: _kNodeCount, value: creds.nodeCount.toString()),
    ]);
  }

  /// Removes all stored credentials.
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kHost),
      _storage.delete(key: _kPort),
      _storage.delete(key: _kUsername),
      _storage.delete(key: _kPassword),
      _storage.delete(key: _kNodeCount),
    ]);
  }

  /// Returns [true] if a host has been saved (sufficient to attempt connect).
  Future<bool> hasCredentials() async {
    final host = await _storage.read(key: _kHost);
    return host != null && host.isNotEmpty;
  }
}
