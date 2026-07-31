
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
}
