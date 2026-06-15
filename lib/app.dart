import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'features/dashboard/dashboard_screen.dart';
import 'features/lg_commands/camera_action_dialog.dart';

class LGQuickRigApp extends StatefulWidget {
  const LGQuickRigApp({super.key});

  @override
  State<LGQuickRigApp> createState() => _LGQuickRigAppState();
}

class _LGQuickRigAppState extends State<LGQuickRigApp> {
  static const _channel = MethodChannel('com.liqtech.lg_quickrig/widget');

  final _navKey = GlobalKey<NavigatorState>();

  /// True when the app was cold-launched purely to show a camera dialog from
  /// the home screen widget. In that mode we render a transparent barrier
  /// instead of the dashboard, so the dialog floats over the launcher.
  bool _cameraOnly = false;

  @override
  void initState() {
    super.initState();

    // Warm start: the widget launched us while already running.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'openCamera' && call.arguments is String) {
        _openCamera(call.arguments as String, cameraOnly: false);
      }
      return null;
    });

    // Cold start: ask the native side whether a widget button launched us.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPending());
  }

  Future<void> _checkPending() async {
    try {
      final action = await _channel.invokeMethod<String>('getPendingCameraAction');
      if (action != null) {
        setState(() => _cameraOnly = true);
        _openCamera(action, cameraOnly: true);
      }
    } catch (_) {
      // No native handler (e.g. non-Android) — ignore.
    }
  }

  Future<void> _openCamera(String action, {required bool cameraOnly}) async {
    final ctx = _navKey.currentContext;
    if (ctx == null) return;
    await CameraActionDialog.show(ctx, action);
    // When this was a camera-only launch, close the app once the dialog is
    // dismissed so the user returns straight to their home screen.
    if (cameraOnly) SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'LG QuickRig',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8), // Google blue
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F9FA),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE0E3E7)),
          ),
        ),
      ),
      home: _cameraOnly
          ? const Scaffold(backgroundColor: Colors.transparent)
          : const DashboardScreen(),
    );
  }
}
