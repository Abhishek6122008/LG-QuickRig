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

  // Guards the navigation the integration test drives (which only runs on a
  // Linux/Android device in CI, so it cannot fail fast here otherwise).
  testWidgets('the shell navigates between Rig, Camera and Settings',
      (tester) async {
    await tester.pumpWidget(const LGQuickRigApp());
    await tester.pumpAndSettle();

    // Each destination label must be unambiguous — the tests tap by text.
    expect(find.text('Rig'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Rig is the landing tab.
    expect(find.text('Quick Actions'), findsOneWidget);

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();
    expect(find.text('Fly To'), findsOneWidget);
    expect(find.text('Stop Orbit'), findsOneWidget);
    expect(find.text('Quick Actions'), findsNothing);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Host / IP address'), findsOneWidget);

    await tester.tap(find.text('Rig'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Actions'), findsOneWidget);
  });

  // Stop Orbit is the one tile that must work with the rig unreachable: the
  // orbit timer is local, and a rig that just dropped is when a runaway orbit
  // most needs stopping.
  testWidgets('Stop Orbit stays enabled while disconnected', (tester) async {
    await tester.pumpWidget(const LGQuickRigApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();

    expect(find.text('Disconnected'), findsOneWidget);

    InkWell inkWellFor(String label) => tester.widget<InkWell>(
          find.ancestor(of: find.text(label), matching: find.byType(InkWell)),
        );

    expect(inkWellFor('Fly To').onTap, isNull, reason: 'needs the rig');
    expect(inkWellFor('Stop Orbit').onTap, isNotNull);
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
