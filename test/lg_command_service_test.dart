import 'package:flutter_test/flutter_test.dart';
import 'package:lg_quickrig/core/ssh/ssh_credentials.dart';
import 'package:lg_quickrig/services/lg_command_service.dart';

import 'fakes.dart';

// The rig is driven entirely by shell strings, so the strings ARE the
// contract. Everything here asserts on what would actually land on the
// master's shell.
void main() {
  late FakeSSHClient ssh;
  late LGCommandService commands;

  Future<void> connectWith(String password, {int nodes = 3}) async {
    await ssh.connect(SSHCredentials(
      host: '192.168.2.2',
      port: 22,
      username: 'lg',
      password: password,
      nodeCount: nodes,
    ));
  }

  setUp(() {
    ssh = FakeSSHClient();
    commands = LGCommandService(ssh);
  });

  group('readCameraTarget', () {
    test('parses lat/lng/range out of a flytoview LookAt', () async {
      ssh.nextOutput = 'flytoview=<LookAt><latitude>27.1751</latitude>'
          '<longitude>78.0421</longitude><range>1500.0</range>'
          '<heading>0</heading><tilt>45</tilt></LookAt>';

      final target = await commands.readCameraTarget();

      expect(target, isNotNull);
      expect(target!.lat, 27.1751);
      expect(target.lng, 78.0421);
      expect(target.range, 1500.0);
    });

    // A fresh rig has an empty query.txt, and some LG setups delete it once
    // Earth has read it — both must degrade to null, not crash or return 0,0.
    test('returns null when query.txt is empty or consumed', () async {
      ssh.nextOutput = '';
      expect(await commands.readCameraTarget(), isNull);
    });

    test('returns null when the rig is unreachable', () async {
      ssh.failOn.add('query.txt');
      expect(await commands.readCameraTarget(), isNull);
    });

    test('range is optional — a LookAt without one still parses', () async {
      ssh.nextOutput =
          '<LookAt><latitude>41.9</latitude><longitude>12.5</longitude></LookAt>';

      final target = await commands.readCameraTarget();

      expect(target!.lat, 41.9);
      expect(target.range, isNull);
    });
  });

  group('executeOnSlave', () {
    // The password is interpolated into a single-quoted sshpass argument. An
    // apostrophe in it would close that quote early and every slave command
    // would silently run as garbage — this is the whole reason _sudoPass and
    // the command escaping exist.
    test("a password containing ' stays inside its own quoting", () async {
      await connectWith("lg'pass");

      await commands.executeOnSlave(2, 'echo hi');

      expect(ssh.commands.single, contains(r"-p 'lg'\''pass'"));
      expect(ssh.commands.single, isNot(contains("-p 'lg'pass'")));
    });

    test("a command containing ' is escaped for its own wrapper", () async {
      await connectWith('lg');

      await commands.executeOnSlave(3, "echo 'done'");

      expect(ssh.commands.single, contains(r"lg@lg3 'echo '\''done'\'''"));
    });
  });

  group('multi-node actions', () {
    test('reboot walks slaves high to low, then the master', () async {
      await connectWith('lg', nodes: 3);

      await commands.reboot();

      expect(ssh.commands.length, 3);
      expect(ssh.commands[0], contains('lg@lg3'));
      expect(ssh.commands[1], contains('lg@lg2'));
      expect(ssh.commands[2], isNot(contains('sshpass'))); // master, directly
      expect(ssh.commands.last, contains('sudo -S reboot'));
    });

    // A node drops the SSH connection as it goes down. That exception is
    // expected, not a failure — the remaining nodes must still be told.
    test('reboot keeps going when a node drops the connection', () async {
      await connectWith('lg', nodes: 3);
      ssh.failOn.add('lg@lg3');

      await commands.reboot();

      expect(ssh.sent('lg@lg2'), isTrue);
      expect(ssh.commands.last, contains('sudo -S reboot'));
    });

    test('shutdown reaches every node and the master', () async {
      await connectWith('lg', nodes: 3);
      ssh.failOn.addAll({'lg@lg3', 'lg@lg2'});

      await commands.shutdown();

      expect(ssh.commands.length, 3);
      expect(ssh.commands.last, contains('shutdown -h now'));
    });

    test('blankScreens clears each slave kml and then kmls.txt', () async {
      await connectWith('lg', nodes: 3);

      await commands.blankScreens();

      expect(ssh.only('slave_3.kml'), contains('lg@lg3'));
      expect(ssh.only('slave_2.kml'), contains('lg@lg2'));
      expect(ssh.commands.last, contains('> /var/www/html/kmls.txt'));
    });

    test('restartServices relaunches the master directly, slaves over ssh',
        () async {
      await connectWith('lg', nodes: 3);

      await commands.restartServices();

      expect(ssh.commands.length, 3);
      expect(ssh.commands[0], contains('lg@lg3'));
      expect(ssh.commands.last, contains('lg-relaunch'));
      expect(ssh.commands.last, isNot(contains('sshpass')));
    });
  });

  // Without credentials the service falls back to a 3-node rig rather than
  // refusing to act — the widgets can fire before any connect() lands.
  test('nodeCount defaults to 3 with no credentials', () {
    expect(commands.nodeCount, 3);
  });
}
