import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../app.dart';
import '../core/di/service_locator.dart';
import '../core/ssh/ssh_client.dart';
import '../features/lg_commands/camera_action_dialog.dart';
import '../features/lg_commands/image_overlay_dialog.dart';
import '../services/lg_command_service.dart';
import '../services/lg_kml_controller.dart';
import '../services/lg_orbit_controller.dart';

class LGTray with TrayListener, WindowListener {
  LGCommandService get _lg => sl<LGCommandService>();
  LGKMLController get _kml => sl<LGKMLController>();
  LGOrbitController get _orbit => sl<LGOrbitController>();
  LGSSHClient get _ssh => sl<LGSSHClient>();

  Future<void> init() async {
    // tray_manager only dispatches menu onClick callbacks while at least one
    // TrayListener is registered — without this, every menu click is a no-op.
    trayManager.addListener(this);

    // Menu and state listener come FIRST: if a call below throws (tooltips
    // aren't supported on every Linux tray, and there may be no window
    // manager at all), the menu must already be attached or every click is
    // dead and the icon freezes on its first state forever.
    await _buildMenu();
    _stateSub = _ssh.stateStream.listen(_applyState);

    // Closing the window used to take the process — and the tray with it —
    // down, because it is a plain GtkApplicationWindow. Hide it instead; the
    // tray's own Quit is the way out.
    try {
      windowManager.addListener(this);
      await windowManager.setPreventClose(true);
    } catch (_) {
      // No window manager here — the menu above still works, and closing the
      // window just ends the process as it always did.
    }

    // The state stream only fires on explicit connects/disconnects and
    // detected remote closes — a periodic ping (same 5-min cadence as the
    // Android status widget) surfaces connections that died silently.
    _pingTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (!_ssh.isConnected) return;
      try {
        await _lg.execute('echo ok');
      } catch (_) {
        // The failed command already flipped the state stream to disconnected.
      }
    });

    await _applyState(_ssh.state);
  }

  Timer? _pingTimer;
  StreamSubscription<SSHConnectionState>? _stateSub;

  Future<void> dispose() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    await _stateSub?.cancel();
    trayManager.removeListener(this);
    windowManager.removeListener(this);
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
          key: 'show',
          label: 'Show window',
          onClick: (_) => _showWindow(),
        ),
        MenuItem.separator(),
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
          key: 'orbitstop',
          label: 'Stop orbit',
          onClick: (_) => _run(_orbit.orbitStop),
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
          label: 'Relaunch',
          onClick: (_) => _run(_lg.relaunch),
        ),
        MenuItem(key: 'sync', label: 'Sync', onClick: (_) => _run(_lg.sync)),
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
        MenuItem(key: 'quit', label: 'Quit', onClick: (_) => _quit()),
      ],
    );
    await trayManager.setContextMenu(menu);
  }

  /// Was a bare `exit(0)`, which left the SSH session to be reaped by the
  /// remote sshd instead of closed.
  Future<void> _quit() async {
    await dispose();
    try {
      await _orbit.orbitStop();
      await _ssh.dispose();
    } catch (_) {
      // Shutting down anyway.
    }
    exit(0);
  }

  Future<void> _kmlTest() => kmlSanityCheck(_kml, _orbit);

  /// Raises the window so the tray icon has somewhere to put a dialog. The
  /// tray_manager Linux backend never emits mouse events, so this menu item
  /// is the only way to get the window back once it is hidden.
  Future<void> _showWindow() async {
    try {
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {
      // No window manager (headless test run) — the dialogs below still work.
    }
  }

  /// One dialog at a time. Each click awaits its own showDialog, so three
  /// clicks used to stack three modal barriers on the same navigator.
  bool _dialogOpen = false;

  /// Camera actions need text input, so they open the app's existing dialogs.
  /// The window is raised first: pushing a route onto a hidden or minimised
  /// window is what made these menu items look like they did nothing.
  Future<void> _openDialog(String action) async {
    if (_dialogOpen) return;
    await _showWindow();

    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    _dialogOpen = true;
    try {
      if (action == 'overlay') {
        await ImageOverlayDialog.show(ctx);
      } else {
        await CameraActionDialog.show(ctx, action);
      }
    } finally {
      _dialogOpen = false;
    }
  }

  @override
  void onWindowClose() {
    windowManager.hide();
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
