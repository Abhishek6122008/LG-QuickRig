import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';

import '../constants.dart';
import 'ssh_credentials.dart';
import 'ssh_exception.dart';

/// Lifecycle states exposed to the UI layer.
enum SSHConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// Low-level SSH transport for the Liquid Galaxy master node.
///
/// Registered as a singleton in [ServiceLocator]. Consumers (controllers,
/// services) inject it via GetIt — they must NOT call [dispose] themselves.
///
/// Usage:
/// ```dart
/// final client = sl<LGSSHClient>();
/// await client.connect(creds);
/// final out = await client.executeCommand('echo hello');
/// await client.disconnect();
/// ```
class LGSSHClient {
  SSHClient? _rawClient;
  SSHCredentials? _credentials;

  final _stateController = StreamController<SSHConnectionState>.broadcast();
  SSHConnectionState _state = SSHConnectionState.disconnected;

  /// Broadcast stream — emits on every state transition.
  Stream<SSHConnectionState> get stateStream => _stateController.stream;

  SSHConnectionState get state => _state;
  bool get isConnected => _state == SSHConnectionState.connected;

  /// The credentials used for the current (or last) connection attempt.
  SSHCredentials? get credentials => _credentials;

  void _setState(SSHConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Opens an SSH connection, retrying up to [maxRetries] times.
  ///
  /// Throws [LGSSHException] on auth failure or when all retries are exhausted.
  Future<void> connect(
    SSHCredentials credentials, {
    int maxRetries = LGDefaults.maxRetries,
    Duration retryDelay = LGDefaults.retryDelay,
    Duration connectTimeout = LGDefaults.connectTimeout,
  }) async {
    if (_state == SSHConnectionState.connecting ||
        _state == SSHConnectionState.connected) {
      return;
    }

    _setState(SSHConnectionState.connecting);
    _credentials = credentials;

    Exception? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final socket = await SSHSocket.connect(
          credentials.host,
          credentials.port,
          timeout: connectTimeout,
        );

        _rawClient = SSHClient(
          socket,
          username: credentials.username,
          onPasswordRequest: () => credentials.password,
        );

        await _rawClient!.authenticated;

        // Monitor for unexpected server-side disconnects (e.g., LG node reboot).
        _watchForRemoteDisconnect();

        _setState(SSHConnectionState.connected);
        return;
      } on SSHAuthAbortError catch (e) {
        // Wrong credentials — no point retrying.
        await _cleanupRawClient();
        _setState(SSHConnectionState.disconnected);
        throw LGSSHException('Authentication failed: $e');
      } on Exception catch (e) {
        lastError = e;
        await _cleanupRawClient();
        if (attempt < maxRetries) await Future.delayed(retryDelay);
      }
    }

    _setState(SSHConnectionState.disconnected);
    throw LGSSHException(
      'Failed to connect after $maxRetries attempt(s). Last error: $lastError',
    );
  }

  /// Gracefully closes the SSH session.
  Future<void> disconnect() async {
    if (_state == SSHConnectionState.disconnected) return;
    _setState(SSHConnectionState.disconnecting);
    await _cleanupRawClient();
    _setState(SSHConnectionState.disconnected);
  }

  /// Sends [command] to the remote shell and returns stdout (+ stderr prefix).
  ///
  /// Throws [LGSSHException] if not connected, if execution times out,
  /// or if the SSH session itself fails.
  Future<String> executeCommand(
    String command, {
    Duration timeout = LGDefaults.commandTimeout,
  }) async {
    if (!isConnected || _rawClient == null) {
      throw const LGSSHException('Not connected to the LG node.');
    }

    late final SSHSession session;
    try {
      session = await _rawClient!.execute(command);
    } catch (e) {
      throw LGSSHException('Failed to open command session: $e');
    }

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

    // Uint8List implements List<int> but the static type mismatch requires
    // an explicit cast before Utf8Decoder can bind as a StreamTransformer.
    final stdoutDone = session.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach(stdoutBuf.write);

    final stderrDone = session.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach(stderrBuf.write);

    try {
      await session.done.timeout(timeout);
      await Future.wait([stdoutDone, stderrDone]);
    } on TimeoutException {
      throw LGSSHException(
          'Command timed out after ${timeout.inSeconds}s: "$command"');
    } catch (e) {
      throw LGSSHException('Command execution error: $e');
    }

    final output = stdoutBuf.toString().trim();
    final errors = stderrBuf.toString().trim();

    if (errors.isNotEmpty && output.isEmpty) return '[stderr] $errors';
    if (errors.isNotEmpty) return '$output\n[stderr] $errors';
    return output;
  }

  /// Release resources. Called only by [ServiceLocator] on app teardown.
  void dispose() {
    _cleanupRawClient();
    _stateController.close();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Listens on the raw client's `done` future so that if the LG server drops
  /// the connection (e.g., after a reboot command) the state updates to
  /// [SSHConnectionState.disconnected] without requiring an explicit call.
  void _watchForRemoteDisconnect() {
    _rawClient?.done.then(
      (_) => _onRemoteClose(),
      onError: (_) => _onRemoteClose(),
    );
  }

  void _onRemoteClose() {
    // Only act if we think we're still connected — avoids firing during a
    // deliberate disconnect() call that already moved us to disconnecting.
    if (_state == SSHConnectionState.connected) {
      _rawClient = null;
      _setState(SSHConnectionState.disconnected);
    }
  }

  Future<void> _cleanupRawClient() async {
    try {
      _rawClient?.close();
    } catch (_) {}
    _rawClient = null;
  }
}
