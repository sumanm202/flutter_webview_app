import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_webview_app/session_manager.dart';
import 'package:flutter_webview_app/background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'Used for important notifications.',
  importance: Importance.high,
  playSound: true,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 Background message: ${message.messageId}');
  print('📩 Title: ${message.notification?.title}');
  print('📩 Body: ${message.notification?.body}');
  print('📦 Data: ${message.data}');
}

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

  // Initialize background service for session management
  await BackgroundService.initializeService();

  runApp(const MyApp());
}

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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WebViewPage()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(image: AssetImage('assets/images/logo.png'), width: 150, height: 150),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});
  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> with WidgetsBindingObserver {
  InAppWebViewController? webViewController;
  bool _isLoading = true;
  String? _fcmToken;
  String? _userId;
  Timer? _sessionTimer;
  Timer? _backgroundTimer;
  final String _baseUrl = "https://firstfinance.xpresspaisa.in";
  bool _isOnLoginPage = false; // Track if user is on login page
  bool _isAutoLoggingIn = false; // Track if auto-login is in progress

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initFCM();
    SessionManager.initCookieManager();
    _setupSessionManagement();
    _setupBackgroundSessionManagement();
    _attemptAutoLogin();
  }

  // Attempt auto-login on app start
  Future<void> _attemptAutoLogin() async {
    try {
      print("🔐 Attempting auto-login on app start...");

      // First check if we have a valid session
      bool isValid = await SessionManager.checkSession();
      if (isValid) {
        print("✅ Valid session found, no auto-login needed");
        return;
      }

      // Try auto-login with stored credentials
      final credentials = await SessionManager.getStoredCredentials();
      if (credentials != null) {
        _isAutoLoggingIn = true;
        print("🔐 Attempting auto-login with stored credentials...");

        final result = await SessionManager.autoLogin(
          credentials['email'],
          credentials['password'],
        );

        if (result != null && result['status'] == 'success') {
          print("✅ Auto-login successful!");
          _userId = result['user_id'].toString();

          // Register FCM token if available
          if (_fcmToken != null && _userId != null) {
            await SessionManager.registerToken(_userId!, _fcmToken!);
          }

          // Navigate to dashboard
          if (webViewController != null) {
            webViewController!.loadUrl(
              urlRequest: URLRequest(url: WebUri("$_baseUrl/dashboard.php")),
            );
          }
        } else {
          print("❌ Auto-login failed, user needs to login manually");
        }
        _isAutoLoggingIn = false;
      } else {
        print("📝 No stored credentials found, user needs to login manually");
      }
    } catch (e) {
      print("❌ Auto-login error: $e");
      _isAutoLoggingIn = false;
    }
  }

  void _setupSessionManagement() {
    // Check session every 5 minutes (more frequent)
    _sessionTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      // Don't check session if user is on login page or auto-login is in progress
      if (_isOnLoginPage || _isAutoLoggingIn) {
        print("🔍 Skipping session check - user on login page or auto-login in progress");
        return;
      }

      print("🔍 Checking enhanced session...");
      bool isValid = await SessionManager.checkSession();
      print("Session valid: $isValid");

      if (!isValid) {
        // Try auto-login before redirecting
        print("❌ Session expired, attempting auto-login...");
        final credentials = await SessionManager.getStoredCredentials();
        if (credentials != null) {
          _isAutoLoggingIn = true;
          final result = await SessionManager.autoLogin(
            credentials['email'],
            credentials['password'],
          );

          if (result != null && result['status'] == 'success') {
            print("✅ Auto-login successful, session restored!");
            _userId = result['user_id'].toString();
            _isAutoLoggingIn = false;
            return;
          }
          _isAutoLoggingIn = false;
        }

        // If auto-login failed, redirect to login
        print("❌ Auto-login failed, redirecting to login");
        _redirectToLogin();
      } else {
        // Refresh session to extend lifetime
        print("✅ Session valid, refreshing...");
        await SessionManager.refreshSession();
        await SessionManager.saveCookies(_baseUrl);
      }
    });
  }

  void _setupBackgroundSessionManagement() {
    // Background session management every 10 minutes
    _backgroundTimer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      // Don't refresh session if user is on login page or auto-login is in progress
      if (_isOnLoginPage || _isAutoLoggingIn) {
        print("🔄 Skipping background session refresh - user on login page or auto-login in progress");
        return;
      }

      print("🔄 Background session refresh...");
      try {
        await SessionManager.refreshSession();
        await SessionManager.saveCookies(_baseUrl);
        print("✅ Background session refreshed");
      } catch (e) {
        print("❌ Background session refresh error: $e");
      }
    });
  }

  void _redirectToLogin() {
    if (webViewController != null) {
      webViewController!.loadUrl(
        urlRequest: URLRequest(url: WebUri("$_baseUrl/login.php")),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.paused:
        print("📱 App paused - saving session");
        SessionManager.saveCookies(_baseUrl);
        break;
      case AppLifecycleState.resumed:
      // Don't check session if user is on login page or auto-login is in progress
        if (_isOnLoginPage || _isAutoLoggingIn) {
          print("📱 App resumed - skipping session check (on login page or auto-login in progress)");
          return;
        }

        print("📱 App resumed - checking session");
        SessionManager.checkSession().then((isValid) {
          if (!isValid) {
            print("❌ Session invalid on resume, attempting auto-login...");
            _attemptAutoLogin();
          } else {
            print("✅ Session valid on resume");
            SessionManager.refreshSession();
          }
        });
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    _backgroundTimer?.cancel();
    super.dispose();
  }

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
        await SessionManager.registerToken(_userId!, _fcmToken!);
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        const androidDetails = AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'Used for important notifications.',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        );
        const platformDetails = NotificationDetails(android: androidDetails);
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
      if (url != null && webViewController != null) {
        webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      }
    });
  }

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
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text("No")),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("Yes")),
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
                  url: WebUri("$_baseUrl/home.php"),
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
                  // Enhanced cache settings
                  cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
                  // Cookie settings
                  thirdPartyCookiesEnabled: true,
                  // Database settings
                  databaseEnabled: true,
                  // DOM storage settings
                  domStorageEnabled: true,
                  // Additional settings for persistence
                  appCachePath: ".",
                  applicationNameForUserAgent: "FirstFinance/1.0",
                  // Cookie persistence
                  clearSessionCache: false,
                  // Cache persistence
                  useShouldInterceptFetchRequest: true,
                  // Additional persistence settings
                  allowContentAccess: true,
                  allowFileAccessFromFileURLs: true,
                ),
                onWebViewCreated: (controller) async {
                  webViewController = controller;
                  // Restore cookies when WebView is created
                  await SessionManager.restoreCookies(_baseUrl);

                  controller.addJavaScriptHandler(
                    handlerName: 'onLogin',
                    callback: (args) async {
                      if (args.isNotEmpty) {
                        _userId = args[0].toString();
                        print("👤 Logged in User ID: $_userId");

                        // Store credentials for auto-login
                        if (args.length >= 3) {
                          await SessionManager.storeCredentials(args[1].toString(), args[2].toString());
                        }

                        if (_fcmToken != null && _userId != null) {
                          await SessionManager.registerToken(_userId!, _fcmToken!);
                          // Save cookies after successful login
                          await SessionManager.saveCookies(_baseUrl);
                        }
                      }
                    },
                  );
                },
                onLoadStart: (controller, url) async {
                  setState(() => _isLoading = true);

                  // Check if user is on login page
                  final currentUrl = url?.toString() ?? '';
                  if (currentUrl.contains('login.php')) {
                    _isOnLoginPage = true;
                    print("📝 User is on login page: $currentUrl");
                    print("📝 Session management PAUSED");
                  } else {
                    _isOnLoginPage = false;
                    print("📝 User is on page: $currentUrl");
                    print("📝 Session management RESUMED");
                  }

                  // Save cookies on each page load start
                  await SessionManager.saveCookies(_baseUrl);
                },
                onLoadStop: (controller, url) async {
                  setState(() => _isLoading = false);

                  // Only send heartbeat if not on login page
                  if (!_isOnLoginPage) {
                    await SessionManager.sendHeartbeat();
                  }

                  // Save cookies on each page load
                  await SessionManager.saveCookies(_baseUrl);
                },
                onReceivedHttpError: (controller, request, errorResponse) async {
                  if (errorResponse.statusCode == 401) {
                    // Session expired
                    print("❌ HTTP 401 - Session expired");
                    _redirectToLogin();
                  }
                },
                shouldInterceptFetchRequest: (controller, fetchRequest) async {
                  // Add stored cookies to all requests
                  final prefs = await SharedPreferences.getInstance();
                  final storedCookies = prefs.getString('saved_cookies');
                  final persistentToken = await SessionManager.getPersistentToken();

                  String allCookies = storedCookies ?? '';
                  if (persistentToken != null) {
                    allCookies += '; persistent_token=$persistentToken';
                  }

                  if (allCookies.isNotEmpty) {
                    fetchRequest.headers?['Cookie'] = allCookies;
                  }
                  return fetchRequest;
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
              ),
              if (_isLoading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
