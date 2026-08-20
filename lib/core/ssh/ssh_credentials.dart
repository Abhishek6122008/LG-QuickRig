
class SSHCredentials {
  final String host;
  final int port;
  final String username;
  final String password;

  final int nodeCount;

  const SSHCredentials({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.nodeCount = 3,
  });

  @override
  String toString() =>
      'SSHCredentials($username@$host:$port, nodes: $nodeCount)';

  // Value equality so the SSH client can tell "reconnect with what you have"
  // from "the user just changed something" — a password edit has to count as
  // different credentials, so it is part of the comparison.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SSHCredentials &&
          host == other.host &&
          port == other.port &&
          username == other.username &&
          password == other.password &&
          nodeCount == other.nodeCount;

  @override
  int get hashCode => Object.hash(host, port, username, password, nodeCount);
}
