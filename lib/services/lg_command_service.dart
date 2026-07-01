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

  Future<String> executeOnSlave(int node, String command) {
    assert(
      node >= 2 && node <= nodeCount,
      'Node index $node is out of range [2, $nodeCount]',
    );
    final pass = _client.credentials?.password ?? 'lg';

    final safePass = pass.replaceAll("'", r"'\''");
    return execute(
      "sshpass -p '$safePass' ssh -t "
      "-o StrictHostKeyChecking=no "
      "-o ConnectTimeout=5 "
      "lg@lg$node '$command' 2>/dev/null",
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

  Future<void> restartServices() async {
    for (int i = nodeCount; i >= 1; i--) {
      final cmd =
          "export DISPLAY=:0; pkill -9 chrome 2>/dev/null || true; sleep 1; "
          "/home/lg/bin/lg-relaunch 2>/dev/null "
          "|| ~/scripts/lg-relaunch 2>/dev/null "
          "|| echo 'relaunch script not found on node $i'";

      if (i == 1) {
        await execute(cmd);
      } else {
        await executeOnSlave(i, cmd);
      }
    }
  }

  Future<void> sync() async {
    await execute(
      "~/scripts/lg-sync 2>/dev/null "
      "|| ~/bin/lg-sync 2>/dev/null "
      "|| echo 'sync script not found'",
    );
  }

  Future<void> blankScreens() async {
    for (int i = nodeCount; i >= 2; i--) {
      try {
        await executeOnSlave(
          i,
          'echo "" > /var/www/html/kml/slave_$i.kml',
        );
      } on LGSSHException {
        // one unreachable slave shouldn't stop us blanking the rest
      }
    }
    await execute('echo "" > /var/www/html/kmls.txt');
  }

  String _sudoPass() {
    final pass = _client.credentials?.password ?? 'lg';
    return pass.replaceAll("'", r"'\''");
  }
}
