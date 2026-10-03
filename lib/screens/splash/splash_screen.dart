import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final authProvider = context.read<AuthProvider>();

    final isAuthenticated = await authProvider.restoreSession();

    if (!mounted) return;

    if (isAuthenticated) {
      final route = AppRoutes.dashboardForRole(
        authProvider.role ?? '',
      );

      Navigator.pushReplacementNamed(
        context,
        route,
      );
    } else {
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.login,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 72,
            ),
            SizedBox(height: 20),
            Text(
              'TaskFlow',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}