import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/admin_dashboard_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/manager_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/project_provider.dart';
import 'providers/task_provider.dart';
import 'providers/team_provider.dart';
import 'providers/time_log_provider.dart';
import 'providers/user_provider.dart';
import 'routes/app_routes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<AdminDashboardProvider>(
          create: (_) => AdminDashboardProvider(),
        ),
        ChangeNotifierProvider<ProjectProvider>(
          create: (_) => ProjectProvider(),
        ),
        ChangeNotifierProvider<ManagerProvider>(
          create: (_) => ManagerProvider(),
        ),
        ChangeNotifierProvider<TaskProvider>(create: (_) => TaskProvider()),
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
        ),
        ChangeNotifierProvider<TeamProvider>(create: (_) => TeamProvider()),
        ChangeNotifierProvider<TimeLogProvider>(
          create: (_) => TimeLogProvider(),
        ),
      ],
      child: const TaskFlowApp(),
    ),
  );
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
