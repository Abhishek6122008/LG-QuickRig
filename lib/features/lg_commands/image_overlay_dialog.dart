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

class _ImageOverlayDialogState extends State<ImageOverlayDialog> {
  final _northCtrl = TextEditingController();
  final _southCtrl = TextEditingController();
  final _eastCtrl = TextEditingController();
  final _westCtrl = TextEditingController();

  final _kml = sl<LGKMLController>();
  final _orbit = sl<LGOrbitController>();
  final _ssh = sl<LGSSHClient>();

  XFile? _image;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _northCtrl.dispose();
    _southCtrl.dispose();
    _eastCtrl.dispose();
    _westCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = picked);
  }

  Future<void> _run() async {
    final north = double.tryParse(_northCtrl.text.trim());
    final south = double.tryParse(_southCtrl.text.trim());
    final east = double.tryParse(_eastCtrl.text.trim());
    final west = double.tryParse(_westCtrl.text.trim());

    if (_image == null) {
      setState(() => _error = 'Pick an image first.');
      return;
    }
    if (north == null || south == null || east == null || west == null) {
      setState(() => _error = 'Enter all four bounds.');
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
      final bytes = await _image!.readAsBytes();
      final name = 'overlay_${DateTime.now().millisecondsSinceEpoch}.png';
      await _kml.groundOverlay(
        imageBytes: bytes,
        imageName: name,
        north: north,
        south: south,
        east: east,
        west: west,
      );
      await _orbit.flyTo(
        lat: (north + south) / 2,
        lng: (east + west) / 2,
      );
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

  Widget _boundField(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Image Overlay'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.image),
            label: Text(_image == null ? 'Pick image' : _image!.name),
          ),
          _boundField(_northCtrl, 'North'),
          _boundField(_southCtrl, 'South'),
          _boundField(_eastCtrl, 'East'),
          _boundField(_westCtrl, 'West'),
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
