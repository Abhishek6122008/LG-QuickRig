import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'tray/lg_tray.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await setupServiceLocator();

  if (Platform.isLinux) {
    try {
      await windowManager.ensureInitialized();
    } catch (_) {
      // Non-desktop shell — carry on without window control.
    }
  }

  runApp(const LGQuickRigApp());

  // After runApp, not before: init() awaits three method-channel round trips,
  // and while they ran there was no widget tree, so navigatorKey.currentContext
  // was null and any tray click landing in that window silently did nothing.
  if (Platform.isLinux) {
    try {
      await LGTray().init();
    } catch (_) {
      // No system tray on this desktop (e.g. stock GNOME) — run windowed only.
    }
  }
}
