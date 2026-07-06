import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/di/service_locator.dart';
import '../../core/ssh/ssh_client.dart';
import '../../services/lg_kml_controller.dart';
import '../../services/lg_orbit_controller.dart';

class ImageOverlayDialog extends StatefulWidget {
  const ImageOverlayDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ImageOverlayDialog(),
    );
  }

  @override
  State<ImageOverlayDialog> createState() => _ImageOverlayDialogState();
}

class _Marker {
  final String label;
  final IconData icon;
  final Color color;
  final String kmlColor; // aabbggrr
  final String? iconHref; // null = built-in pushpin (works offline)
  const _Marker(this.label, this.icon, this.color, this.kmlColor,
      [this.iconHref]);
}

class _ImageOverlayDialogState extends State<ImageOverlayDialog> {
  static const _markers = [
    _Marker('Red Pin', Icons.place, Color(0xFFD93025), 'ff0000ff'),
    _Marker('Yellow Pin', Icons.place, Color(0xFFF9AB00), 'ff00ffff'),
    _Marker('Green Pin', Icons.place, Color(0xFF1E8E3E), 'ff00ff00'),
    _Marker('Blue Pin', Icons.place, Color(0xFF1A73E8), 'ffff0000'),
    _Marker('Flag', Icons.flag, Color(0xFFE8710A), 'ffffffff',
        'http://maps.google.com/mapfiles/kml/shapes/flag.png'),
    _Marker('Target', Icons.gps_fixed, Color(0xFF9334E6), 'ffffffff',
        'http://maps.google.com/mapfiles/kml/shapes/target.png'),
  ];

  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController(text: '1');

  final _kml = sl<LGKMLController>();
  final _orbit = sl<LGOrbitController>();
  final _ssh = sl<LGSSHClient>();

  /// 0 = image overlay, 1.._markers.length = marker choice.
  int _selected = 0;
  XFile? _image;
  bool _busy = false;
  String? _error;

  _Marker? get _marker => _selected == 0 ? null : _markers[_selected - 1];

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentView() async {
    if (!_ssh.isConnected) {
      setState(() => _error = 'Not connected to the LG rig.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final target = await _orbit.currentTarget();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (target == null) {
        _error = 'Could not read the current view.';
      } else {
        _latCtrl.text = target.lat.toStringAsFixed(6);
        _lngCtrl.text = target.lng.toStringAsFixed(6);
      }
    });
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = picked);
  }

  Future<void> _run() async {
    final marker = _marker;
    if (marker == null && _image == null) {
      setState(() => _error = 'Pick an image first.');
      return;
    }
    if (!_ssh.isConnected) {
      setState(() => _error = 'Not connected to the LG rig.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      var lat = double.tryParse(_latCtrl.text.trim());
      var lng = double.tryParse(_lngCtrl.text.trim());
      final sizeKm = double.tryParse(_sizeCtrl.text.trim());

      // Blank coordinates → place it wherever the camera is right now.
      if (lat == null || lng == null) {
        final target = await _orbit.currentTarget();
        if (target == null) {
          setState(() {
            _busy = false;
            _error = 'Could not read the current view — enter coordinates.';
          });
          return;
        }
        lat = target.lat;
        lng = target.lng;
      }
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        setState(() {
          _busy = false;
          _error = 'Latitude ±90, longitude ±180.';
        });
        return;
      }

      if (marker != null) {
        await _kml.dropPin(
          lat: lat,
          lng: lng,
          name: marker.label,
          kmlColor: marker.kmlColor,
          iconHref: marker.iconHref,
        );
        await _orbit.flyTo(lat: lat, lng: lng, range: 5000);
        if (mounted) Navigator.of(context).pop();
        return;
      }

      if (sizeKm == null || sizeKm <= 0) {
        setState(() {
          _busy = false;
          _error = 'Enter a size in km (e.g. 1).';
        });
        return;
      }

      // Center + size → LatLonBox. 1° latitude ≈ 111.32 km; longitude
      // degrees shrink by cos(lat), clamped so the poles don't divide by ~0.
      final dLat = sizeKm / 2 / 111.32;
      final cosLat =
          math.max(math.cos(lat * math.pi / 180).abs(), 0.01);
      final dLng = sizeKm / 2 / (111.32 * cosLat);

      final bytes = await _image!.readAsBytes();
      final name = 'overlay_${DateTime.now().millisecondsSinceEpoch}.png';
      await _kml.groundOverlay(
        imageBytes: bytes,
        imageName: name,
        north: lat + dLat,
        south: lat - dLat,
        east: lng + dLng,
        west: lng - dLng,
      );
      await _orbit.flyTo(lat: lat, lng: lng);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Failed: $e';
        });
      }
    }
  }

  Widget _numField(TextEditingController c, String label, {String? hint}) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Overlay'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.image, size: 18),
                label: const Text('Image'),
                selected: _selected == 0,
                onSelected:
                    _busy ? null : (_) => setState(() => _selected = 0),
              ),
              ...List.generate(_markers.length, (i) {
                final m = _markers[i];
                return ChoiceChip(
                  avatar: Icon(m.icon, size: 18, color: m.color),
                  label: Text(m.label),
                  selected: _selected == i + 1,
                  onSelected:
                      _busy ? null : (_) => setState(() => _selected = i + 1),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          if (_selected == 0)
            OutlinedButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.image),
              label: Text(_image == null ? 'Pick image' : _image!.name),
            ),
          _numField(_latCtrl, 'Latitude', hint: 'blank = current view'),
          _numField(_lngCtrl, 'Longitude', hint: 'blank = current view'),
          if (_selected == 0) _numField(_sizeCtrl, 'Size (km)'),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _busy ? null : _useCurrentView,
              icon: const Icon(Icons.my_location, size: 18),
              label: const Text('Use current view'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _run,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send'),
        ),
      ],
    );
  }
}
