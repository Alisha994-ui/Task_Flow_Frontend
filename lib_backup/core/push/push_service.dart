import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../screens/manager/task_detail_screen.dart';
import '../../screens/notifications/notification_list_screen.dart';
import '../../services/device_token_service.dart';

/// Lets a push open a screen even though no widget is in scope at the
/// time. MaterialApp must be given this key.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Runs in its own isolate when a push arrives and the app is dead or in
/// the background. Android draws the notification itself from the
/// `notification` block, so there is nothing to do here - but Firebase
/// requires the handler to exist and to be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Deliberately empty.
}

/// Push notifications, start to finish:
/// permission -> device token -> Django -> Firebase -> back here -> the
/// right screen.
class PushService {
  const PushService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'taskflow_default',
    'TaskFlow',
    description: 'Task assignments, comments and deadline reminders',
    importance: Importance.high,
  );

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _ready = false;

  /// Call once from main(), before runApp.
  static Future<void> init() async {
    if (_ready) {
      return;
    }

    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // Android 13+ asks the person; older versions grant it silently.
    await FirebaseMessaging.instance.requestPermission();

    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _openFromPayload(response.payload);
      },
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // App open and on screen: Android does not draw a banner by itself,
    // so draw one.
    FirebaseMessaging.onMessage.listen(_showWhileOpen);

    // App open but in the background, and the person taps the banner.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _openFromData(message.data);
    });

    // App was closed and the tap is what started it.
    final RemoteMessage? initial =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initial != null) {
      // Wait for the first frame, otherwise the navigator is not ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openFromData(initial.data);
      });
    }

    _ready = true;
  }

  /// Tell Django which device this is. Call it right after a successful
  /// login - the token belongs to a person, not to an install.
  static Future<void> registerDevice() async {
    try {
      final String? token = await FirebaseMessaging.instance.getToken();

      if (token == null || token.isEmpty) {
        return;
      }

      await DeviceTokenService.register(token);

      // Firebase rotates tokens on its own schedule.
      FirebaseMessaging.instance.onTokenRefresh.listen((String fresh) {
        DeviceTokenService.register(fresh).catchError((Object _) {});
      });
    } catch (e) {
      debugPrint('Push registration failed: $e');
    }
  }

  /// Call on logout, so the next person on this phone does not receive
  /// the previous one's notifications.
  static Future<void> unregisterDevice() async {
    try {
      final String? token = await FirebaseMessaging.instance.getToken();

      if (token != null && token.isNotEmpty) {
        await DeviceTokenService.unregister(token);
      }

      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('Push unregistration failed: $e');
    }
  }

  // ------------------------------------------------------------ internals

  static Future<void> _showWhileOpen(RemoteMessage message) async {
    final RemoteNotification? note = message.notification;

    if (note == null) {
      return;
    }

    // Keep the bell badge honest without waiting for a refresh.
    final BuildContext? context = appNavigatorKey.currentContext;

    if (context != null && context.mounted) {
      context.read<NotificationProvider>().refresh();
    }

    await _local.show(
      message.hashCode,
      note.title,
      note.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['task_id']?.toString(),
    );
  }

    static void _openFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) {
      _openFromData(const <String, dynamic>{});

      return;
    }

    _openFromData(<String, dynamic>{'task_id': payload});
  }

  /// Django sends `task_id` in the data block. With it we open the task;
  /// without it we fall back to the notifications list.
  static void _openFromData(Map<String, dynamic> data) {
    final NavigatorState? navigator = appNavigatorKey.currentState;
    final BuildContext? context = appNavigatorKey.currentContext;

    if (navigator == null || context == null) {
      return;
    }

    final int? taskId = int.tryParse(data['task_id']?.toString() ?? '');

    // An employee may only change their own task's status, so the task
    // screen opens read-only for them - same rule as everywhere else.
    final bool canManage =
        !(context.read<AuthProvider>().user?.isEmployee ?? false);

    if (taskId == null) {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => NotificationListScreen(canManageTasks: canManage),
        ),
      );

      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(
          taskId: taskId,
          canManage: canManage,
        ),
      ),
    );
  }
}
