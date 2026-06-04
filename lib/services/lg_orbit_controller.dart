import 'dart:async';

import 'package:flutter/foundation.dart';

import 'lg_command_service.dart';

/// Controls the Liquid Galaxy viewport — fly-to, orbit, and camera reset.
///
/// View commands are sent by writing a `flytoview=<LookAt>` line to
/// `/tmp/query.txt`, which the LG master process monitors natively.
/// No NetworkLink setup is required.
class LGOrbitController {
  final LGCommandService _commandService;

  Timer? _orbitTimer;
  bool _orbitPlaying = false;
  String? _lastOrbitPosition;

  LGOrbitController(this._commandService);

  bool get isOrbitPlaying => _orbitPlaying;

  // ---------------------------------------------------------------------------
  // Fly-to
  // ---------------------------------------------------------------------------

  /// Smoothly moves the LG camera to the given geographic point.
  Future<void> flyTo({
    required double lat,
    required double lng,
    double range = 10000,
    double tilt = 0,
    double heading = 0,
  }) async {
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

  // ---------------------------------------------------------------------------
  // Orbit
  // ---------------------------------------------------------------------------

  /// Starts a 360° orbit animation around [lat]/[lng] at [range] metres.
  ///
  /// Returns `false` if an orbit is already playing; `true` when started.
  /// [onStop] is called when the animation finishes or is cancelled.
  Future<bool> orbitPlay({
    required double lat,
    required double lng,
    required double range,
    double tilt = 45,
    VoidCallback? onStop,
  }) async {
    if (_orbitPlaying) return false;
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
            '<longitude>$lng</longitude>'
            '<latitude>$lat</latitude>'
            '<range>$range</range>'
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

  /// Cancels the orbit animation and holds the camera at the last position.
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
