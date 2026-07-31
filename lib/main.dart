import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'tray/lg_tray.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await setupServiceLocator();

  if (Platform.isLinux) {
    try {
      await LGTray().init();
    } catch (_) {
      // No system tray on this desktop (e.g. stock GNOME) — run windowed only.
    }
  }

  runApp(const LGQuickRigApp());
}
