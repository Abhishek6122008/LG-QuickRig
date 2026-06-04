import 'package:flutter/foundation.dart';

import '../../core/di/service_locator.dart';
import '../../core/ssh/ssh_client.dart';
import '../../core/ssh/ssh_exception.dart';
import '../../services/lg_command_service.dart';
import '../../services/lg_orbit_controller.dart';

class LGCommandEntry {
  final DateTime timestamp;
  final String text;
  final bool isError;

  LGCommandEntry(this.text, {this.isError = false}) : timestamp = DateTime.now();

  String get label => isError ? '[ERR]' : '[OUT]';
}

/// Drives [LGCommandsScreen].
///
/// Uses the shared [LGSSHClient], [LGCommandService], and [LGOrbitController]
/// singletons — does NOT own them and must NOT call [LGSSHClient.dispose].
class LGCommandsController extends ChangeNotifier {
  final LGSSHClient _sshClient = sl<LGSSHClient>();
  final LGCommandService _commandService = sl<LGCommandService>();
  final LGOrbitController _orbitController = sl<LGOrbitController>();

  final List<LGCommandEntry> log = [];
  bool isBusy = false;
  String? activeCommand;

  SSHConnectionState get connectionState => _sshClient.state;
  bool get isConnected => _sshClient.isConnected;
  bool get isOrbitPlaying => _orbitController.isOrbitPlaying;

  LGCommandsController() {
    _sshClient.stateStream.listen((_) => notifyListeners());
  }

  // ---------------------------------------------------------------------------
  // System commands
  // ---------------------------------------------------------------------------

  Future<void> reboot() => _run('Reboot', _commandService.reboot);
  Future<void> shutdown() => _run('Shutdown', _commandService.shutdown);
  Future<void> sync() => _run('Sync', _commandService.sync);
  Future<void> restartSlaves() => _run('Restart Services', _commandService.restartServices);
  Future<void> blankScreens() => _run('Blank Screens', _commandService.blankScreens);

  // ---------------------------------------------------------------------------
  // Navigation commands
  // ---------------------------------------------------------------------------

  Future<void> moveUp() => _run('Move Up', _commandService.moveUp);
  Future<void> moveDown() => _run('Move Down', _commandService.moveDown);
  Future<void> rotateLeft() => _run('Rotate Left', _commandService.rotateLeft);
  Future<void> rotateRight() => _run('Rotate Right', _commandService.rotateRight);

  Future<void> flyTo({
    required double lat,
    required double lng,
    double range = 10000,
    double tilt = 0,
  }) => _run(
        'Fly To',
        () => _orbitController.flyTo(lat: lat, lng: lng, range: range, tilt: tilt),
      );

  // ---------------------------------------------------------------------------
  // Orbit
  // ---------------------------------------------------------------------------

  Future<void> orbitPlay({
    required double lat,
    required double lng,
    required double range,
    double tilt = 45,
  }) async {
    if (!isConnected || _orbitController.isOrbitPlaying) return;
    _append('Starting orbit at ($lat, $lng)…');
    notifyListeners();

    final started = await _orbitController.orbitPlay(
      lat: lat,
      lng: lng,
      range: range,
      tilt: tilt,
      onStop: () {
        _append('Orbit completed.');
        notifyListeners();
      },
    );

    if (!started) _append('Orbit already running.', isError: true);
    notifyListeners();
  }

  Future<void> orbitStop() async {
    if (!_orbitController.isOrbitPlaying) return;
    await _orbitController.orbitStop();
    _append('Orbit stopped.');
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Log
  // ---------------------------------------------------------------------------

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

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
