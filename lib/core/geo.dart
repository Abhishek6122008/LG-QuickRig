/// Coordinate bounds check, shared by every path that can reach the rig's
/// camera: the two command dialogs and the Copilot's tool dispatcher.
///
/// It previously existed only inside the overlay dialog, which left the two
/// paths that most need it unguarded — a typo in the Fly To field, and a
/// hallucinated `fly_to` argument from the model.
///
/// Returns null when the pair is usable, or a message to show the user.
String? validateLatLng(double? lat, double? lng) {
  if (lat == null || lng == null) {
    return 'Enter valid latitude and longitude.';
  }
  if (lat.isNaN || lng.isNaN || lat.isInfinite || lng.isInfinite) {
    return 'Latitude and longitude must be real numbers.';
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return 'Latitude ±90, longitude ±180.';
  }
  return null;
}
