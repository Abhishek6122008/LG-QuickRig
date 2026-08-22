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

  /// Called when a running orbit gives up on the rig. Without it a died
  /// orbit vanished silently — the errors were swallowed one per tick.
  void Function(String)? onOrbitError;

  LGOrbitController(this._commandService);

  bool get isOrbitPlaying => _orbitPlaying;

  /// Best-effort "where is the camera": the rig's query.txt first, then the
  /// last position this app commanded. query.txt is empty on a fresh rig and
  /// some LG setups consume it after Earth reads it, so this returns null
  /// often enough that it is no longer offered to the user as a way to fill
  /// in coordinates. It survives for the Copilot's rig context and the KML
  /// test, both of which degrade to "unknown" without complaining.
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

  /// Circles the camera around [lat]/[lng] until [orbitStop] is called.
  ///
  /// Returns false only when an orbit is already running. This used to stop
  /// itself after 60 steps, and to end the whole orbit on the first failed
  /// SSH write — with the error swallowed. Step 0 is heading 0, so a failure
  /// on step 1 looked exactly like "it points north and quits".
  Future<bool> orbitPlay({
    required double lat,
    required double lng,
    double? range,
    double tilt = 45,
    VoidCallback? onStop,
  }) async {
    if (_orbitPlaying) return false;

    final orbitLat = lat;
    final orbitLng = lng;
    final orbitRange = range ?? _lastRange ?? 10000;

    _lastLat = lat;
    _lastLng = lng;
    _lastRange = orbitRange;

    _orbitPlaying = true;

    // 6 degrees every 400ms: one revolution in 24 seconds, and it keeps going
    // for as many revolutions as the operator wants.
    const int stepDegrees = 6;
    const int stepDurationMs = 400;

    // A rig that blips shouldn't end a running orbit. Three consecutive
    // failures means it's really gone.
    const int maxConsecutiveFailures = 3;

    int currentStep = 0;
    int failures = 0;
    bool isMoving = false;

    void finish(Timer timer, [String? error]) {
      timer.cancel();
      _orbitTimer = null;
      _orbitPlaying = false;
      onStop?.call();
      if (error != null) onOrbitError?.call(error);
    }

    _orbitTimer = Timer.periodic(
      const Duration(milliseconds: stepDurationMs),
      (timer) async {
        if (!_orbitPlaying) {
          finish(timer);
          return;
        }
        if (isMoving) return;
        isMoving = true;

        final double bearing = (currentStep * stepDegrees) % 360;
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

        try {
          await _commandService.execute(
            "echo 'flytoview=$lookAt' > /tmp/query.txt",
          );
          failures = 0;
        } catch (e) {
          failures++;
          if (failures >= maxConsecutiveFailures) {
            finish(timer, 'Orbit stopped: $e');
          }
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
