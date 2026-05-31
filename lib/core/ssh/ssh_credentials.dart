/// All parameters needed to open an SSH session to the Liquid Galaxy cluster.
class SSHCredentials {
  final String host;
  final int port;
  final String username;
  final String password;

  /// Total number of LG nodes (master + slaves). Used by [LGCommandService]
  /// when broadcasting commands across the cluster.
  final int nodeCount;

  const SSHCredentials({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
    this.nodeCount = 3,
  });

  SSHCredentials copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    int? nodeCount,
  }) {
    return SSHCredentials(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      nodeCount: nodeCount ?? this.nodeCount,
    );
  }

  @override
  String toString() =>
      'SSHCredentials($username@$host:$port, nodes: $nodeCount)';
}
