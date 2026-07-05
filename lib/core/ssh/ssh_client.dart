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

  Stream<SSHConnectionState> get stateStream => _stateController.stream;
  SSHConnectionState get state => _state;
  bool get isConnected => _state == SSHConnectionState.connected;
  SSHCredentials? get credentials => _credentials;

  void _setState(SSHConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

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
        _watchForRemoteDisconnect();
        _setState(SSHConnectionState.connected);
        return;
      } on SSHAuthAbortError catch (e) {
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

  void dispose() {
    _cleanupRawClient();
    _stateController.close();
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
