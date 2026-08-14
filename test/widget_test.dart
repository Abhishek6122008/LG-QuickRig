import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lg_quickrig/app.dart';
import 'package:lg_quickrig/core/ssh/ssh_credentials.dart';
import 'package:lg_quickrig/core/ssh/ssh_exception.dart';
import 'package:lg_quickrig/features/settings/settings_screen.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSSHClient ssh;
  late FakeCredentialsRepository creds;

  const savedCreds = SSHCredentials(
    host: '192.168.2.2',
    port: 22,
    username: 'lg',
    password: 'lg',
  );

  setUp(() async {
    final rig = await useFakeRig();
    ssh = rig.ssh;
    creds = rig.creds;
  });

  testWidgets('Dashboard renders in disconnected state on first launch',
      (tester) async {
    await tester.pumpWidget(const LGQuickRigApp());

    // Let the auto-connect attempt start and resolve (no saved credentials).
    await tester.pump();
    await tester.pump();

    expect(find.text('LG QuickRig'), findsWidgets);
    expect(find.text('Disconnected'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('Settings screen renders form fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

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

  // Week 6: a failed connection is the moment a rig operator most needs help,
  // so the banner offers to hand the real SSH error to Copilot.
  testWidgets('a failed connection offers a Copilot diagnosis',
      (tester) async {
    creds.creds = savedCreds;
    ssh.connectError = const LGSSHException('Authentication failed');

    await tester.pumpWidget(const LGQuickRigApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text('Authentication failed'), findsOneWidget);
    expect(find.byTooltip('Diagnose with Copilot'), findsOneWidget);
  });

  // The diagnosis prompt must not fire a request (and spend credits) on a
  // Copilot the user has never switched on.
  testWidgets('the diagnosis prompt does not auto-send while Copilot is off',
      (tester) async {
    creds.creds = savedCreds;
    creds.copilotEnabled = false;
    ssh.connectError = const LGSSHException('Connection refused');

    await tester.pumpWidget(const LGQuickRigApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Diagnose with Copilot'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Copilot is turned off'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
  });

  testWidgets('an enabled Copilot with no key asks for one first',
      (tester) async {
    creds.creds = savedCreds;
    creds.copilotEnabled = true;
    creds.geminiKey = null;
    ssh.connectError = const LGSSHException('No route to host');

    await tester.pumpWidget(const LGQuickRigApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Diagnose with Copilot'));
    await tester.pumpAndSettle();

    expect(find.text('Gemini API key'), findsOneWidget);
  });
}
