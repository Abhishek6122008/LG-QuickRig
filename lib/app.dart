import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_shell.dart';
import 'core/di/service_locator.dart';
import 'core/ssh/ssh_client.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/credentials_repository.dart';
import 'features/lg_commands/camera_action_dialog.dart';
import 'features/lg_commands/image_overlay_dialog.dart';

/// Shared so the Linux tray can open the camera dialogs on the app window.
final navigatorKey = GlobalKey<NavigatorState>();

class LGQuickRigApp extends StatefulWidget {
  const LGQuickRigApp({super.key});

  @override
  State<LGQuickRigApp> createState() => _LGQuickRigAppState();
}

class _LGQuickRigAppState extends State<LGQuickRigApp> {
  static const _channel = MethodChannel('com.liqtech.lg_quickrig/widget');

  final _navKey = navigatorKey;

  bool _cameraOnly = false;

  @override
  void initState() {
    super.initState();

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openCamera' && call.arguments is String) {
        _openCamera(call.arguments as String, cameraOnly: false);
      }
      return null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPending());
  }

  Future<void> _checkPending() async {
    try {
      final action = await _channel.invokeMethod<String>('getPendingCameraAction');
      if (action != null) {
        setState(() => _cameraOnly = true);
        _openCamera(action, cameraOnly: true);
      }
    } catch (_) {}
  }

  /// Dialog-only launches run in a fresh engine with no SSH session yet —
  /// dial in with the saved credentials so the dialog's Send just works.
  Future<void> _connectSilently() async {
    try {
      final ssh = sl<LGSSHClient>();
      if (ssh.isConnected) return;
      final creds = await sl<CredentialsRepository>().load();
      if (creds != null && creds.host.isNotEmpty) await ssh.connect(creds);
    } catch (_) {
      // Dialog still opens; its actions will surface the error.
    }
  }

  Future<void> _openCamera(String action, {required bool cameraOnly}) async {
    if (cameraOnly) await _connectSilently();
    final ctx = _navKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    // 'pin' lives inside the overlay dialog now; old widgets may still send it.
    if (action == 'overlay' || action == 'pin') {
      await ImageOverlayDialog.show(ctx);
    } else {
      await CameraActionDialog.show(ctx, action);
    }

    if (cameraOnly) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'LG QuickRig',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      home: _cameraOnly
          ? const Scaffold(backgroundColor: Colors.transparent)
          : const AppShell(),
    );
  }
}
