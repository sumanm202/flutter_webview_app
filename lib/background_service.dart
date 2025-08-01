import 'dart:async';
import 'dart:io';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_webview_app/session_manager.dart';

class BackgroundService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // Configure notification settings for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'session_service',
      'Session Management Service',
      description: 'Keeps your session alive',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: false,
        notificationChannelId: 'session_service',
        initialNotificationTitle: 'First Finance',
        initialNotificationContent: 'Keeping your session alive',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    service.startService();
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Initialize session manager
    SessionManager.initCookieManager();

    // Start periodic session refresh
    Timer.periodic(const Duration(minutes: 10), (timer) async {
      try {
        print("🔄 Background service: Refreshing session...");

        // Check if session is valid
        bool isValid = await SessionManager.checkSession();

        if (isValid) {
          // Refresh session
          await SessionManager.refreshSession();
          await SessionManager.saveCookies('https://firstfinance.xpresspaisa.in');
          print("✅ Background service: Session refreshed successfully");
        } else {
          print("❌ Background service: Session invalid");
        }
      } catch (e) {
        print("❌ Background service error: $e");
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    return true;
  }
}