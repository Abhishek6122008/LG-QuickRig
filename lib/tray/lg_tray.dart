import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

import '../app.dart';
import '../core/di/service_locator.dart';
import '../core/ssh/ssh_client.dart';
import '../features/lg_commands/camera_action_dialog.dart';
import '../features/lg_commands/image_overlay_dialog.dart';
import '../services/lg_command_service.dart';
import '../services/lg_kml_controller.dart';
import '../services/lg_orbit_controller.dart';

class LGTray with TrayListener {
  LGCommandService get _lg => sl<LGCommandService>();
  LGKMLController get _kml => sl<LGKMLController>();
  LGOrbitController get _orbit => sl<LGOrbitController>();
  LGSSHClient get _ssh => sl<LGSSHClient>();

  Future<void> init() async {
    // tray_manager only dispatches menu onClick callbacks while at least one
    // TrayListener is registered — without this, every menu click is a no-op.
    trayManager.addListener(this);

    // Menu and state listener come FIRST: if a cosmetic call below throws
    // (tooltips aren't supported on every Linux tray), the menu must already
    // be attached or every click is dead and the icon freezes on its first
    // state forever.
    await _buildMenu();
    _ssh.stateStream.listen(_applyState);

    // The state stream only fires on explicit connects/disconnects and
    // detected remote closes — a periodic ping (same 5-min cadence as the
    // Android status widget) surfaces connections that died silently.
    Timer.periodic(const Duration(minutes: 5), (_) async {
      if (!_ssh.isConnected) return;
      try {
        await _lg.execute('echo ok');
      } catch (_) {
        // The failed command already flipped the state stream to disconnected.
      }
    });

    await _applyState(_ssh.state);
  }

  Future<void> _applyState(SSHConnectionState state) async {
    final icon = switch (state) {
      SSHConnectionState.connected => 'tray_icon_online.png',
      SSHConnectionState.disconnected => 'tray_icon_offline.png',
      _ => 'tray_icon.png', // connecting/disconnecting — neutral
    };
    final host = _ssh.credentials?.host;
    final label = switch (state) {
      SSHConnectionState.connected => 'Connected — $host',
      SSHConnectionState.disconnected => 'Disconnected',
      _ => 'Connecting…',
    };
    try {
      await trayManager.setIcon(_assetPath(icon));
      await trayManager.setToolTip('LG QuickRig — $label');
    } catch (_) {
      // Icon/tooltip are cosmetic — never let them break the menu.
    }
  }

  /// `flutter run` serves assets relative to the project dir; a bundled
  /// release keeps them under `<exe>/data/flutter_assets`. The tray needs a
  /// path that exists on disk either way.
  String _assetPath(String name) {
    final local = File('assets/$name');
    // Absolute path either way — appindicator resolves relative paths
    // against the icon theme, not the working directory.
    if (local.existsSync()) return local.absolute.path;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    return '$exeDir/data/flutter_assets/assets/$name';
  }

  Future<void> _buildMenu() async {
    final menu = Menu(
      items: [
        MenuItem(
          key: 'flyto',
          label: 'Fly To…',
          onClick: (_) => _openDialog('flyto'),
        ),
        MenuItem(
          key: 'orbit',
          label: 'Orbit…',
          onClick: (_) => _openDialog('orbit'),
        ),
        MenuItem(
          key: 'overlay',
          label: 'Overlay…',
          onClick: (_) => _openDialog('overlay'),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'kmltest',
          label: 'KML Test',
          onClick: (_) => _run(_kmlTest),
        ),
        MenuItem(
          key: 'clean',
          label: 'Clean KML',
          onClick: (_) => _run(_kml.cleanKML),
        ),
        MenuItem(
          key: 'relaunch',
          label: 'Restart services',
          onClick: (_) => _run(_lg.restartServices),
        ),
        MenuItem(key: 'sync', label: 'Sync', onClick: (_) => _run(_lg.sync)),
        MenuItem(
          key: 'blank',
          label: 'Blank screens',
          onClick: (_) => _run(_lg.blankScreens),
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'reboot',
          label: 'Reboot rig',
          onClick: (_) => _run(_lg.reboot),
        ),
        MenuItem(
          key: 'shutdown',
          label: 'Shutdown rig',
          onClick: (_) => _run(_lg.shutdown),
        ),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit', onClick: (_) => exit(0)),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  /// Same sanity check as the dashboard's KML Test tile.
  Future<void> _kmlTest() async {
    await _kml.dropPin(lat: 27.1751, lng: 78.0421, name: 'QuickRig KML Test');
    await _orbit.flyTo(lat: 27.1751, lng: 78.0421, range: 5000);
  }

  /// Camera actions need text input, so they open the app's existing dialogs.
  /// ponytail: doesn't raise a minimized window — add window_manager if that
  /// turns out to annoy in daily use.
  Future<void> _openDialog(String action) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    if (action == 'overlay') {
      await ImageOverlayDialog.show(ctx);
    } else {
      await CameraActionDialog.show(ctx, action);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Not connected / SSH failure — a tray has no surface to report it on;
      // the icon already shows the connection state.
    }
  }
}
