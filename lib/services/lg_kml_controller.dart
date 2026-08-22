import 'dart:convert';

import '../core/constants.dart';
import 'lg_command_service.dart';
import 'lg_orbit_controller.dart';

class LGKMLController {
  final LGCommandService _commandService;

  static const _webRoot = LGPaths.webRoot;
  static const _kmlDir = LGPaths.kmlDir;
  static const _kmlsFile = LGPaths.kmlsFile;

  /// Pins rotate through slots 2..[_pinSlots]+1 so consecutive pins coexist —
  /// slot 1 stays reserved for the ground overlay. Every pin used to land in
  /// slot 2, so dropping a second pin silently erased the first.
  static const _pinSlots = 8;
  int _nextPinSlot = 0;

  static const _webPort = LGPaths.webPort;

  LGKMLController(this._commandService);

  /// Writes the KML into a numbered slot and registers it in kmls.txt.
  /// Separate slots let a ground overlay and a dropped pin coexist;
  /// cleanKML wipes every lgquickrig_* slot.
  Future<void> sendKML(String kml, {int slot = 1}) async {
    final escaped = _shellEscape(kml);
    await _commandService.execute(
      "echo '$escaped' > $_kmlDir/lgquickrig_$slot.kml",
    );
    await _addKMLReference('http://$_host:$_webPort/kml/lgquickrig_$slot.kml');
  }

  Future<void> _addKMLReference(String url) async {
    // Append only if not already listed — repeated overlays would otherwise
    // pile up duplicate entries in kmls.txt.
    await _commandService.execute(
      "grep -qxF '$url' $_kmlsFile 2>/dev/null || echo '$url' >> $_kmlsFile",
    );
  }

  Future<void> cleanKML() async {

    await _commandService.execute(
      "rm -f $_kmlDir/lgquickrig_*.kml 2>/dev/null; echo 'done'",
    );

    // Ground overlay images were uploaded next to the KMLs but never removed,
    // so every overlay ever sent stayed on the rig's disk forever.
    await _commandService.execute(
      "rm -f $_webRoot/lgquickrig_overlay_* 2>/dev/null || true",
    );

    await _commandService.execute(
      "sed -i '/lgquickrig/d' $_kmlsFile 2>/dev/null || true",
    );

    _nextPinSlot = 0;
  }

  Future<void> groundOverlay({
    required List<int> imageBytes,
    required String imageName,
    required double north,
    required double south,
    required double east,
    required double west,
  }) async {
    final imageUrl = 'http://$_host:$_webPort/$imageName';
    final kml = '<?xml version="1.0" encoding="UTF-8"?>'
        '<kml xmlns="http://www.opengis.net/kml/2.2">'
        '<GroundOverlay>'
        '<name>$imageName</name>'
        '<Icon><href>$imageUrl</href></Icon>'
        '<LatLonBox>'
        '<north>$north</north><south>$south</south>'
        '<east>$east</east><west>$west</west>'
        '</LatLonBox>'
        '</GroundOverlay></kml>';

    await _commandService.uploadFile(imageBytes, '/var/www/html/$imageName');
    await sendKML(kml);
  }

  /// Drops a tinted Placemark. With no [iconHref] it uses the built-in
  /// pushpin, which renders even on rigs without internet access; an
  /// [iconHref] (e.g. the mapfiles flag/target icons) needs the rig online.
  /// [kmlColor] is KML aabbggrr, e.g. ff0000ff = red. [description], if
  /// given, becomes the info balloon shown when the pin is clicked on the rig.
  Future<void> dropPin({
    required double lat,
    required double lng,
    String name = 'QuickRig Pin',
    String? description,
    String kmlColor = 'ff0000ff',
    String? iconHref,
  }) async {
    final icon = iconHref != null ? '<Icon><href>$iconHref</href></Icon>' : '';
    final desc = description != null
        ? '<description>${htmlEscape.convert(description)}</description>'
        : '';
    final kml = '<?xml version="1.0" encoding="UTF-8"?>'
        '<kml xmlns="http://www.opengis.net/kml/2.2">'
        '<Placemark>'
        '<name>${htmlEscape.convert(name)}</name>'
        '$desc'
        '<Style><IconStyle>'
        '<color>$kmlColor</color><scale>1.4</scale>$icon'
        '</IconStyle></Style>'
        '<Point><coordinates>$lng,$lat,0</coordinates></Point>'
        '</Placemark></kml>';
    await sendKML(kml, slot: 2 + (_nextPinSlot++ % _pinSlots));
  }

  String get _host => _commandService.host;

  String _shellEscape(String content) => content.replaceAll("'", r"'\''");
}

/// Rig sanity check: drop a pin wherever the rig is currently looking (the
/// Taj Mahal only as a fallback if nothing's been flown to yet) and fly
/// there — if the pin appears, the whole KML pipeline (write, kmls.txt,
/// refresh) works. Shared by the dashboard's KML Test tile and the Linux
/// tray's menu item so there's one implementation to keep dynamic.
Future<void> kmlSanityCheck(LGKMLController kml, LGOrbitController orbit) async {
  final target = await orbit.currentTarget();
  final lat = target?.lat ?? 27.1751;
  final lng = target?.lng ?? 78.0421;
  final range = target?.range ?? 5000;
  await kml.dropPin(lat: lat, lng: lng, name: 'QuickRig KML Test');
  await orbit.flyTo(lat: lat, lng: lng, range: range);
}
