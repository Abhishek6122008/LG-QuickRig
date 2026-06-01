import 'package:flutter/foundation.dart';

import '../../core/di/service_locator.dart';
import '../../core/ssh/ssh_client.dart';
import '../../core/ssh/ssh_exception.dart';
import '../../services/lg_command_service.dart';

class LGCommandEntry {
  final DateTime timestamp;
  final String text;
  final bool isError;

  LGCommandEntry(this.text, {this.isError = false}) : timestamp = DateTime.now();

  String get label => isError ? '[ERR]' : '[OUT]';
}

/// Drives [LGCommandsScreen].
///
/// Uses the shared [LGSSHClient] and [LGCommandService] singletons — does NOT
/// own them and must NOT call [LGSSHClient.dispose].
class LGCommandsController extends ChangeNotifier {
  final LGSSHClient _sshClient = sl<LGSSHClient>();
  final LGCommandService _commandService = sl<LGCommandService>();

  final List<LGCommandEntry> log = [];
  bool isBusy = false;
  String? activeCommand;

  SSHConnectionState get connectionState => _sshClient.state;
  bool get isConnected => _sshClient.isConnected;

  LGCommandsController() {
    _sshClient.stateStream.listen((_) => notifyListeners());
  }

  Future<void> reboot() => _run('Reboot', _commandService.reboot);
  Future<void> shutdown() => _run('Shutdown', _commandService.shutdown);
  Future<void> sync() => _run('Sync', _commandService.sync);
  Future<void> restartSlaves() => _run('Restart Services', _commandService.restartServices);
  Future<void> blankScreens() => _run('Blank Screens', _commandService.blankScreens);

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  Future<void> _run(String label, Future<void> Function() action) async {
    if (!isConnected || isBusy) return;
    isBusy = true;
    activeCommand = label;
    _append('Running: $label…');

    try {
      await action();
      _append('$label completed.');
    } on LGSSHException catch (e) {
      _append(e.message, isError: true);
    } catch (e) {
      _append('Unexpected error: $e', isError: true);
    } finally {
      isBusy = false;
      activeCommand = null;
      notifyListeners();
    }
  }

  void _append(String text, {bool isError = false}) {
    log.add(LGCommandEntry(text, isError: isError));
    notifyListeners();
  }
}
