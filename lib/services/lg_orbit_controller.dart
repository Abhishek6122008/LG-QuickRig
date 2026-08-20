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

  /// Best-effort "where is the camera": the rig's query.txt first, then the
  /// last position this app commanded. query.txt is empty on a fresh rig and
  /// some LG setups consume it after Earth reads it — without the fallback
  /// the "use current view" buttons dead-end on those rigs.
  Future<({double lat, double lng, double? range})?> currentTarget() async {
    final target = await _commandService.readCameraTarget();
    if (target != null) return target;
    final lat = _lastLat, lng = _lastLng;
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng, range: _lastRange);
  }

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

    var orbitLat = lat ?? _lastLat;
    var orbitLng = lng ?? _lastLng;
    var orbitRange = range ?? _lastRange ?? 10000;

    // Nothing flown from this app yet — orbit wherever the rig's camera is.
    if (orbitLat == null || orbitLng == null) {
      final target = await _commandService.readCameraTarget();
      if (target == null) return false;
      orbitLat = target.lat;
      orbitLng = target.lng;
      orbitRange = range ?? target.range ?? 10000;
    }

    _orbitPlaying = true;

    const int steps = 60;
    const int stepDurationMs = 400;
    int currentStep = 0;
    bool isMoving = false;

    void finish(Timer timer) {
      timer.cancel();
      _orbitTimer = null;
      _orbitPlaying = false;
      onStop?.call();
    }

    _orbitTimer = Timer.periodic(
      const Duration(milliseconds: stepDurationMs),
      (timer) async {
        if (!_orbitPlaying || currentStep >= steps) {
          finish(timer);
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
        currentStep++;

        // Previously this future was left unawaited and its errors forwarded
        // through whenComplete, so a rig that dropped mid-orbit threw into
        // the zone once every 400ms while the orbit ticked on against a dead
        // socket for the rest of its 24-second run. One failure ends it.
        try {
          await _commandService.execute(
            "echo 'flytoview=$lookAt' > /tmp/query.txt",
          );
        } catch (_) {
          finish(timer);
        } finally {
          isMoving = false;
        }
      },
    );
    return true;
  }

  /// Safe to call when nothing is orbiting — the Camera tab's Stop Orbit tile
  /// is always enabled so a runaway orbit is always stoppable.
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
