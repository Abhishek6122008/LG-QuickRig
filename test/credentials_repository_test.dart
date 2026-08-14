import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lg_quickrig/core/ssh/ssh_credentials.dart';
import 'package:lg_quickrig/data/repositories/credentials_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // In-memory stand-in for the Keystore/Keychain/libsecret backend. Without
  // it the platform channel never answers and every read hangs.
  final store = <String, String>{};

  setUp(() {
    store.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        final args = (call.arguments as Map?) ?? const {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return store[key];
          case 'write':
            store[key!] = args['value'] as String;
            return null;
          case 'delete':
            return store.remove(key);
          case 'readAll':
            return Map<String, String>.from(store);
          case 'deleteAll':
            store.clear();
            return null;
          case 'containsKey':
            return store.containsKey(key);
        }
        return null;
      },
    );
  });

  const creds = SSHCredentials(
    host: '192.168.2.2',
    port: 22,
    username: 'lg',
    password: "lg'pass",
    nodeCount: 5,
  );

  test('credentials round-trip through storage', () async {
    final repo = CredentialsRepository();

    await repo.save(creds);
    final loaded = await repo.load();

    expect(loaded!.host, creds.host);
    expect(loaded.port, creds.port);
    expect(loaded.username, creds.username);
    expect(loaded.password, creds.password);
    expect(loaded.nodeCount, creds.nodeCount);
  });

  test('nothing saved means no credentials, not empty ones', () async {
    expect(await CredentialsRepository().load(), isNull);
  });

  test('clear removes the SSH credentials', () async {
    final repo = CredentialsRepository();
    await repo.save(creds);

    await repo.clear();

    expect(await repo.load(), isNull);
  });

  // The Gemini key is deliberately not part of SSHCredentials: it is not an
  // SSH credential and must never be mirrored to the Android widgets.
  test('the Gemini key is stored separately and survives a credentials clear',
      () async {
    final repo = CredentialsRepository();
    await repo.save(creds);
    await repo.saveGeminiKey('AIza-test');

    await repo.clear();

    expect(await repo.loadGeminiKey(), 'AIza-test');
    expect(store.keys, isNot(contains('lg_cred_host')));
  });

  // Copilot spends the user's own credits, so it must start off.
  test('Copilot is off until it is explicitly turned on', () async {
    final repo = CredentialsRepository();

    expect(await repo.loadCopilotEnabled(), isFalse);

    await repo.saveCopilotEnabled(true);
    expect(await repo.loadCopilotEnabled(), isTrue);

    await repo.saveCopilotEnabled(false);
    expect(await repo.loadCopilotEnabled(), isFalse);
  });

  test('a corrupted port or node count falls back to the defaults', () async {
    store['lg_cred_host'] = '10.0.0.1';
    store['lg_cred_port'] = 'not-a-number';
    store['lg_cred_node_count'] = '';

    final loaded = await CredentialsRepository().load();

    expect(loaded!.port, 22);
    expect(loaded.nodeCount, 3);
    expect(loaded.username, 'lg');
  });
}
