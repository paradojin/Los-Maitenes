import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/staff_session.dart';
import 'theme.dart';

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Los Maitenes',
      theme: AppTheme.lightTheme,
      home: ValueListenableBuilder<String?>(
        valueListenable: StaffSession.name,
        builder: (_, staff, __) {
          if (staff == null || staff.isEmpty) return const LoginScreen();
          return const MainShell();
        },
      ),
    );
  }
}
