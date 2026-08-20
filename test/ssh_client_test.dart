import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lg_quickrig/core/ssh/ssh_client.dart';
import 'package:lg_quickrig/core/ssh/ssh_credentials.dart';
import 'package:lg_quickrig/core/ssh/ssh_exception.dart';

/// The real [LGSSHClient] — every other test swaps in FakeSSHClient, which
/// left this file (the retry loop, the connect guard, the state stream)
/// without a single line of execution coverage.
///
/// These drive it against a real TCP port with nothing behind it: enough to
/// exercise connect failure, retries and the supersede path without needing
/// an SSH server. The authenticated path still needs a real rig.
void main() {
  late LGSSHClient client;
  late int deadPort;

  setUp(() async {
    client = LGSSHClient();
    // Bind and immediately release, so the port is real but refuses.
    final probe = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    deadPort = probe.port;
    await probe.close();
  });

  tearDown(() async => client.dispose());

  SSHCredentials creds(String user) => SSHCredentials(
        host: '127.0.0.1',
        port: deadPort,
        username: user,
        password: user,
      );

  test('starts disconnected', () {
    expect(client.state, SSHConnectionState.disconnected);
    expect(client.isConnected, isFalse);
    expect(client.credentials, isNull);
  });

  test('a refused connection reports the attempt count and ends disconnected',
      () async {
    await expectLater(
      client.connect(
        creds('lg'),
        maxRetries: 2,
        retryDelay: const Duration(milliseconds: 1),
      ),
      throwsA(
        isA<LGSSHException>().having(
          (e) => e.message,
          'message',
          contains('after 2 attempt(s)'),
        ),
      ),
    );

    expect(client.state, SSHConnectionState.disconnected);
    expect(client.isConnected, isFalse);
  });

  test('the state stream reports connecting then disconnected', () async {
    final seen = <SSHConnectionState>[];
    final sub = client.stateStream.listen(seen.add);

    await client
        .connect(creds('lg'),
            maxRetries: 1, retryDelay: const Duration(milliseconds: 1))
        .catchError((_) {});

    // Broadcast events are delivered on a microtask; let the last one land.
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen, [
      SSHConnectionState.connecting,
      SSHConnectionState.disconnected,
    ]);
  });

  // Regression: connect() used to early-return whenever state was
  // `connecting`, and it did so *before* assigning _credentials. So a user who
  // fixed a wrong password in Settings while auto-connect was still retrying
  // had their correction silently dropped — the rig kept being dialled with
  // the old credentials.
  test('credentials supplied during an in-flight connect are not dropped',
      () async {
    final old = creds('old');
    final fixed = creds('fixed');

    // Long retry delay so this one is still looping when the second arrives.
    final inFlight = client.connect(
      old,
      maxRetries: 3,
      retryDelay: const Duration(milliseconds: 300),
    );

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(client.credentials, old, reason: 'first attempt should own state');

    await expectLater(
      client.connect(fixed,
          maxRetries: 1, retryDelay: const Duration(milliseconds: 1)),
      throwsA(isA<LGSSHException>()),
    );

    expect(client.credentials, fixed);

    // The superseded attempt bows out quietly rather than racing.
    await inFlight;
    expect(client.credentials, fixed);
  });

  test('a repeated connect with identical credentials is ignored', () async {
    final same = creds('lg');

    final first = client.connect(
      same,
      maxRetries: 3,
      retryDelay: const Duration(milliseconds: 300),
    );
    await Future<void>.delayed(const Duration(milliseconds: 40));

    // Returns immediately instead of starting a competing dial.
    await client.connect(same);

    expect(client.state, SSHConnectionState.connecting);

    await expectLater(first, throwsA(isA<LGSSHException>()));
  });

  test('commands before any connection fail rather than hang', () async {
    await expectLater(
      client.executeCommand('echo hi'),
      throwsA(isA<LGSSHException>()),
    );
  });

  test('dispose is safe to call twice', () async {
    await client.dispose();
    await client.dispose();
  });
}
