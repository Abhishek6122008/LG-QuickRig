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
    // Earth has read it. Without this fallback the "use current view" buttons
    // dead-end on those rigs.
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
    testWidgets('refuses when there is nowhere to orbit', (tester) async {
      rig.cameraTarget = null;

      expect(await orbit.orbitPlay(), isFalse);
      expect(orbit.isOrbitPlaying, isFalse);
    });

    testWidgets('orbits the rig camera when given no coordinates',
        (tester) async {
      rig.cameraTarget = (lat: 48.85, lng: 2.29, range: 500.0);

      expect(await orbit.orbitPlay(), isTrue);
      await tester.pump(const Duration(milliseconds: 400));

      expect(rig.commands.first, contains('<latitude>48.85</latitude>'));
      await orbit.orbitStop();
    });

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

      // 60 steps over a full circle = 6 degrees per tick.
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

    // The tick future used to be unawaited with errors forwarded through
    // whenComplete, so a rig dropping mid-orbit threw into the zone once
    // every 400ms and kept ticking against a dead socket for the full 24s.
    testWidgets('a rig that drops mid-orbit ends the orbit', (tester) async {
      await orbit.orbitPlay(lat: 1, lng: 2, range: 1000);
      await tester.pump(const Duration(milliseconds: 400));
      expect(orbit.isOrbitPlaying, isTrue);

      rig.failWith = const LGSSHException('connection lost');
      await tester.pump(const Duration(milliseconds: 400));

      expect(orbit.isOrbitPlaying, isFalse);

      // And it really stopped — no further ticks once the rig is back.
      rig.failWith = null;
      final sentSoFar = rig.commands.length;
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.commands.length, sentSoFar);
    });
  });
}
