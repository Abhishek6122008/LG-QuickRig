import 'package:flutter/services.dart';

// Shared with the Android widgets/tile — one declaration so the channel
// name can't drift out of sync between call sites.
const platformCommandsChannel =
    MethodChannel('com.liqtech.lg_quickrig/commands');

class LGDefaults {
  LGDefaults._();

  static const String host = '192.168.2.2';
  static const int port = 22;
  static const String username = 'lg';

  static const Duration connectTimeout = Duration(seconds: 10);

  static const Duration commandTimeout = Duration(seconds: 30);

  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}
