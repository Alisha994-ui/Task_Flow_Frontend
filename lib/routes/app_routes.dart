import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/admin/admin_panel_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/employee/employee_panel_screen.dart';
import '../screens/manager/manager_panel_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/team_lead/team_lead_panel_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';

  static const String adminDashboard = '/admin-dashboard';
  static const String projectManagerDashboard = '/project-manager-dashboard';
  static const String teamLeadDashboard = '/team-lead-dashboard';
  static const String employeeDashboard = '/employee-dashboard';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
        );

      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );

      case adminDashboard:
        return MaterialPageRoute(
          builder: (_) => const AdminPanelScreen(),
        );

      case projectManagerDashboard:
        return MaterialPageRoute(
          builder: (context) {
            final UserModel? user = context.read<AuthProvider>().user;

            return ManagerPanelScreen(
              managerId: user?.id ?? 0,
              managerName: user?.fullName ?? '',
            );
          },
        );

      case teamLeadDashboard:
        return MaterialPageRoute(
          builder: (context) {
            final UserModel? user = context.read<AuthProvider>().user;

            return TeamLeadPanelScreen(
              userId: user?.id ?? 0,
              userName: user?.fullName ?? '',
            );
          },
        );

      case employeeDashboard:
        return MaterialPageRoute(
          builder: (context) {
            final UserModel? user = context.read<AuthProvider>().user;

            return EmployeePanelScreen(
              userId: user?.id ?? 0,
              userName: user?.fullName ?? '',
            );
          },
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );
    }
  }

  static String dashboardForRole(String role) {
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return adminDashboard;

      case 'PROJECT_MANAGER':
        return projectManagerDashboard;

      case 'TEAM_LEAD':
        return teamLeadDashboard;

      case 'EMPLOYEE':
        return employeeDashboard;

      default:
        return login;
    }
  }
}