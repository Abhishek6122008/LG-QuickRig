import 'package:flutter/foundation.dart';

import '../../core/di/service_locator.dart';
import '../../core/ssh/ssh_client.dart';
import '../../core/ssh/ssh_credentials.dart';
import '../../core/ssh/ssh_exception.dart';

/// A single timestamped entry in the SSH output log.
class LogEntry {
  final DateTime timestamp;
  final String text;
  final bool isError;

  LogEntry(this.text, {this.isError = false}) : timestamp = DateTime.now();

  String get label => isError ? '[ERR]' : '[OUT]';
}

/// Drives [SSHTestScreen].
///
/// Uses the shared [LGSSHClient] singleton from [sl] — any connection made
/// here is visible to [DashboardScreen] and vice versa. The controller does
/// NOT own the client and must NOT call [LGSSHClient.dispose].
class SSHTestController extends ChangeNotifier {
  final LGSSHClient _sshClient = sl<LGSSHClient>();

  final List<LogEntry> log = [];
  bool isBusy = false;

  SSHConnectionState get connectionState => _sshClient.state;
  bool get isConnected => _sshClient.isConnected;

  /// The credentials currently in use (if connected).
  SSHCredentials? get credentials => _sshClient.credentials;

  SSHTestController() {
    _sshClient.stateStream.listen((_) => notifyListeners());
  }

  // ---------------------------------------------------------------------------
  // Connection
  // ---------------------------------------------------------------------------

  Future<void> connect(SSHCredentials creds) async {
    if (isBusy) return;
    _setBusy(true);
    _appendLog(
        'Connecting to ${creds.username}@${creds.host}:${creds.port} …');

    try {
      await _sshClient.connect(creds);
      _appendLog('Connected.');
    } on LGSSHException catch (e) {
      _appendLog(e.message, isError: true);
    } catch (e) {
      _appendLog('Unexpected error: $e', isError: true);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> disconnect() async {
    if (isBusy) return;
    _setBusy(true);
    _appendLog('Disconnecting …');
    try {
      await _sshClient.disconnect();
      _appendLog('Disconnected.');
    } catch (e) {
      _appendLog('Disconnect error: $e', isError: true);
    } finally {
      _setBusy(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Command execution
  // ---------------------------------------------------------------------------

  Future<void> executeCommand(String command) async {
    final cmd = command.trim();
    if (cmd.isEmpty || isBusy) return;

    _setBusy(true);
    _appendLog('> $cmd');

    try {
      final output = await _sshClient.executeCommand(cmd);
      _appendLog(output.isEmpty ? '(no output)' : output);
    } on LGSSHException catch (e) {
      _appendLog(e.message, isError: true);
    } catch (e) {
      _appendLog('Unexpected error: $e', isError: true);
    } finally {
      _setBusy(false);
    }
  }

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _appendLog(String text, {bool isError = false}) {
    log.add(LogEntry(text, isError: isError));
    notifyListeners();
  }

  void _setBusy(bool value) {
    isBusy = value;
    notifyListeners();
  }

  // Do NOT call _sshClient.dispose() here — it is a shared singleton.
}
