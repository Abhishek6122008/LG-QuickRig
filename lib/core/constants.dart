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

/// Where the LG master serves its KML from. Shared so the command service and
/// the KML controller can't drift apart on the web root or the port.
class LGPaths {
  LGPaths._();

  static const String webRoot = '/var/www/html';
  static const String kmlDir = '$webRoot/kml';
  static const String kmlsFile = '$webRoot/kmls.txt';

  // The LG image serves /var/www/html on port 81, not 80 — port-80 URLs land
  // in kmls.txt but Earth can never fetch them, so nothing renders.
  static const int webPort = 81;
}
