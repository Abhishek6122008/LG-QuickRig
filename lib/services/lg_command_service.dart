import '../core/ssh/ssh_client.dart';
import '../core/ssh/ssh_exception.dart';

class LGCommandService {
  final LGSSHClient _client;

  LGCommandService(this._client);

  bool get isConnected => _client.isConnected;

  int get nodeCount => _client.credentials?.nodeCount ?? 3;

  Future<String> execute(String command) => _client.executeCommand(command);

  String get host => _client.credentials?.host ?? '';

  Future<void> uploadFile(List<int> bytes, String remotePath) =>
      _client.uploadBytes(bytes, remotePath);

  /// Last camera target commanded on the rig — every controller app drives
  /// Earth by writing a flytoview LookAt/Camera to /tmp/query.txt on the
  /// master, so this is "where the camera is" for command-driven movement.
  /// ponytail: blind to SpaceNav/mouse moves — capture ViewSync UDP on a
  /// slave if that ever matters.
  Future<({double lat, double lng, double? range})?> readCameraTarget() async {
    try {
      final xml = await execute('cat /tmp/query.txt 2>/dev/null');
      final lat = _tagValue(xml, 'latitude');
      final lng = _tagValue(xml, 'longitude');
      if (lat == null || lng == null) return null;
      return (lat: lat, lng: lng, range: _tagValue(xml, 'range'));
    } on LGSSHException {
      return null;
    }
  }

  double? _tagValue(String xml, String tag) => double.tryParse(
      RegExp('<$tag>([^<]*)</$tag>').firstMatch(xml)?.group(1) ?? '');

  /// Stderr is deliberately NOT discarded here: [LGSSHClient.executeCommand]
  /// folds it into the returned string, and it is the only way to learn *why*
  /// a node refused a command. This used to end in `2>/dev/null`, which is
  /// how "sshpass: not found" and "sudo: no tty present" came back looking
  /// exactly like success. Callers that inspect the output must match a
  /// specific marker rather than "any stderr" — `ssh -t` from a non-tty
  /// always warns about the pseudo-terminal it could not allocate.
  Future<String> executeOnSlave(int node, String command) {
    // Was an assert, which release builds strip — an out-of-range node then
    // silently SSHed to a host that doesn't exist.
    if (node < 2 || node > nodeCount) {
      throw LGSSHException('Node index $node is out of range [2, $nodeCount]');
    }
    final pass = _client.credentials?.password ?? 'lg';

    final safePass = pass.replaceAll("'", r"'\''");
    // Escape the command for its own single-quote wrapper — inner quotes
    // (e.g. around the sudo password) would otherwise terminate it early.
    final safeCmd = command.replaceAll("'", r"'\''");
    return execute(
      "sshpass -p '$safePass' ssh -t "
      "-o StrictHostKeyChecking=no "
      "-o ConnectTimeout=5 "
      "lg@lg$node '$safeCmd'",
    );
  }

  Future<void> reboot() async {
    final safePass = _sudoPass();
    for (int i = nodeCount; i >= 2; i--) {
      try {
        await executeOnSlave(i, "echo '$safePass' | sudo -S reboot");
      } on LGSSHException {
        // node drops the connection as it goes down — expected, keep going
      }
    }
    try {
      await execute("echo '$safePass' | sudo -S reboot");
    } on LGSSHException {
      // master drops us as it reboots — expected
    }
  }

  Future<void> shutdown() async {
    final safePass = _sudoPass();
    for (int i = nodeCount; i >= 2; i--) {
      try {
        await executeOnSlave(i, "echo '$safePass' | sudo -S shutdown -h now");
      } on LGSSHException {
        // node drops the connection as it powers off — expected, keep going
      }
    }
    try {
      await execute("echo '$safePass' | sudo -S shutdown -h now");
    } on LGSSHException {
      // master drops us as it powers off — expected
    }
  }

  /// Printed by the last link of the relaunch chain. Every link before it
  /// short-circuits on success, so getting this back means every option was
  /// tried and all of them failed.
  static const relaunchFailedMarker = 'LGQUICKRIG_RELAUNCH_FAILED';

  /// Restarts the display manager on every node, which is what actually
  /// relaunches Google Earth without rebooting the machines.
  ///
  /// This is the standard LG relaunch: work out whether the node runs lxdm or
  /// lightdm, then start that service if it is stopped and restart it if it is
  /// not. The old implementation instead looked for an `lg-relaunch` script at
  /// two hardcoded paths; most images don't ship one, so it fell through to an
  /// echo nothing read, exited 0, and the tile reported success while nothing
  /// happened.
  Future<void> relaunch() async {
    final sudo = "echo '${_sudoPass()}' | sudo -S -p ''";
    final cmd =
        'if [ -f /etc/init/lxdm.conf ]; then SERVICE=lxdm; '
        'elif [ -f /etc/init/lightdm.conf ]; then SERVICE=lightdm; '
        // Those two are the Upstart-era markers the classic script uses.
        // A systemd image has no /etc/init at all and keeps its display
        // manager as a unit instead.
        "elif systemctl list-unit-files 2>/dev/null | grep -q '^lxdm'; "
        'then SERVICE=lxdm; '
        "elif systemctl list-unit-files 2>/dev/null | grep -q '^lightdm'; "
        'then SERVICE=lightdm; '
        'else echo $relaunchFailedMarker; exit 0; fi; '
        // `grep -q stop` rather than bash's [[ =~ ]], so this still works if
        // the node's shell is dash.
        r'if service $SERVICE status 2>&1 | grep -q stop; then '
        '$sudo '
        r'service $SERVICE start; '
        'else $sudo '
        r'service $SERVICE restart; fi';

    final failures = <int, String>{};

    // High to low, so the master's X server — the one carrying this very SSH
    // session — is restarted last.
    for (int i = nodeCount; i >= 1; i--) {
      try {
        final out = i == 1 ? await execute(cmd) : await executeOnSlave(i, cmd);
        if (out.contains(relaunchFailedMarker)) failures[i] = out;
      } on LGSSHException catch (e) {
        failures[i] = e.message;
      }
    }

    if (failures.isNotEmpty) {
      final nodes = failures.keys.toList().reversed.join(', ');
      final reason = _firstReason(failures.values.first);
      throw LGSSHException(
        'Relaunch failed on node(s) $nodes — no lxdm or lightdm service '
        'found.${reason.isEmpty ? '' : ' $reason'}',
      );
    }
  }

  /// The most useful line the rig sent back, so the error banner says
  /// something actionable instead of only naming the node.
  String _firstReason(String output) {
    // Strip the marker rather than dropping its whole line: stdout and
    // stderr come back merged, so the real reason can share a line with it.
    final lines = output
        .replaceAll(relaunchFailedMarker, '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !l.contains('Pseudo-terminal'))
        .toList();
    return lines.isEmpty ? '' : lines.last;
  }

  Future<void> sync() async {
    await execute(
      "~/scripts/lg-sync 2>/dev/null "
      "|| ~/bin/lg-sync 2>/dev/null "
      "|| echo 'sync script not found'",
    );
  }

  String _sudoPass() {
    final pass = _client.credentials?.password ?? 'lg';
    return pass.replaceAll("'", r"'\''");
  }
}
