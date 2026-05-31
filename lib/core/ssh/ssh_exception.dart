/// Thrown for any SSH-layer error surfaced by [LGSSHClient].
class LGSSHException implements Exception {
  final String message;

  const LGSSHException(this.message);

  @override
  String toString() => 'LGSSHException: $message';
}
