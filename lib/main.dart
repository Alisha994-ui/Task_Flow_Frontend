
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/network/connectivity_watcher.dart';
import 'core/push/push_service.dart';
import 'core/utils/coach_observer.dart';
import 'core/theme/app_theme.dart';
import 'providers/admin_dashboard_provider.dart';
import 'providers/assistant_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/coach_provider.dart';
import 'widgets/coach_overlay.dart';
import 'providers/manager_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/project_provider.dart';
import 'providers/task_provider.dart';
import 'providers/team_provider.dart';
import 'providers/time_log_provider.dart';
import 'providers/user_provider.dart';
import 'routes/app_routes.dart';
import 'screens/profile/profile_screen.dart' show signOut;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // BUG-01: a release build must be built with an https API address
  // (--dart-define=API_BASE_URL=https://...). Fail loudly, not silently.
  if (!ApiClient.isConfigured) {
    runApp(const _MisconfiguredBuildApp());
    return;
  }

  await PushService.init();

  ConnectivityWatcher.start();

  await SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) {
            final authProvider = AuthProvider();

            ApiClient.onConnectionRestored =
                authProvider.clearRestoredFromCache;

            // The server rejected the saved session for real (not just a
            // dropped connection): sign out and go to the login screen
            // instead of leaving every screen showing errors.
            bool handlingExpiry = false;

            ApiClient.onSessionExpired = () async {
              final BuildContext? ctx = appNavigatorKey.currentContext;

              if (handlingExpiry ||
                  ctx == null ||
                  !authProvider.isAuthenticated) {
                return;
              }

              handlingExpiry = true;

              try {
                await signOut(ctx);

                ApiClient.sessionExpired = false;

                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Your session has expired. Please sign in again.',
                        ),
                      ),
                    );
                }
              } finally {
                handlingExpiry = false;
              }
            };

            return authProvider;
          },
        ),
        ChangeNotifierProvider<AssistantProvider>(
          create: (_) => AssistantProvider(),
        ),
        ChangeNotifierProvider<CoachProvider>(
          create: (_) => CoachProvider(),
        ),
        ChangeNotifierProvider<AdminDashboardProvider>(
          create: (_) => AdminDashboardProvider(),
        ),
        ChangeNotifierProvider<ProjectProvider>(
          create: (_) => ProjectProvider(),
        ),
        ChangeNotifierProvider<ManagerProvider>(
          create: (_) => ManagerProvider(),
        ),
        ChangeNotifierProvider<TaskProvider>(
          create: (_) => TaskProvider(),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(),
        ),
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
        ),
        ChangeNotifierProvider<TeamProvider>(
          create: (_) => TeamProvider(),
        ),
        ChangeNotifierProvider<TimeLogProvider>(
          create: (_) => TimeLogProvider(),
        ),
      ],
      child: const TaskFlowApp(),
    ),
  );
}

class _MisconfiguredBuildApp extends StatelessWidget {
  const _MisconfiguredBuildApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'This build has no secure server address.\n\n'
                'Rebuild with --dart-define=API_BASE_URL=https://<your-api>/api',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      navigatorObservers: <NavigatorObserver>[
        CoachObserver(context.read<CoachProvider>()),
      ],
      builder: (BuildContext context, Widget? child) {
        return Stack(
          children: <Widget>[
            child ?? const SizedBox.shrink(),
            const CoachOverlay(),
          ],
        );
      },
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
