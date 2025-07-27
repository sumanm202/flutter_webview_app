import 'dart:async';
import 'dart:convert';
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

// Initialize local notifications plugin for handling foreground notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Configure Android notification channel for high-priority notifications
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for important notifications.',
  importance: Importance.high,
  playSound: true,
);

// Background message handler for Firebase Cloud Messaging (FCM)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 Background message: ${message.messageId}');
  print('📩 Background notification title: ${message.notification?.title}');
  print('📩 Background notification body: ${message.notification?.body}');
  print('📦 Background data: ${message.data}');
}

// Application entry point
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

  await [
    Permission.camera,
    Permission.microphone,
    Permission.photos,
    Permission.storage,
    Permission.notification,
  ].request();

  runApp(const MyApp());
}

// Root widget of the application
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

// Splash screen widget to display logo and validate session
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to WebViewPage after 2 seconds, validating stored session ID
    Timer(const Duration(seconds: 2), () async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? sessionId = prefs.getString('PHPSESSID');
      bool isSessionValid = await _validateSession(sessionId);
      if (!isSessionValid && sessionId != null) {
        await prefs.remove('PHPSESSID');
        sessionId = null;
        print("❌ Cleared invalid PHPSESSID");
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WebViewPage(sessionId: sessionId),
        ),
      );
    });
  }

  // Validate session ID with backend
  Future<bool> _validateSession(String? sessionId) async {
    if (sessionId == null) return false;
    try {
      final response = await http.get(
        Uri.parse('https://firstfinance.xpresspaisa.in/api/check_session.php'),
        headers: {'Cookie': 'PHPSESSID=$sessionId'},
      );
      print("🟢 Session validation status: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print("❌ Session validation error: $e");
      return false;
    }
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

// WebView page for displaying web content with session and FCM handling
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
  Timer? _sessionRefreshTimer;

  @override
  void initState() {
    super.initState();
    initFCM();
    // Start periodic session refresh every 12 hours
    _sessionRefreshTimer = Timer.periodic(const Duration(hours: 12), (_) => _refreshSession());
  }

  // Set up Firebase Cloud Messaging and local notifications
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

  // Register FCM token with backend
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

  // Refresh session periodically to prevent expiration
  Future<void> _refreshSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? sessionId = prefs.getString('PHPSESSID');
    if (sessionId != null) {
      try {
        final response = await http.get(
          Uri.parse('https://firstfinance.xpresspaisa.in/api/refresh_session.php'),
          headers: {'Cookie': 'PHPSESSID=$sessionId'},
        );
        if (response.statusCode == 200) {
          final jsonResponse = jsonDecode(response.body);
          if (jsonResponse['session_id'] != null) {
            await prefs.setString('PHPSESSID', jsonResponse['session_id']);
            print("💾 Updated PHPSESSID: ${jsonResponse['session_id']}");
          }
          print("✅ Session refreshed");
        } else {
          await prefs.remove('PHPSESSID');
          print("❌ Session refresh failed, cleared PHPSESSID");
          // Reload WebView to trigger login
          if (webViewController != null) {
            webViewController!.loadUrl(
              urlRequest: URLRequest(url: WebUri("https://firstfinance.xpresspaisa.in/home.php")),
            );
          }
        }
      } catch (e) {
        print("❌ Session refresh error: $e");
      }
    }
  }

  // Handle back button for WebView navigation or app exit
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

                  // Detect redirect to login page indicating session expiration
                  if (uri.toString().contains('/login.php')) {
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.remove('PHPSESSID');
                    print("❌ Session expired, cleared PHPSESSID");

                    setState(() => _isLoading = false);
                    return NavigationActionPolicy.ALLOW;
                  }

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

  @override
  void dispose() {
    _sessionRefreshTimer?.cancel(); // Clean up timer
    super.dispose();
  }
}