import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_logger.dart';

// Firebase background message handler must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppTracker.info("Handling a background message: ${message.messageId}");
  // We can do background offline queue syncs here if needed
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService();
});

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permissions
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    AppTracker.info('User granted FCM permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get the FCM token for this device
      final token = await _fcm.getToken();
      AppTracker.info('FCM Token: $token');
      // In a real app, send this token to the backend using AgentApi / FarmerApi

      // Setup local notifications for foreground messages
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings();
      const initSettings = InitializationSettings(android: androidInit, iOS: darwinInit);
      await _localNotifications.initialize(settings: initSettings);

      // Listen to foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        AppTracker.info('Received foreground message: ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // Handle message open (from background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppTracker.info('Opened app from notification: ${message.notification?.title}');
        // You could use GoRouter to navigate to a specific screen based on data payload
      });

      _isInitialized = true;
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'agriagent_channel_id',
      'AgriAgent Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    const details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
    );
  }
}
