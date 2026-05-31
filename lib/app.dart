import 'package:flutter/material.dart';

import 'features/dashboard/dashboard_screen.dart';

class LGQuickRigApp extends StatelessWidget {
  const LGQuickRigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LG QuickRig',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00B4D8), // Liquid Galaxy teal
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
