import 'package:flutter_test/flutter_test.dart';
import 'package:lg_quickrig/services/lg_kml_controller.dart';

import 'fakes.dart';

void main() {
  late FakeCommandService rig;
  late LGKMLController kml;

  /// The first command that reached the rig — for pins and overlays that's
  /// always the `echo '<kml>' > slot` write.
  String written() => rig.commands.first;

  setUp(() {
    rig = FakeCommandService()..host = '192.168.2.2';
    kml = LGKMLController(rig);
  });

  group('sendKML', () {
    // Earth fetches kmls.txt entries over HTTP, and the LG image serves
    // /var/www/html on 81. A port-80 URL lands in kmls.txt and silently never
    // renders — it cost a debugging session once already.
    test('registers the KML on port 81, not 80', () async {
      await kml.sendKML('<kml/>');

      expect(rig.only('kmls.txt'),
          contains('http://192.168.2.2:81/kml/lgquickrig_1.kml'));
      expect(rig.sent(':80/'), isFalse);
    });

    test('writes into the numbered slot it was given', () async {
      await kml.sendKML('<kml/>', slot: 2);

      expect(rig.only('> /var/www/html/kml/lgquickrig_2.kml'), isNotEmpty);
    });

    // Sending the same overlay twice would otherwise pile up duplicate lines
    // in kmls.txt, so the append is guarded by a grep.
    test('the kmls.txt append is guarded against duplicates', () async {
      await kml.sendKML('<kml/>');

      expect(rig.only('kmls.txt'), startsWith('grep -qxF '));
      expect(rig.only('kmls.txt'), contains('|| echo '));
    });
  });

  group('dropPin', () {
    test('uses slot 2 so a pin and an overlay can coexist', () async {
      await kml.dropPin(lat: 27.17, lng: 78.04);

      expect(rig.sent('lgquickrig_2.kml'), isTrue);
      expect(written(), contains('<coordinates>78.04,27.17,0</coordinates>'));
    });

    test('no description means no empty balloon on the rig', () async {
      await kml.dropPin(lat: 1, lng: 2);

      expect(written(), isNot(contains('<description>')));
    });

    test('a description becomes the info balloon', () async {
      await kml.dropPin(
        lat: 41.9,
        lng: 12.5,
        name: 'Rome',
        description: 'Founded in 753 BC.',
      );

      expect(written(), contains('<description>Founded in 753 BC.</description>'));
    });

    // Copilot writes these descriptions itself, so they are free text: an
    // apostrophe would break out of the single-quoted `echo '...'` wrapper and
    // an ampersand would break the KML. htmlEscape neutralises both BEFORE the
    // shell escaping runs, so no '\'' dance should be needed at all.
    test('free-text descriptions survive both the XML and the shell', () async {
      await kml.dropPin(
        lat: 41.9,
        lng: 12.5,
        description: "Rome's R&D district, 5 < 6.",
      );

      expect(written(), contains('&#39;')); // the apostrophe
      expect(written(), contains('&amp;')); // the ampersand
      expect(written(), contains('&lt;')); // the less-than
      expect(written(), isNot(contains(r"'\''"))); // nothing reached shell raw
    });

    test('pin names are escaped too', () async {
      await kml.dropPin(lat: 0, lng: 0, name: "Ben & Jerry's");

      expect(written(), contains('<name>Ben &amp; Jerry&#39;s</name>'));
    });

    test('with no iconHref it uses the built-in pushpin', () async {
      await kml.dropPin(lat: 0, lng: 0);

      // Rigs without internet can't fetch mapfiles.google.com icons.
      expect(written(), isNot(contains('<Icon>')));
    });
  });

  test('cleanKML removes the files and their kmls.txt lines', () async {
    await kml.cleanKML();

    expect(rig.commands.length, 2);
    expect(written(), contains('rm -f /var/www/html/kml/lgquickrig_*.kml'));
    expect(rig.commands[1], contains("sed -i '/lgquickrig/d'"));
  });

  test('groundOverlay uploads the image before referencing it', () async {
    await kml.groundOverlay(
      imageBytes: [1, 2, 3],
      imageName: 'map.png',
      north: 1,
      south: 0,
      east: 1,
      west: 0,
    );

    expect(rig.uploads.single.path, '/var/www/html/map.png');
    expect(rig.uploads.single.bytes, [1, 2, 3]);
    expect(written(), contains('<href>http://192.168.2.2:81/map.png</href>'));
  });
}
