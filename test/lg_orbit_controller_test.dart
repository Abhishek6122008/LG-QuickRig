import 'package:flutter_test/flutter_test.dart';
import 'package:lg_quickrig/core/ssh/ssh_exception.dart';
import 'package:lg_quickrig/services/lg_orbit_controller.dart';

import 'fakes.dart';

void main() {
  late FakeCommandService rig;
  late LGOrbitController orbit;

  setUp(() {
    rig = FakeCommandService();
    orbit = LGOrbitController(rig);
  });

  test('flyTo writes a flytoview LookAt to query.txt', () async {
    await orbit.flyTo(lat: 27.17, lng: 78.04, range: 1500);

    final cmd = rig.only('query.txt');
    expect(cmd, contains('flytoview=<LookAt>'));
    expect(cmd, contains('<latitude>27.17</latitude>'));
    expect(cmd, contains('<longitude>78.04</longitude>'));
    expect(cmd, contains('<range>1500.0</range>'));
  });

  group('currentTarget', () {
    test('prefers what the rig actually reports', () async {
      rig.cameraTarget = (lat: 1.0, lng: 2.0, range: 300.0);
      await orbit.flyTo(lat: 9, lng: 9);

      final target = await orbit.currentTarget();

      expect(target!.lat, 1.0);
      expect(target.lng, 2.0);
    });

    // query.txt is empty on a fresh rig, and some LG setups consume it once
    // Earth has read it. The Copilot's rig context and the KML test both lean
    // on this fallback.
    test('falls back to the last position this app flew to', () async {
      rig.cameraTarget = null;
      await orbit.flyTo(lat: 41.9, lng: 12.5, range: 800);

      final target = await orbit.currentTarget();

      expect(target!.lat, 41.9);
      expect(target.range, 800);
    });

    test('is null when neither the rig nor this app knows', () async {
      rig.cameraTarget = null;

      expect(await orbit.currentTarget(), isNull);
    });
  });

  group('orbitPlay', () {
    testWidgets('a second play is refused while one is running',
        (tester) async {
      expect(await orbit.orbitPlay(lat: 1, lng: 2), isTrue);
      expect(await orbit.orbitPlay(lat: 3, lng: 4), isFalse);

      await orbit.orbitStop();
    });

    testWidgets('each tick advances the heading around the circle',
        (tester) async {
      await orbit.orbitPlay(lat: 1, lng: 2, range: 1000);

      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      // 6 degrees per tick — one revolution every 24 seconds.
      expect(rig.commands[0], contains('<heading>0.0</heading>'));
      expect(rig.commands[1], contains('<heading>6.0</heading>'));

      await orbit.orbitStop();
    });

    // Stopping mid-orbit must leave the camera where it is, not snap back.
    testWidgets('orbitStop replays the last position it sent', (tester) async {
      await orbit.orbitPlay(lat: 1, lng: 2);
      await tester.pump(const Duration(milliseconds: 400));

      await orbit.orbitStop();

      expect(orbit.isOrbitPlaying, isFalse);
      expect(rig.commands.length, 2);
      expect(rig.commands.last, contains('<heading>0.0</heading>'));
    });

    testWidgets('stopping before any tick sends nothing', (tester) async {
      await orbit.orbitPlay(lat: 1, lng: 2);

      await orbit.orbitStop();

      expect(rig.commands, isEmpty);
    });

    // A single failed write used to end the whole orbit, silently. Step 0 is
    // heading 0, so that read as "it points north and quits".
    testWidgets('one failed write does not end the orbit', (tester) async {
      await orbit.orbitPlay(lat: 1, lng: 2, range: 1000);
      await tester.pump(const Duration(milliseconds: 400));

      rig.failWith = const LGSSHException('blip');
      await tester.pump(const Duration(milliseconds: 400));
      expect(orbit.isOrbitPlaying, isTrue);

      rig.failWith = null;
      await tester.pump(const Duration(milliseconds: 400));
      expect(orbit.isOrbitPlaying, isTrue);
      expect(rig.commands.last, contains('<heading>12.0</heading>'));

      await orbit.orbitStop();
    });

    testWidgets('three consecutive failures give up and report', (tester) async {
      String? reported;
      orbit.onOrbitError = (m) => reported = m;

      await orbit.orbitPlay(lat: 1, lng: 2, range: 1000);
      await tester.pump(const Duration(milliseconds: 400));

      rig.failWith = const LGSSHException('connection lost');
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(orbit.isOrbitPlaying, isFalse);
      expect(reported, contains('connection lost'));

      // And it really stopped — no further ticks once the rig is back.
      rig.failWith = null;
      final sentSoFar = rig.commands.length;
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.commands.length, sentSoFar);
    });

    // The whole point of the rewrite: it used to stop itself after 60 steps.
    testWidgets('keeps going well past a full revolution', (tester) async {
      await orbit.orbitPlay(lat: 1, lng: 2, range: 1000);

      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(orbit.isOrbitPlaying, isTrue);
      expect(rig.commands.length, 70);
      // Step 65 is 65 * 6 = 390 degrees, i.e. 30 into the second lap.
      expect(rig.commands[65], contains('<heading>30.0</heading>'));

      await orbit.orbitStop();
    });
  });
}
