import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lg_quickrig/app.dart';

import '../test/fakes.dart';

/// The one flow a rig operator actually performs on a fresh install:
/// open Settings, type the rig's credentials, save, connect, fire an action.
/// It runs the real widgets, the real DashboardController and the real
/// KML/orbit controllers — only the SSH socket and the secure storage are
/// faked, so a break anywhere in that chain fails here.
///
/// Deliberately does NOT call main(): that would pull in the Linux system
/// tray and the real keyring, neither of which exists on a CI runner.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('configure, connect and drive the rig end to end',
      (tester) async {
    final rig = await useFakeRig();

    await tester.pumpWidget(const LGQuickRigApp());
    await tester.pumpAndSettle();

    expect(find.text('Disconnected'), findsOneWidget);

    // Settings → fill in the rig.
    await tester.tap(find.byTooltip('SSH Settings'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Host / IP address'), '10.1.2.3');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'), 'lg-secret');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Node count'), '3');

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save & Connect'));
    await tester.pumpAndSettle();

    // Back on the dashboard, connected with what we typed.
    expect(rig.creds.creds!.host, '10.1.2.3');
    expect(rig.creds.creds!.password, 'lg-secret');
    expect(find.text('Connected'), findsOneWidget);
    expect(find.textContaining('lg@10.1.2.3'), findsOneWidget);

    // Fire a rig action and check what actually reached the master's shell.
    final cleanKml = find.text('Clean KML');
    await tester.ensureVisible(cleanKml); // the grid sits below the fold
    await tester.pumpAndSettle();
    await tester.tap(cleanKml);
    await tester.pumpAndSettle();

    expect(rig.ssh.sent('rm -f /var/www/html/kml/lgquickrig_*.kml'), isTrue);
    expect(rig.ssh.sent("sed -i '/lgquickrig/d'"), isTrue);
    expect(find.textContaining('Clean KML'), findsWidgets);
  });
}
