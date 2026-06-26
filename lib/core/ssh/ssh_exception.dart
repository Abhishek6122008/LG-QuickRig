
class LGSSHException implements Exception {
  final String message;

  const LGSSHException(this.message);

  @override
  String toString() => 'LGSSHException: $message';
}
