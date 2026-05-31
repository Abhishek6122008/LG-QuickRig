import 'package:flutter/material.dart';

import 'app.dart';
import 'core/di/service_locator.dart';

void main() async {
  // Required before any plugin or async work in main().
  WidgetsFlutterBinding.ensureInitialized();

  // Register all singletons (SSH client, repositories, services).
  await ServiceLocator.setup();

  runApp(const LGQuickRigApp());
}
