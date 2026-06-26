import 'dart:async';

import 'package:flutter/foundation.dart';

import 'lg_command_service.dart';

class LGOrbitController {
  final LGCommandService _commandService;

  Timer? _orbitTimer;
  bool _orbitPlaying = false;
  String? _lastOrbitPosition;

  double? _lastLat;
  double? _lastLng;
  double? _lastRange;

  LGOrbitController(this._commandService);

  bool get isOrbitPlaying => _orbitPlaying;

  Future<void> flyTo({
    required double lat,
    required double lng,
    double range = 10000,
    double tilt = 0,
    double heading = 0,
  }) async {
    _lastLat = lat;
    _lastLng = lng;
    _lastRange = range;

    final lookAt = '<LookAt>'
        '<latitude>$lat</latitude>'
        '<longitude>$lng</longitude>'
        '<range>$range</range>'
        '<heading>$heading</heading>'
        '<tilt>$tilt</tilt>'
        '</LookAt>';
    await _commandService.execute(
      'echo "flytoview=$lookAt" > /tmp/query.txt',
    );
  }

  Future<bool> orbitPlay({
    double? lat,
    double? lng,
    double? range,
    double tilt = 45,
    VoidCallback? onStop,
  }) async {
    if (_orbitPlaying) return false;

    final orbitLat = lat ?? _lastLat;
    final orbitLng = lng ?? _lastLng;
    final orbitRange = range ?? _lastRange ?? 10000;
    if (orbitLat == null || orbitLng == null) return false;

    _orbitPlaying = true;

    const int steps = 60;
    const int stepDurationMs = 400;
    int currentStep = 0;
    bool isMoving = false;

    _orbitTimer = Timer.periodic(
      const Duration(milliseconds: stepDurationMs),
      (timer) {
        if (!_orbitPlaying || currentStep >= steps) {
          timer.cancel();
          _orbitPlaying = false;
          onStop?.call();
          return;
        }
        if (isMoving) return;
        isMoving = true;

        final double bearing = (currentStep * (360 / steps)) % 360;
        final lookAt = '<gx:duration>0.3</gx:duration>'
            '<gx:flyToMode>smooth</gx:flyToMode>'
            '<LookAt>'
            '<longitude>$orbitLng</longitude>'
            '<latitude>$orbitLat</latitude>'
            '<range>$orbitRange</range>'
            '<tilt>$tilt</tilt>'
            '<heading>$bearing</heading>'
            '<gx:altitudeMode>relativeToGround</gx:altitudeMode>'
            '</LookAt>';
        _lastOrbitPosition = lookAt;

        _commandService
            .execute("echo 'flytoview=$lookAt' > /tmp/query.txt")
            .whenComplete(() => isMoving = false);

        currentStep++;
      },
    );
    return true;
  }

  Future<void> orbitStop() async {
    _orbitTimer?.cancel();
    _orbitTimer = null;
    _orbitPlaying = false;
    if (_lastOrbitPosition != null) {
      await _commandService.execute(
        "echo 'flytoview=$_lastOrbitPosition' > /tmp/query.txt",
      );
    }
  }
}
