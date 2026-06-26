import 'dart:io';

import 'package:tray_manager/tray_manager.dart';

import '../core/di/service_locator.dart';
import '../services/lg_command_service.dart';

class LGTray {
  LGCommandService get _lg => sl<LGCommandService>();

  Future<void> init() async {
    await trayManager.setIcon('assets/tray_icon.png');
    await trayManager.setToolTip('LG QuickRig');
    await _buildMenu();
  }

  Future<void> _buildMenu() async {
    final menu = Menu(
      items: [
        MenuItem(key: 'reboot', label: 'Reboot', onClick: (_) => _lg.reboot()),
        MenuItem(key: 'sync', label: 'Sync', onClick: (_) => _lg.sync()),
        MenuItem(
          key: 'shutdown',
          label: 'Shutdown',
          onClick: (_) => _lg.shutdown(),
        ),
        MenuItem(
          key: 'blank',
          label: 'Blank screens',
          onClick: (_) => _lg.blankScreens(),
        ),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: 'Quit', onClick: (_) => exit(0)),
      ],
    );
    await trayManager.setContextMenu(menu);
  }
}
