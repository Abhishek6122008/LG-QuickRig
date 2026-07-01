import 'lg_command_service.dart';

class LGKMLController {
  final LGCommandService _commandService;

  static const _kmlDir = '/var/www/html/kml';
  static const _kmlsFile = '/var/www/html/kmls.txt';

  LGKMLController(this._commandService);

  Future<void> sendKML(String kml) async {
    final escaped = _shellEscape(kml);
    await _commandService.execute(
      "echo '$escaped' > $_kmlDir/lgquickrig_1.kml",
    );
  }

  Future<void> addKMLReference(String url) async {
    await _commandService.execute("echo '$url' >> $_kmlsFile");
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
    final imageUrl = 'http://$_host/$imageName';
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
    await addKMLReference('http://$_host/kml/lgquickrig_1.kml');
  }

  String get _host => _commandService.host;

  String _shellEscape(String content) => content.replaceAll("'", r"'\''");
}
