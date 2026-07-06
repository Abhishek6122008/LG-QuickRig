import 'lg_command_service.dart';

class LGKMLController {
  final LGCommandService _commandService;

  static const _kmlDir = '/var/www/html/kml';
  static const _kmlsFile = '/var/www/html/kmls.txt';

  // The LG image serves /var/www/html on port 81, not 80 — port-80 URLs
  // land in kmls.txt but Earth can never fetch them, so nothing renders.
  static const _webPort = 81;

  LGKMLController(this._commandService);

  /// Writes the KML into a numbered slot and registers it in kmls.txt.
  /// Separate slots let a ground overlay and a dropped pin coexist;
  /// cleanKML wipes every lgquickrig_* slot.
  Future<void> sendKML(String kml, {int slot = 1}) async {
    final escaped = _shellEscape(kml);
    await _commandService.execute(
      "echo '$escaped' > $_kmlDir/lgquickrig_$slot.kml",
    );
    await addKMLReference('http://$_host:$_webPort/kml/lgquickrig_$slot.kml');
  }

  Future<void> addKMLReference(String url) async {
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

    await _commandService.execute(
      "sed -i '/lgquickrig/d' $_kmlsFile 2>/dev/null || true",
    );
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
  /// [kmlColor] is KML aabbggrr, e.g. ff0000ff = red.
  Future<void> dropPin({
    required double lat,
    required double lng,
    String name = 'QuickRig Pin',
    String kmlColor = 'ff0000ff',
    String? iconHref,
  }) async {
    final icon = iconHref != null ? '<Icon><href>$iconHref</href></Icon>' : '';
    final kml = '<?xml version="1.0" encoding="UTF-8"?>'
        '<kml xmlns="http://www.opengis.net/kml/2.2">'
        '<Placemark>'
        '<name>$name</name>'
        '<Style><IconStyle>'
        '<color>$kmlColor</color><scale>1.4</scale>$icon'
        '</IconStyle></Style>'
        '<Point><coordinates>$lng,$lat,0</coordinates></Point>'
        '</Placemark></kml>';
    await sendKML(kml, slot: 2);
  }

  String get _host => _commandService.host;

  String _shellEscape(String content) => content.replaceAll("'", r"'\''");
}
