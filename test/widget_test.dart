import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lg_quickrig/app.dart';
import 'package:lg_quickrig/core/di/service_locator.dart';
import 'package:lg_quickrig/features/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock secure storage as "empty". Without a mock the platform channel
  // never responds inside the fake-async test zone, so credential loads
  // (auto-connect, settings) would hang forever regardless of pumps.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );

  // Register singletons once for the entire test file.
  // GetIt uses a global registry, so this survives across test cases.
  setUpAll(() async {
    await setupServiceLocator();
  });

  tearDownAll(() async {
    // Reset so subsequent test runs start clean (relevant in watch mode).
    await sl.reset();
  });

  testWidgets('Dashboard renders in disconnected state on first launch',
      (tester) async {
    await tester.pumpWidget(const LGQuickRigApp());

    // Let the auto-connect attempt start and resolve (no saved credentials).
    await tester.pump();
    await tester.pump();

    // App title appears in the AppBar.
    expect(find.text('LG QuickRig'), findsWidgets);

    // Connection status badge shows "Disconnected" with no saved credentials.
    // flutter_secure_storage returns null in test environments, so no
    // auto-connect is attempted.
    expect(find.text('Disconnected'), findsOneWidget);

    // Quick actions section is present.
    expect(find.text('Quick Actions'), findsOneWidget);

    // The Connect button is visible.
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('Settings screen renders form fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    // Let the saved-credentials load resolve (secure storage is unavailable
    // in tests, so the form falls back to defaults).
    await tester.pump();
    await tester.pump();

    expect(find.text('Host / IP address'), findsOneWidget);
    expect(find.text('Port'), findsOneWidget);
    expect(find.text('Node count'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // The Copilot section pushes the button below the fold — scroll to it.
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(find.text('Save & Connect'), findsOneWidget);
  });
}
