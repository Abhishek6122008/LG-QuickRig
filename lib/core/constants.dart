/// Default connection parameters for the Liquid Galaxy master node.
/// Override these via the Settings screen at runtime.
class LGDefaults {
  LGDefaults._();

  static const String host = '192.168.2.2';
  static const int port = 22;
  static const String username = 'lg';

  // How long to wait before giving up on the initial TCP + SSH handshake.
  static const Duration connectTimeout = Duration(seconds: 10);

  // Per-command execution deadline.
  static const Duration commandTimeout = Duration(seconds: 30);

  // Retry policy for [LGSSHClient.connect].
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}
