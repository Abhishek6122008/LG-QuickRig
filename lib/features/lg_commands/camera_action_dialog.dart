import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../core/ssh/ssh_client.dart';
import '../../services/lg_orbit_controller.dart';
import 'current_view.dart';

class CameraActionDialog extends StatefulWidget {

  final String action;

  const CameraActionDialog({super.key, required this.action});

  static Future<void> show(BuildContext context, String action) {
    return showDialog(
      context: context,
      builder: (_) => CameraActionDialog(action: action),
    );
  }

  @override
  State<CameraActionDialog> createState() => _CameraActionDialogState();
}

class _CameraActionDialogState extends State<CameraActionDialog> {
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _rangeCtrl = TextEditingController(text: '10000');

  final _orbit = sl<LGOrbitController>();
  final _ssh = sl<LGSSHClient>();

  bool _busy = false;
  String? _error;

  bool get _isOrbit => widget.action == 'orbit';
  String get _title => _isOrbit ? 'Orbit' : 'Fly To';

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _rangeCtrl.dispose();
    super.dispose();
  }

  Future<void> _useCurrentView() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await fillCurrentView(
      _orbit,
      connected: _ssh.isConnected,
      lat: _latCtrl,
      lng: _lngCtrl,
      range: _rangeCtrl,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  Future<void> _run() async {
    final lat = double.tryParse(_latCtrl.text.trim());
    final lng = double.tryParse(_lngCtrl.text.trim());
    final range = double.tryParse(_rangeCtrl.text.trim());

    if (!_isOrbit && (lat == null || lng == null)) {
      setState(() => _error = 'Enter valid latitude and longitude.');
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
      if (_isOrbit) {
        final started = await _orbit.orbitPlay(lat: lat, lng: lng, range: range);
        if (!started && mounted) {
          setState(() {
            _busy = false;
            _error = _orbit.isOrbitPlaying
                ? 'An orbit is already running.'
                : 'Could not read the current view — enter coordinates.';
          });
          return;
        }
      } else {
        await _orbit.flyTo(lat: lat!, lng: lng!, range: range ?? 10000);
      }
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _latCtrl,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Latitude',
              hintText: 'e.g. 27.1751',
            ),
          ),
          TextField(
            controller: _lngCtrl,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: const InputDecoration(
              labelText: 'Longitude',
              hintText: 'e.g. 78.0421',
            ),
          ),
          TextField(
            controller: _rangeCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Range (metres)',
            ),
          ),
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
              : Text(_isOrbit ? 'Start Orbit' : 'Fly'),
        ),
      ],
    );
  }
}
