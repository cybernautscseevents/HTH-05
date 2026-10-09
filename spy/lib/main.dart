import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/auth_provider.dart';
import 'src/notification_provider.dart';
import 'src/theme.dart';
import 'src/screens/role_select_screen.dart';
import 'src/screens/staff_shell.dart';
import 'src/screens/doctor_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const SaathiStaffApp(),
    ),
  );
}

class SaathiStaffApp extends StatelessWidget {
  const SaathiStaffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saathi Staff Portal',
      theme: buildSaathiTheme(),
      debugShowCheckedModeBanner: false,
      routes: {'/staff/patients': (_) => const StaffShell(initialIndex: 1)},
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(
        backgroundColor: saathiCream,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(saathiGreen),
          ),
        ),
      );
    }

    if (!authProvider.isAuthenticated) {
      return const RoleSelectScreen();
    }

    final role = authProvider.role?.toLowerCase();
    if (role == 'doctor') {
      return const DoctorHomeScreen();
    } else if (role == 'receptionist' || role == 'admin') {
      return const StaffShell();
    } else {
      return const RoleSelectScreen();
    }
  }
}
