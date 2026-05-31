import 'lg_command_service.dart';

/// Controls the Liquid Galaxy viewport — fly-to, orbit, and camera reset.
///
/// View commands are issued by writing a KML file containing a
/// `gx:FlyTo` element to the master's HTTP server. The cluster browser
/// picks it up via a pre-configured NetworkLink with a short refresh interval.
///
/// ── Setup requirement ────────────────────────────────────────────────────
/// The LG installation must have a NetworkLink in its persistent KML that
/// polls `http://lg1/kml/lgquickrig_orbit.kml`. Without this NetworkLink
/// the FlyTo files are written but ignored by the browsers.
/// ─────────────────────────────────────────────────────────────────────────
class LGOrbitController {
  final LGCommandService _commandService;

  static const _kmlDir = '/var/www/html/kml';
  static const _orbitFile = '$_kmlDir/lgquickrig_orbit.kml';

  LGOrbitController(this._commandService);

  // ---------------------------------------------------------------------------
  // View commands
  // ---------------------------------------------------------------------------

  /// Smoothly flies the LG view to the given geographic location.
  ///
  /// Parameters follow the KML `LookAt` spec:
  ///   [lat]      Latitude  in decimal degrees (-90 to 90)
  ///   [lng]      Longitude in decimal degrees (-180 to 180)
  ///   [altitude] Altitude in metres above ground
  ///   [range]    Distance from the point to the camera in metres
  ///   [tilt]     Tilt angle in degrees (0 = top-down, 90 = horizon)
  ///   [heading]  Compass bearing in degrees (0 = North)
  Future<void> flyTo({
    required double lat,
    required double lng,
    double altitude = 0,
    double range = 1000,
    double tilt = 60,
    double heading = 0,
  }) async {
    final kml = _buildFlyToKml(lat, lng, altitude, range, tilt, heading);
    final escaped = kml.replaceAll("'", r"'\''");
    await _commandService.execute("echo '$escaped' > $_orbitFile");
  }

  /// Sets the camera to look straight down at [lat]/[lng] from [altitudeM]
  /// metres — useful for a top-down map view.
  Future<void> lookAt({
    required double lat,
    required double lng,
    double altitudeM = 10000,
  }) => flyTo(lat: lat, lng: lng, altitude: altitudeM, range: altitudeM, tilt: 0);

  /// Removes the QuickRig orbit KML, releasing the view back to the cluster's
  /// default state.
  Future<void> stopOrbit() async {
    await _commandService.execute(
      'rm -f $_orbitFile 2>/dev/null; echo done',
    );
  }

  // ---------------------------------------------------------------------------
  // KML builders
  // ---------------------------------------------------------------------------

  String _buildFlyToKml(
    double lat,
    double lng,
    double altitude,
    double range,
    double tilt,
    double heading,
  ) =>
      '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"
     xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <gx:Tour>
      <name>LGQuickRig FlyTo</name>
      <gx:Playlist>
        <gx:FlyTo>
          <gx:duration>2</gx:duration>
          <gx:flyToMode>smooth</gx:flyToMode>
          <LookAt>
            <longitude>$lng</longitude>
            <latitude>$lat</latitude>
            <altitude>$altitude</altitude>
            <range>$range</range>
            <tilt>$tilt</tilt>
            <heading>$heading</heading>
            <altitudeMode>relativeToGround</altitudeMode>
          </LookAt>
        </gx:FlyTo>
      </gx:Playlist>
    </gx:Tour>
  </Document>
</kml>''';
}
