import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Local notifications plugin initialization
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Android notification channel setup
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for important notifications.',
  importance: Importance.high,
  playSound: true,
);

/// Firebase background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 Background message: ${message.messageId}');
  print('📩 Background notification title: ${message.notification?.title}');
  print('📩 Background notification body: ${message.notification?.body}');
  print('📦 Background data: ${message.data}');
}

/// Entry point of the application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Request permissions
  await [
    Permission.camera,
    Permission.microphone,
    Permission.photos,
    Permission.storage,
    Permission.notification,
  ].request();

  runApp(const MyApp());
}

/// Root widget of the application
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

/// Splash screen that checks for stored session ID
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? sessionId = prefs.getString('PHPSESSID');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WebViewPage(sessionId: sessionId),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 150,
              height: 150,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

/// WebView page with login tracking, FCM handling, and session persistence
class WebViewPage extends StatefulWidget {
  final String? sessionId;
  const WebViewPage({super.key, this.sessionId});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  String? _fcmToken;
  String? _userId;

  @override
  void initState() {
    super.initState();
    initFCM();
  }

  /// Initializes Firebase Cloud Messaging and sets up local notifications
  Future<void> initFCM() async {
    const InitializationSettings initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await flutterLocalNotificationsPlugin.initialize(initSettings);

    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      _fcmToken = await FirebaseMessaging.instance.getToken();
      print("✅ FCM Token: $_fcmToken");

      if (_userId != null && _fcmToken != null) {
        await registerToken(_userId!, _fcmToken!);
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      print("🔔 Foreground notification received");
      print("📩 Title: ${notification?.title}");
      print("📩 Body: ${notification?.body}");
      print("📦 Data: ${message.data}");

      if (notification != null && android != null) {
        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'Used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );
        const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
        await flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          platformDetails,
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final url = message.data['url'];
      print("📲 Notification tapped");
      print("📦 Data: ${message.data}");
      if (url != null && webViewController != null) {
        webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      }
    });
  }

  /// Sends user ID and FCM token to backend to register for push notifications
  Future<void> registerToken(String userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('https://firstfinance.xpresspaisa.in/api/register_token.php'),
        body: {
          'user_id': userId,
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
      );
      print("✅ Token register request sent");
      print("🟢 Status Code: ${response.statusCode}");
      print("📦 Response Body: ${response.body}");
    } catch (e) {
      print("❌ Token registration error: $e");
    }
  }

  /// Handles back button to support WebView navigation or app exit confirmation
  Future<bool> _onBackPressed() async {
    if (webViewController != null && await webViewController!.canGoBack()) {
      webViewController!.goBack();
      return false;
    } else {
      return await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Exit App"),
          content: const Text("Do you really want to exit?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Yes"),
            ),
          ],
        ),
      ) ?? false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri("https://firstfinance.xpresspaisa.in/home.php"),
                  headers: widget.sessionId != null ? {
                    'Cookie': 'PHPSESSID=${widget.sessionId}'
                  } : null,
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  cacheEnabled: true,
                  clearCache: false,
                  mediaPlaybackRequiresUserGesture: false,
                  supportZoom: false,
                  allowsBackForwardNavigationGestures: true,
                  useShouldOverrideUrlLoading: true,
                  allowsInlineMediaPlayback: true,
                  allowFileAccess: true,
                  allowUniversalAccessFromFileURLs: true,
                  useHybridComposition: true,
                  transparentBackground: false,
                ),
                onWebViewCreated: (controller) {
                  webViewController = controller;

                  controller.addJavaScriptHandler(
                    handlerName: 'onLogin',
                    callback: (args) async {
                      if (args.isNotEmpty) {
                        _userId = args[0].toString();
                        print("👤 Logged in User ID: $_userId");

                        final cookies = await CookieManager.instance().getCookies(url: WebUri("https://firstfinance.xpresspaisa.in"));
                        for (var cookie in cookies) {
                          if (cookie.name == 'PHPSESSID') {
                            SharedPreferences prefs = await SharedPreferences.getInstance();
                            await prefs.setString('PHPSESSID', cookie.value);
                            print("💾 Saved PHPSESSID: ${cookie.value}");
                          }
                        }

                        if (_fcmToken != null && _userId != null) {
                          await registerToken(_userId!, _fcmToken!);
                        }
                      }
                    },
                  );
                },
                androidOnPermissionRequest: (controller, origin, resources) async {
                  return PermissionRequestResponse(
                    resources: resources,
                    action: PermissionRequestResponseAction.GRANT,
                  );
                },
                shouldOverrideUrlLoading: (controller, action) async {
                  final uri = action.request.url;
                  final scheme = uri?.scheme;

                  setState(() => _isLoading = true);

                  if (scheme == 'tel' || scheme == 'mailto') {
                    if (await canLaunchUrl(uri!)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                    setState(() => _isLoading = false);
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (uri.toString().contains("wa.me") || scheme == "whatsapp") {
                    if (await canLaunchUrl(uri!)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("WhatsApp not installed")),
                      );
                    }
                    setState(() => _isLoading = false);
                    return NavigationActionPolicy.CANCEL;
                  }

                  return NavigationActionPolicy.ALLOW;
                },
                onLoadStart: (_, __) => setState(() => _isLoading = true),
                onLoadStop: (_, __) => setState(() => _isLoading = false),
              ),
              if (_isLoading)
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
