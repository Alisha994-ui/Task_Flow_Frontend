import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase has to be up before the first frame, otherwise a push that
  // launched the app is lost.
  await PushService.init();

  // This is a phone-first business app with no landscape layouts; in
  // landscape the keyboard alone can take up most of the short screen
  // height (see sign-in). Locking portrait is simpler and more reliable
  // than trying to make every screen reflow for landscape.
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<AssistantProvider>(
          create: (_) => AssistantProvider(),
        ),
        ChangeNotifierProvider<CoachProvider>(create: (_) => CoachProvider()),
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
      navigatorKey: appNavigatorKey,

      // Opening a screen moves the walkthrough along by itself, so a
      // step that says "tap the + button" does not also need a tap on
      // Next.
      navigatorObservers: <NavigatorObserver>[
        CoachObserver(context.read<CoachProvider>()),
      ],

      // The walkthrough draws over every route, not inside one: it
      // dims the screen, lights up the control a step is about, and
      // puts the bubble next to it. The dim layer ignores taps, so the
      // real button underneath still works.
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
