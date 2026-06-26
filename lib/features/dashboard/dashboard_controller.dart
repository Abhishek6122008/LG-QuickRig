import 'package:flutter/foundation.dart';

import '../../core/di/service_locator.dart';
import '../../core/ssh/ssh_client.dart';
import '../../core/ssh/ssh_credentials.dart';
import '../../core/ssh/ssh_exception.dart';
import '../../data/repositories/credentials_repository.dart';
import '../../services/lg_command_service.dart';
import '../../services/lg_kml_controller.dart';

class DashboardController extends ChangeNotifier {
  final LGSSHClient _sshClient = sl<LGSSHClient>();
  final LGCommandService _commandService = sl<LGCommandService>();
  final LGKMLController _kmlController = sl<LGKMLController>();
  final CredentialsRepository _credsRepo = sl<CredentialsRepository>();

  bool isBusy = false;

  bool isAutoConnecting = false;

  String? lastActionLabel;
  DateTime? lastActionTime;

  String? lastError;

  SSHConnectionState get connectionState => _sshClient.state;
  bool get isConnected => _sshClient.isConnected;
  SSHCredentials? get credentials => _sshClient.credentials;

  DashboardController() {

    _sshClient.stateStream.listen((_) {
      notifyListeners();
    });
    _tryAutoConnect();
  }

  Future<void> _tryAutoConnect() async {
    isAutoConnecting = true;
    notifyListeners();

    try {
      final creds = await _credsRepo.load();
      if (creds != null && creds.host.isNotEmpty) {
        await _sshClient.connect(creds);
      }
    } catch (_) {} finally {
      isAutoConnecting = false;
      notifyListeners();
    }
  }

  Future<void> connect({SSHCredentials? creds}) async {
    if (isBusy) return;

    SSHCredentials? resolved = creds;
    if (resolved == null) {
      resolved = await _credsRepo.load();
      if (resolved == null || resolved.host.isEmpty) {
        lastError =
            'No credentials saved. Open Settings (⚙) to configure the LG connection.';
        notifyListeners();
        return;
      }
    }

    _setBusy(true);
    lastError = null;

    try {
      if (_sshClient.isConnected) await _sshClient.disconnect();
      await _sshClient.connect(resolved);
    } on LGSSHException catch (e) {
      lastError = e.message;
    } catch (e) {
      lastError = 'Unexpected error: $e';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> disconnect() async {
    if (isBusy) return;
    _setBusy(true);
    try {
      await _sshClient.disconnect();
      lastError = null;
    } catch (e) {
      lastError = 'Disconnect error: $e';
    } finally {
      _setBusy(false);
    }
  }

  Future<void> reboot() =>
      _runAction('Reboot', _commandService.reboot);

  Future<void> shutdown() =>
      _runAction('Shutdown', _commandService.shutdown);

  Future<void> restartServices() =>
      _runAction('Restart Services', _commandService.restartServices);

  Future<void> sync() =>
      _runAction('Sync', _commandService.sync);

  Future<void> blankScreens() =>
      _runAction('Blank Screens', _commandService.blankScreens);

  Future<void> cleanKML() =>
      _runAction('Clean KML', _kmlController.cleanKML);

  Future<void> _runAction(
    String label,
    Future<void> Function() action,
  ) async {
    if (!isConnected || isBusy) return;

    _setBusy(true);
    lastError = null;

    try {
      await action();
      lastActionLabel = label;
      lastActionTime = DateTime.now();
    } on LGSSHException catch (e) {
      lastError = e.message;
    } catch (e) {
      lastError = 'Unexpected error: $e';
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    isBusy = value;
    notifyListeners();
  }

}
