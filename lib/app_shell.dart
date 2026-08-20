import 'package:flutter/material.dart';

import 'features/copilot/copilot_sheet.dart';
import 'features/dashboard/dashboard_controller.dart';
import 'features/dashboard/rig_view.dart';
import 'features/lg_commands/camera_view.dart';
import 'features/settings/settings_screen.dart';
import 'shared/widgets/connection_status_badge.dart';

/// Responsive shell: a bottom [NavigationBar] on phones, a side
/// [NavigationRail] once there's room — the standard Material 3 adaptive
/// navigation pattern, built on the framework's own widgets.
///
/// The app previously ran as a single phone-shaped ListView, which on a
/// maximised Linux desktop window stretched two tile columns across 1080px.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  /// Below this the rail has no room to sit beside the content.
  static const double railBreakpoint = 700;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _ctrl = DashboardController();
  int _index = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dns_outlined),
      selectedIcon: Icon(Icons.dns),
      label: 'Rig',
    ),
    NavigationDestination(
      icon: Icon(Icons.travel_explore_outlined),
      selectedIcon: Icon(Icons.travel_explore),
      label: 'Camera',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _page(int i) => switch (i) {
        0 => RigView(ctrl: _ctrl),
        1 => CameraView(ctrl: _ctrl),
        _ => SettingsView(onSaved: (creds) => _ctrl.connect(creds: creds)),
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= AppShell.railBreakpoint;

    return ListenableBuilder(
      listenable: _ctrl,
      builder: (context, _) {
        final body = _page(_index);

        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'LG QuickRig',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            actions: [
              if (_ctrl.isBusy || _ctrl.isAutoConnecting)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: ConnectionStatusBadge(state: _ctrl.connectionState),
                  ),
                ),
            ],
          ),
          // Settings is a form; a FAB floating over the Save button is noise.
          floatingActionButton: _index == 2
              ? null
              : FloatingActionButton(
                  tooltip: 'Copilot',
                  onPressed: () => CopilotSheet.show(context),
                  child: const Icon(Icons.auto_awesome),
                ),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final d in _destinations)
                          NavigationRailDestination(
                            icon: d.icon,
                            selectedIcon: d.selectedIcon,
                            label: Text(d.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1, thickness: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: _destinations,
                ),
        );
      },
    );
  }
}
