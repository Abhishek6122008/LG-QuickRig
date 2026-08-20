import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';

import '../constants.dart';
import 'ssh_credentials.dart';
import 'ssh_exception.dart';

enum SSHConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

class LGSSHClient {
  SSHClient? _rawClient;
  SSHCredentials? _credentials;

  final _stateController = StreamController<SSHConnectionState>.broadcast();
  SSHConnectionState _state = SSHConnectionState.disconnected;

  /// Bumped by every [connect]; lets a superseded attempt detect that a newer
  /// one has taken over.
  int _connectGeneration = 0;

  bool _disposed = false;

  Stream<SSHConnectionState> get stateStream => _stateController.stream;
  SSHConnectionState get state => _state;
  bool get isConnected => _state == SSHConnectionState.connected;
  SSHCredentials? get credentials => _credentials;

  void _setState(SSHConnectionState s) {
    _state = s;
    // _watchForRemoteDisconnect's callback can land after dispose() has
    // closed the controller, and adding to a closed StreamController throws.
    if (!_disposed) _stateController.add(s);
  }

  Future<void> connect(
    SSHCredentials credentials, {
    int maxRetries = LGDefaults.maxRetries,
    Duration retryDelay = LGDefaults.retryDelay,
    Duration connectTimeout = LGDefaults.connectTimeout,
  }) async {
    // A connect carrying *different* credentials must never be swallowed.
    // Auto-connect retries for up to ~36s; if the user opened Settings during
    // that window and fixed a wrong password, the old code returned here —
    // before `_credentials` was reassigned — and they watched the rig fail to
    // connect on the password they had just corrected.
    final sameCredentials = _credentials == credentials;
    if (sameCredentials &&
        (_state == SSHConnectionState.connecting ||
            _state == SSHConnectionState.connected)) {
      return;
    }

    // Every attempt claims a generation. A later connect bumps it, and any
    // earlier attempt still in its retry loop sees the mismatch and bows out
    // instead of racing the newer one for _rawClient and the state stream.
    final generation = ++_connectGeneration;

    if (_rawClient != null) await _cleanupRawClient();

    _setState(SSHConnectionState.connecting);
    _credentials = credentials;

    Exception? lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (generation != _connectGeneration) return;
      try {
        final socket = await SSHSocket.connect(
          credentials.host,
          credentials.port,
          timeout: connectTimeout,
        );

        final client = SSHClient(
          socket,
          username: credentials.username,
          onPasswordRequest: () => credentials.password,
        );

        await client.authenticated;

        if (generation != _connectGeneration) {
          client.close();
          return;
        }

        _rawClient = client;
        _watchForRemoteDisconnect();
        _setState(SSHConnectionState.connected);
        return;
      } on SSHAuthAbortError catch (e) {
        if (generation != _connectGeneration) return;
        await _cleanupRawClient();
        _setState(SSHConnectionState.disconnected);
        throw LGSSHException('Authentication failed: $e');
      } on Exception catch (e) {
        if (generation != _connectGeneration) return;
        lastError = e;
        await _cleanupRawClient();
        if (attempt < maxRetries) await Future.delayed(retryDelay);
      }
    }

    if (generation != _connectGeneration) return;
    _setState(SSHConnectionState.disconnected);
    throw LGSSHException(
      'Failed to connect after $maxRetries attempt(s). Last error: $lastError',
    );
  }

  Future<void> disconnect() async {
    if (_state == SSHConnectionState.disconnected) return;
    _setState(SSHConnectionState.disconnecting);
    await _cleanupRawClient();
    _setState(SSHConnectionState.disconnected);
  }

  Future<void> _ensureAlive() async {
    if (_rawClient != null && !_rawClient!.isClosed) return;
    _rawClient = null;
    if (_state == SSHConnectionState.connected) {
      _setState(SSHConnectionState.disconnected);
    }
    final creds = _credentials;
    if (creds == null) throw const LGSSHException('Not connected to the LG node.');
    await connect(creds);
  }

  Future<String> executeCommand(
    String command, {
    Duration timeout = LGDefaults.commandTimeout,
  }) async {
    await _ensureAlive();

    late final SSHSession session;
    try {
      session = await _rawClient!.execute(command);
    } catch (e) {
      throw LGSSHException('Failed to open command session: $e');
    }

    final stdoutBuf = StringBuffer();
    final stderrBuf = StringBuffer();

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
      session.close();
      // These two drains outlive the timeout. Left unhandled, an error on
      // either surfaces as an unhandled zone error long after this call has
      // already thrown something useful.
      unawaited(stdoutDone.catchError((_) {}));
      unawaited(stderrDone.catchError((_) {}));
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

  Future<void> uploadBytes(List<int> bytes, String remotePath) async {
    await _ensureAlive();
    final sftp = await _rawClient!.sftp();
    final file = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create |
          SftpFileOpenMode.write |
          SftpFileOpenMode.truncate,
    );
    try {
      await file.write(Stream.value(Uint8List.fromList(bytes)));
    } finally {
      await file.close();
      sftp.close();
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    // Was fire-and-forget, so the socket could still be closing when the
    // controller went away.
    await _cleanupRawClient();
    await _stateController.close();
  }

  void _watchForRemoteDisconnect() {
    _rawClient?.done.then(
      (_) => _onRemoteClose(),
      onError: (_) => _onRemoteClose(),
    );
  }

  void _onRemoteClose() {
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
