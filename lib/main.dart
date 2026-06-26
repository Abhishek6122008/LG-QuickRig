import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/service_locator.dart';
import 'tray/lg_tray.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await ServiceLocator.setup();

  if (Platform.isLinux) await LGTray().init();

  runApp(const LGQuickRigApp());
}
