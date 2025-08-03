import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const String baseUrl = 'https://firstfinance.xpresspaisa.in/api/';
  static const String mainDomain = 'firstfinance.xpresspaisa.in';
  static CookieManager? _cookieManager;
  static const String _cookieStorageKey = 'saved_cookies';
  static const String _lastSessionCheckKey = 'last_session_check';
  static const String _storedCredentialsKey = 'stored_credentials';
  static const String _persistentTokenKey = 'persistent_token';

  static Future<void> registerToken(String userId, String token) async {
    try {
      final response = await http.post(
        Uri.parse('${baseUrl}register_token.php'),
        body: {
          'user_id': userId,
          'token': token,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
      );
      print("✅ Token registration response: ${response.body}");
    } catch (e) {
      print("❌ Token registration error: $e");
    }
  }

  // Initialize cookie manager
  static void initCookieManager() {
    _cookieManager = CookieManager.instance();
  }

  // Enhanced auto login with persistent token support
  static Future<Map<String, dynamic>?> autoLogin(String email, String password) async {
    try {
      print("🔐 Attempting enhanced auto login for: $email");

      final response = await http.post(
        Uri.parse('${baseUrl}enhanced_auto_login.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      print("📡 Enhanced auto login response: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          print("✅ Enhanced auto login successful");

          // Store persistent token
          if (data['persistent_token'] != null) {
            await _storePersistentToken(data['persistent_token']);
          }

          // Save cookies after successful login
          await saveCookies('https://$mainDomain');
          return data;
        } else {
          print("❌ Enhanced auto login failed: ${data['message']}");
          return data;
        }
      } else {
        print("❌ Enhanced auto login failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print('❌ Enhanced auto login error: $e');
      return null;
    }
  }

  // Store persistent token
  static Future<void> _storePersistentToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_persistentTokenKey, token);
      print("🔐 Persistent token stored");
    } catch (e) {
      print("❌ Error storing persistent token: $e");
    }
  }

  // Get stored persistent token
  static Future<String?> getPersistentToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_persistentTokenKey);
    } catch (e) {
      print("❌ Error getting persistent token: $e");
      return null;
    }
  }

  // Store credentials securely (for auto-login)
  static Future<void> storeCredentials(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentials = {
        'email': email,
        'password': password,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_storedCredentialsKey, json.encode(credentials));
      print("🔐 Credentials stored securely");
    } catch (e) {
      print("❌ Error storing credentials: $e");
    }
  }

  // Get stored credentials
  static Future<Map<String, dynamic>?> getStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsStr = prefs.getString(_storedCredentialsKey);
      if (credentialsStr != null) {
        final credentials = json.decode(credentialsStr);
        // Check if credentials are not too old (30 days)
        final timestamp = credentials['timestamp'] as int;
        final storedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final now = DateTime.now();
        final difference = now.difference(storedTime);

        if (difference.inDays < 30) {
          return credentials;
        } else {
          // Remove old credentials
          await prefs.remove(_storedCredentialsKey);
        }
      }
      return null;
    } catch (e) {
      print("❌ Error getting stored credentials: $e");
      return null;
    }
  }

  // Clear stored credentials
  static Future<void> clearStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storedCredentialsKey);
      await prefs.remove(_persistentTokenKey);
      print("🔐 Stored credentials cleared");
    } catch (e) {
      print("❌ Error clearing credentials: $e");
    }
  }

  // Enhanced session check with persistent token support
  static Future<bool> checkSession() async {
    try {
      // Get stored cookies and persistent token
      final prefs = await SharedPreferences.getInstance();
      final storedCookies = prefs.getString(_cookieStorageKey);
      final persistentToken = await getPersistentToken();

      print("🔍 Checking enhanced session...");

      // Add persistent token to cookies if available
      String allCookies = storedCookies ?? '';
      if (persistentToken != null) {
        allCookies += '; persistent_token=$persistentToken';
      }

      final response = await http.get(
        Uri.parse('${baseUrl}enhanced_check_session.php'),
        headers: {
          'Content-Type': 'application/json',
          if (allCookies.isNotEmpty) 'Cookie': allCookies,
        },
      ).timeout(const Duration(seconds: 10));

      print("📡 Enhanced session check response: ${response.statusCode}");

      // Save any new cookies from response
      if (response.headers['set-cookie'] != null) {
        print("🍪 New cookies received: ${response.headers['set-cookie']}");
        await _saveCookieFromHeader(response.headers['set-cookie']!);
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final isValid = data['status'] == 'success';
        print("✅ Enhanced session check result: $isValid");

        // Store last check time
        await prefs.setInt(_lastSessionCheckKey, DateTime.now().millisecondsSinceEpoch);

        // Update persistent token if provided
        if (data['persistent_token'] != null) {
          await _storePersistentToken(data['persistent_token']);
        }

        return isValid;
      }

      print("❌ Enhanced session check failed with status: ${response.statusCode}");
      return false;
    } catch (e) {
      print('❌ Enhanced session check error: $e');
      return false;
    }
  }

  // Refresh session
  static Future<bool> refreshSession() async {
    try {
      // Get stored cookies and persistent token
      final prefs = await SharedPreferences.getInstance();
      final storedCookies = prefs.getString(_cookieStorageKey);
      final persistentToken = await getPersistentToken();

      print("🔄 Refreshing enhanced session...");

      // Add persistent token to cookies if available
      String allCookies = storedCookies ?? '';
      if (persistentToken != null) {
        allCookies += '; persistent_token=$persistentToken';
      }

      final response = await http.get(
        Uri.parse('${baseUrl}refresh_session.php'),
        headers: {
          'Content-Type': 'application/json',
          if (allCookies.isNotEmpty) 'Cookie': allCookies,
        },
      ).timeout(const Duration(seconds: 10));

      print("📡 Session refresh response: ${response.statusCode}");

      // Save any new cookies from response
      if (response.headers['set-cookie'] != null) {
        print("🍪 New cookies from refresh: ${response.headers['set-cookie']}");
        await _saveCookieFromHeader(response.headers['set-cookie']!);
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['status'] == 'success';
        print("✅ Session refresh result: $success");
        return success;
      }

      print("❌ Session refresh failed with status: ${response.statusCode}");
      return false;
    } catch (e) {
      print('❌ Session refresh error: $e');
      return false;
    }
  }

  // Send heartbeat to keep session alive
  static Future<Map<String, dynamic>?> sendHeartbeat() async {
    try {
      // Get stored cookies and persistent token
      final prefs = await SharedPreferences.getInstance();
      final storedCookies = prefs.getString(_cookieStorageKey);
      final persistentToken = await getPersistentToken();

      // Add persistent token to cookies if available
      String allCookies = storedCookies ?? '';
      if (persistentToken != null) {
        allCookies += '; persistent_token=$persistentToken';
      }

      final response = await http.get(
        Uri.parse('${baseUrl}session_heartbeat.php'),
        headers: {
          'Content-Type': 'application/json',
          if (allCookies.isNotEmpty) 'Cookie': allCookies,
        },
      ).timeout(const Duration(seconds: 10));

      // Save any new cookies from response
      if (response.headers['set-cookie'] != null) {
        await _saveCookieFromHeader(response.headers['set-cookie']!);
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("💓 Heartbeat successful: ${data['message']}");
        return data;
      }

      print("❌ Heartbeat failed with status: ${response.statusCode}");
      return null;
    } catch (e) {
      print('❌ Session heartbeat error: $e');
      return null;
    }
  }

  // Save cookies from Set-Cookie header
  static Future<void> _saveCookieFromHeader(String setCookieHeader) async {
    try {
      final cookieValues = setCookieHeader.split(',').map((cookie) => cookie.trim()).toList();

      for (var cookieStr in cookieValues) {
        final parts = cookieStr.split(';')[0].split('=');
        if (parts.length == 2) {
          final cookieName = parts[0].trim();
          final cookieValue = parts[1].trim();

          // Store persistent token separately
          if (cookieName == 'persistent_token') {
            await _storePersistentToken(cookieValue);
          }

          await _cookieManager?.setCookie(
            url: WebUri('https://$mainDomain'),
            name: cookieName,
            value: cookieValue,
            domain: mainDomain,
            path: '/',
            expiresDate: DateTime.now().add(const Duration(days: 70)).millisecondsSinceEpoch,
            isSecure: false,
          );
        }
      }

      await saveCookies('https://$mainDomain');
    } catch (e) {
      print("❌ Error saving cookie from header: $e");
    }
  }

  // Save cookies for persistence
  static Future<void> saveCookies(String domain) async {
    try {
      if (_cookieManager != null) {
        final cookies = await _cookieManager!.getCookies(url: WebUri(domain));

        // Convert cookies to a format we can store
        final cookieStrings = cookies.map((cookie) {
          final expires = DateTime.now().add(const Duration(days: 70));
          return '${cookie.name}=${cookie.value}; expires=${expires.toUtc()}; path=/; domain=$mainDomain';
        }).toList();

        if (cookieStrings.isNotEmpty) {
          // Store cookies in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_cookieStorageKey, cookieStrings.join('; '));

          // Also ensure cookies are set in WebView
          for (var cookie in cookies) {
            await _cookieManager!.setCookie(
              url: WebUri(domain),
              name: cookie.name,
              value: cookie.value,
              domain: mainDomain,
              path: '/',
              expiresDate: DateTime.now().add(const Duration(days: 70)).millisecondsSinceEpoch,
              isSecure: false,
            );
          }

          print("📝 Saved ${cookieStrings.length} cookies");
        }
      }
    } catch (e) {
      print("❌ Error saving cookies: $e");
    }
  }

  // Restore cookies
  static Future<void> restoreCookies(String domain) async {
    try {
      if (_cookieManager != null) {
        // Get stored cookies
        final prefs = await SharedPreferences.getInstance();
        final storedCookies = prefs.getString(_cookieStorageKey);

        if (storedCookies != null) {
          // Parse stored cookies
          final cookieList = storedCookies.split('; ');
          for (var cookieStr in cookieList) {
            final parts = cookieStr.split('=');
            if (parts.length == 2) {
              await _cookieManager!.setCookie(
                url: WebUri('https://$mainDomain'),
                name: parts[0].trim(),
                value: parts[1].trim(),
                domain: mainDomain,
                path: '/',
                expiresDate: DateTime.now().add(const Duration(days: 70)).millisecondsSinceEpoch,
                isSecure: false,
              );
            }
          }
          print("✅ Restored ${cookieList.length} cookies");
        }
      }
    } catch (e) {
      print("❌ Error restoring cookies: $e");
    }
  }

  // Get last session check time
  static Future<DateTime?> getLastSessionCheck() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getInt(_lastSessionCheckKey);
    if (timestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return null;
  }

  // Check if session check is needed (if more than 5 minutes have passed)
  static Future<bool> isSessionCheckNeeded() async {
    final lastCheck = await getLastSessionCheck();
    if (lastCheck == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastCheck);
    return difference.inMinutes >= 5;
  }
}
