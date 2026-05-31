import 'lg_command_service.dart';

/// Manages KML files on the LG master node's built-in HTTP server.
///
/// The Liquid Galaxy browser stack polls `/var/www/html/kmls.txt` for a list
/// of KML URLs to load. Individual slave browsers also watch their own KML
/// files at `/var/www/html/kml/slave_N.kml`.
///
/// All paths follow the standard LG installation layout. If your cluster uses
/// a different web root, adjust [_kmlDir] and [_kmlsFile] accordingly.
class LGKMLController {
  final LGCommandService _commandService;

  static const _kmlDir = '/var/www/html/kml';
  static const _kmlsFile = '/var/www/html/kmls.txt';

  LGKMLController(this._commandService);

  // ---------------------------------------------------------------------------
  // KML file management
  // ---------------------------------------------------------------------------

  /// Writes [kml] to the master's web server under the file name
  /// `lgquickrig_[slave].kml`, replacing any previous content.
  ///
  /// Set [slave] to 1 for the master node's own browser.
  Future<void> sendKML(String kml, {int slave = 1}) async {
    final escaped = _shellEscape(kml);
    await _commandService.execute(
      "echo '$escaped' > $_kmlDir/lgquickrig_$slave.kml",
    );
  }

  /// Writes [kml] directly to the per-slave KML file on slave node [node].
  ///
  /// This is used when a KML must appear on a specific display in the array
  /// rather than the master's presentation layer.
  Future<void> sendSlaveKML(String kml, int node) async {
    final escaped = _shellEscape(kml);
    await _commandService.executeOnSlave(
      node,
      "echo '$escaped' > $_kmlDir/slave_$node.kml",
    );
  }

  /// Appends [url] to `kmls.txt` so the cluster loads it at next refresh.
  Future<void> addKMLReference(String url) async {
    await _commandService.execute("echo '$url' >> $_kmlsFile");
  }

  /// Removes all KML files written by LG QuickRig and cleans their references
  /// from `kmls.txt`.
  Future<void> cleanKML() async {
    // Delete all files written by this app.
    await _commandService.execute(
      "rm -f $_kmlDir/lgquickrig_*.kml 2>/dev/null; echo 'done'",
    );
    // Strip any lgquickrig URLs from the reference list.
    await _commandService.execute(
      "sed -i '/lgquickrig/d' $_kmlsFile 2>/dev/null || true",
    );
  }

  /// Clears ALL KML references from `kmls.txt`, effectively blanking every
  /// browser in the cluster. Use with care.
  Future<void> clearAllKMLReferences() async {
    await _commandService.execute('echo "" > $_kmlsFile');
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Escapes single-quotes in [content] so it can be safely passed to a
  /// shell single-quoted string: `echo '...'`.
  ///
  /// The pattern `'\''` closes the quote, inserts a literal `'`, then reopens
  /// the quote — this is the POSIX-standard way to embed single-quotes in a
  /// single-quoted shell string.
  String _shellEscape(String content) => content.replaceAll("'", r"'\''");
}
