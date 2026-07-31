import 'package:flutter/widgets.dart';

import '../../services/lg_orbit_controller.dart';

/// Reads the rig's current camera target and fills the given controllers.
/// Returns an error message on failure, null on success. Shared by the Fly
/// To/Orbit dialog and the Overlay dialog's "Use current view" button.
Future<String?> fillCurrentView(
  LGOrbitController orbit, {
  required bool connected,
  required TextEditingController lat,
  required TextEditingController lng,
  TextEditingController? range,
}) async {
  if (!connected) return 'Not connected to the LG rig.';
  final target = await orbit.currentTarget();
  if (target == null) return 'Could not read the current view.';
  lat.text = target.lat.toStringAsFixed(6);
  lng.text = target.lng.toStringAsFixed(6);
  if (range != null && target.range != null) {
    range.text = target.range!.toStringAsFixed(0);
  }
  return null;
}
