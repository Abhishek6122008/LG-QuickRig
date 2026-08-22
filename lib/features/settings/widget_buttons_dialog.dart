import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme/app_spacing.dart';
import '../../shared/widgets/busy_button.dart';

/// Picks the actions shown on the two Android home-screen widgets.
///
/// The keys below are an untyped cross-language contract: they must match
/// `CATALOG` in `LGHomeWidgetProvider.kt`. A key that exists on only one side
/// silently renders a blank widget cell.
class WidgetButtonsDialog extends StatefulWidget {
  const WidgetButtonsDialog({super.key});

  static const actions = {
    'clean': 'Clean KML',
    'relaunch': 'Relaunch',
    'reboot': 'Reboot',
    'shutdown': 'Shutdown',
    'sync': 'Sync',
    'overlay': 'Image Overlay',
    'flyto': 'Fly To',
    'orbit': 'Orbit',
    'pin': 'Drop Pin',
  };

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const WidgetButtonsDialog(),
    );
  }

  @override
  State<WidgetButtonsDialog> createState() => _WidgetButtonsDialogState();
}

class _WidgetButtonsDialogState extends State<WidgetButtonsDialog> {
  List<String> _home = ['clean', 'relaunch', 'reboot', 'shutdown'];
  List<String> _status = ['flyto', 'orbit', 'overlay'];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final home = await platformCommandsChannel
          .invokeListMethod<String>('getWidgetButtons', {'widget': 'home'});
      if (home != null && home.length == 4) _home = List.of(home);
      final status = await platformCommandsChannel
          .invokeListMethod<String>('getWidgetButtons', {'widget': 'status'});
      if (status != null && status.length == 3) _status = List.of(status);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await platformCommandsChannel.invokeMethod(
          'saveWidgetButtons', {'widget': 'home', 'buttons': _home});
      await platformCommandsChannel.invokeMethod(
          'saveWidgetButtons', {'widget': 'status', 'buttons': _status});
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // Was a silent catch that only cleared the spinner — the user retried
      // the same tap forever with no idea why nothing happened.
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save: $e';
        });
      }
    }
  }

  List<Widget> _section(String title, List<String> keys) => [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(title, style: Theme.of(context).textTheme.labelLarge),
          ),
        ),
        ...List.generate(keys.length, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: DropdownButtonFormField<String>(
              initialValue: keys[i],
              decoration: InputDecoration(
                labelText: 'Button ${i + 1}',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: WidgetButtonsDialog.actions.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: _saving ? null : (v) => setState(() => keys[i] = v!),
            ),
          );
        }),
      ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Widget buttons'),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ..._section('Command Bar (4×1)', _home),
                  const SizedBox(height: AppSpacing.sm),
                  ..._section('Live Status (2×2)', _status),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        BusyButton(
          busy: _saving,
          onPressed: _loading ? null : _save,
          label: const Text('Apply'),
        ),
      ],
    );
  }
}
