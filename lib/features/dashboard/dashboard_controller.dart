import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/di/service_locator.dart';
import '../../core/ssh/ssh_client.dart';
import '../../core/ssh/ssh_credentials.dart';
import '../../core/ssh/ssh_exception.dart';
import '../../data/repositories/credentials_repository.dart';
import '../../services/lg_command_service.dart';
import '../../services/lg_kml_controller.dart';
import '../../services/lg_orbit_controller.dart';

class DashboardController extends ChangeNotifier with WidgetsBindingObserver {
  final LGSSHClient _sshClient = sl<LGSSHClient>();
  final LGCommandService _commandService = sl<LGCommandService>();
  final LGKMLController _kmlController = sl<LGKMLController>();
  final LGOrbitController _orbit = sl<LGOrbitController>();
  final CredentialsRepository _credsRepo = sl<CredentialsRepository>();

  bool isBusy = false;

  bool isAutoConnecting = false;

  String? lastActionLabel;
  DateTime? lastActionTime;

  String? lastError;

  SSHConnectionState get connectionState => _sshClient.state;
  bool get isConnected => _sshClient.isConnected;
  SSHCredentials? get credentials => _sshClient.credentials;

  late final StreamSubscription<SSHConnectionState> _stateSub;
  bool _disposed = false;

  DashboardController() {
    _stateSub = _sshClient.stateStream.listen((_) {
      _notify();
    });
    WidgetsBinding.instance.addObserver(this);
    _tryAutoConnect();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android drops idle sockets while the app is backgrounded — quietly
    // redial on resume so the app is connected whenever the user looks.
    if (state == AppLifecycleState.resumed &&
        !isConnected &&
        !isBusy &&
        !isAutoConnecting) {
      _tryAutoConnect();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _stateSub.cancel();
    super.dispose();
  }

  /// In-flight SSH work (auto-connect, actions) can outlive this controller —
  /// e.g. the Activity is recreated mid-connect. Notifying after dispose
  /// throws, so every internal notify routes through this guard.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _tryAutoConnect() async {
    isAutoConnecting = true;
    _notify();

    try {
      final creds = await _credsRepo.load();
      if (creds != null && creds.host.isNotEmpty) {
        await _sshClient.connect(creds);
      }
    } on LGSSHException catch (e) {
      // Was swallowed entirely, so a failed auto-connect showed a bare
      // "Disconnected" with no reason and no Copilot diagnose button — the
      // one moment a rig operator most needs to be told what went wrong.
      lastError = e.message;
    } catch (e) {
      lastError = 'Unexpected error: $e';
    } finally {
      isAutoConnecting = false;
      _notify();
    }
  }

  Future<void> connect({SSHCredentials? creds}) async {
    if (isBusy) return;

    _setBusy(true);
    lastError = null;

    try {
      final resolved = creds ?? await _credsRepo.load();
      if (resolved == null || resolved.host.isEmpty) {
        lastError =
            'No credentials saved. Open Settings (⚙) to configure the LG connection.';
        return;
      }
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

  Future<void> kmlTest() =>
      _runAction('KML Test', () => kmlSanityCheck(_kmlController, _orbit));

  bool get isOrbitPlaying => _orbit.isOrbitPlaying;

  /// Deliberately not routed through [_runAction]. That helper bails when the
  /// rig is unreachable or another action is in flight — but the orbit timer
  /// is local to this app, and a rig that just dropped mid-orbit is exactly
  /// when a runaway orbit most needs stopping. Cancelling the timer must
  /// always succeed; only the final camera write can fail.
  Future<void> stopOrbit() async {
    try {
      await _orbit.orbitStop();
      lastActionLabel = 'Stop Orbit';
      lastActionTime = DateTime.now();
    } on LGSSHException catch (e) {
      lastError = e.message;
    } catch (e) {
      lastError = 'Unexpected error: $e';
    }
    _notify();
  }

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
    _notify();
  }

}
