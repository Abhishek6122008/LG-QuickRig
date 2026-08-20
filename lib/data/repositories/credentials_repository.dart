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
  static const _kCopilotUsage = 'copilot_usage';
  static const _kCopilotCapUsd = 'copilot_daily_cap_usd';

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

  /// Settings treats a blank key field as "keep the saved key", so without
  /// this there is no way to remove a key once stored. [clear] only wipes SSH
  /// credentials.
  Future<void> deleteGeminiKey() => _storage.delete(key: _kGeminiKey);

  // Off by default — Copilot spends the user's own API credits, so it's an
  // opt-in, not something that starts calling out on first launch.
  Future<bool> loadCopilotEnabled() async =>
      (await _storage.read(key: _kCopilotEnabled)) == 'true';

  Future<void> saveCopilotEnabled(bool enabled) =>
      _storage.write(key: _kCopilotEnabled, value: enabled.toString());

  /// Token spend for one local calendar day. Persisted so the ceiling
  /// survives an app restart — in-memory counters made the cap trivially
  /// resettable by force-quitting.
  Future<CopilotUsage> loadUsage() async {
    final raw = await _storage.read(key: _kCopilotUsage) ?? '';
    return CopilotUsage.decode(raw);
  }

  Future<void> saveUsage(CopilotUsage usage) =>
      _storage.write(key: _kCopilotUsage, value: usage.encode());

  Future<double> loadDailyCapUsd() async {
    final raw = await _storage.read(key: _kCopilotCapUsd);
    return double.tryParse(raw ?? '') ?? defaultDailyCapUsd;
  }

  Future<void> saveDailyCapUsd(double usd) =>
      _storage.write(key: _kCopilotCapUsd, value: usd.toString());

  /// Low enough that a runaway loop is a rounding error, high enough that
  /// ordinary use never hits it — a typical message is ~$0.0005.
  static const double defaultDailyCapUsd = 0.25;
}

/// Accumulated Gemini token usage for [day] (local date, `YYYY-MM-DD`).
@immutable
class CopilotUsage {
  final String day;
  final int promptTokens;
  final int outputTokens;

  const CopilotUsage({
    required this.day,
    required this.promptTokens,
    required this.outputTokens,
  });

  static String today() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  static CopilotUsage empty() =>
      CopilotUsage(day: today(), promptTokens: 0, outputTokens: 0);

  /// Anything unparseable resets the counters rather than throwing — a
  /// corrupt usage record must not brick Copilot.
  static CopilotUsage decode(String raw) {
    final parts = raw.split('|');
    if (parts.length != 3) return empty();
    final p = int.tryParse(parts[1]), o = int.tryParse(parts[2]);
    if (p == null || o == null) return empty();
    return CopilotUsage(day: parts[0], promptTokens: p, outputTokens: o);
  }

  String encode() => '$day|$promptTokens|$outputTokens';

  /// Rolls over to a fresh record when the local date has changed.
  CopilotUsage forToday() => day == today() ? this : empty();

  CopilotUsage plus({required int prompt, required int output}) => CopilotUsage(
        day: day,
        promptTokens: promptTokens + prompt,
        outputTokens: outputTokens + output,
      );
}
