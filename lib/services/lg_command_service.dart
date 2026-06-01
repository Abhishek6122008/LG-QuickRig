import '../core/ssh/ssh_client.dart';
import '../core/ssh/ssh_exception.dart';

/// Sits one layer above [LGSSHClient].
///
/// Responsibilities:
///   1. Raw command execution on the master node (LG1).
///   2. Slave-node execution via ssh-from-master, using the stored password.
///   3. Cluster-level system commands: reboot, shutdown, restart, sync.
///
/// All public methods throw [LGSSHException] on failure.
/// Callers (controllers, dashboard) are expected to catch and surface errors.
class LGCommandService {
  final LGSSHClient _client;

  LGCommandService(this._client);

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool get isConnected => _client.isConnected;

  /// Total LG nodes (master + slaves) from the active credentials.
  int get nodeCount => _client.credentials?.nodeCount ?? 3;

  // ---------------------------------------------------------------------------
  // Raw execution
  // ---------------------------------------------------------------------------

  /// Executes [command] on the LG master node and returns stdout.
  Future<String> execute(String command) => _client.executeCommand(command);

  /// Executes [command] on slave node [node] (range: 2..nodeCount) via SSH
  /// from the master.
  ///
  /// Standard LG clusters share the same password across all nodes.
  /// The password is taken from the active [SSHCredentials].
  ///
  /// Note: The password is shell-quoted but if it contains single-quotes you
  /// must ensure it is URL-encoded or changed before shipping to production.
  Future<String> executeOnSlave(int node, String command) {
    assert(
      node >= 2 && node <= nodeCount,
      'Node index $node is out of range [2, $nodeCount]',
    );
    final pass = _client.credentials?.password ?? 'lg';
    // Escape single-quotes in the password to prevent shell injection.
    final safePass = pass.replaceAll("'", r"'\''");
    return execute(
      "sshpass -p '$safePass' ssh -t "
      "-o StrictHostKeyChecking=no "
      "-o ConnectTimeout=5 "
      "lg@lg$node '$command' 2>/dev/null",
    );
  }

  // ---------------------------------------------------------------------------
  // System commands
  // ---------------------------------------------------------------------------

  /// Reboots every node in the cluster.
  ///
  /// Slaves are rebooted first (in descending order) so the master — which
  /// serves KML/HTTP — is last. The SSH connection will drop immediately after
  /// the master reboot command is sent; this is expected and not re-thrown.
  Future<void> reboot() async {
    for (int i = nodeCount; i >= 2; i--) {
      try {
        await executeOnSlave(i, 'sudo reboot');
      } on LGSSHException {
        // Slave drops the connection as soon as it starts rebooting — normal.
      }
    }
    try {
      await execute('sudo reboot');
    } on LGSSHException {
      // Master drops the connection immediately — expected.
    }
  }

  /// Shuts down every node in the cluster.
  Future<void> shutdown() async {
    for (int i = nodeCount; i >= 2; i--) {
      try {
        await executeOnSlave(i, 'sudo shutdown -h now');
      } on LGSSHException {
        // Same pattern as reboot — connection drops after the command.
      }
    }
    try {
      await execute('sudo shutdown -h now');
    } on LGSSHException {
      // Expected — master shuts down before SSH can send a clean response.
    }
  }

  /// Restarts the Liquid Galaxy browser/presentation stack on every node.
  ///
  /// Tries the standard LG relaunch script; falls back to a direct pkill
  /// so the caller knows whether any step succeeded.
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

  /// Runs the LG sync script on the master, which propagates content to slaves.
  Future<void> sync() async {
    await execute(
      "~/scripts/lg-sync 2>/dev/null "
      "|| ~/bin/lg-sync 2>/dev/null "
      "|| echo 'sync script not found'",
    );
  }

  /// Blanks all LG screens by writing empty KML files to each slave and
  /// clearing the master's KML reference list.
  Future<void> blankScreens() async {
    for (int i = nodeCount; i >= 2; i--) {
      try {
        await executeOnSlave(
          i,
          'echo "" > /var/www/html/kml/slave_$i.kml',
        );
      } on LGSSHException {
        // Continue even if a slave is unreachable.
      }
    }
    await execute('echo "" > /var/www/html/kmls.txt');
  }
}
