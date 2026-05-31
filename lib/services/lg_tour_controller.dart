import 'lg_command_service.dart';

/// Controls KML tour playback on the Liquid Galaxy cluster.
///
/// LG tours are triggered by writing a command to `~/gs_cmd`, a file
/// monitored by the `gsync` process running on the master node.
///
/// Supported commands (from the standard LG scripts):
///   `gplaytour=NAME`  — start or switch to the named tour
///   gplaytour=        — stop the current tour
///
/// If your LG installation uses a different mechanism (e.g. xdotool key
/// injection or a REST endpoint), replace the `_sendGsCmd` implementation.
class LGTourController {
  final LGCommandService _commandService;

  LGTourController(this._commandService);

  // ---------------------------------------------------------------------------
  // Tour control
  // ---------------------------------------------------------------------------

  /// Starts (or switches to) the KML tour named [tourName].
  ///
  /// [tourName] must match the `name` value inside `gx:Tour` in the loaded KML.
  Future<void> startTour(String tourName) async {
    await _sendGsCmd('gplaytour=$tourName');
  }

  /// Stops the currently playing tour and returns to normal navigation.
  Future<void> stopTour() async {
    await _sendGsCmd('gplaytour=');
  }

  /// Exits the tour and clears the gs_cmd file.
  Future<void> exitTour() async {
    await _sendGsCmd('gxplaytour=');
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  /// Writes [cmd] to a temp file then atomically moves it to `~/gs_cmd`.
  ///
  /// The atomic move prevents the gsync watcher from reading a partial write.
  Future<void> _sendGsCmd(String cmd) async {
    await _commandService.execute(
      "echo '$cmd' > /tmp/gs_cmd && mv /tmp/gs_cmd ~/gs_cmd",
    );
  }
}
