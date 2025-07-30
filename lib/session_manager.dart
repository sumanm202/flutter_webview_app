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

  // Check if session is valid
  static Future<bool> checkSession() async {
    try {
      // Get stored cookies and add them to the request
      final prefs = await SharedPreferences.getInstance();
      final storedCookies = prefs.getString(_cookieStorageKey);

      final response = await http.get(
        Uri.parse('${baseUrl}check_session.php'),
        headers: {
          'Content-Type': 'application/json',
          if (storedCookies != null) 'Cookie': storedCookies,
        },
      );

      // Save any new cookies from response
      if (response.headers['set-cookie'] != null) {
        await _saveCookieFromHeader(response.headers['set-cookie']!);
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      print('❌ Session check error: $e');
      return false;
    }
  }

  // Refresh session
  static Future<bool> refreshSession() async {
    try {
      // Get stored cookies and add them to the request
      final prefs = await SharedPreferences.getInstance();
      final storedCookies = prefs.getString(_cookieStorageKey);

      final response = await http.get(
        Uri.parse('${baseUrl}refresh_session.php'),
        headers: {
          'Content-Type': 'application/json',
          if (storedCookies != null) 'Cookie': storedCookies,
        },
      );

      // Save any new cookies from response
      if (response.headers['set-cookie'] != null) {
        await _saveCookieFromHeader(response.headers['set-cookie']!);
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'success';
      }
      return false;
    } catch (e) {
      print('❌ Session refresh error: $e');
      return false;
    }
  }

  // Send heartbeat to keep session alive
  static Future<Map<String, dynamic>?> sendHeartbeat() async {
    try {
      // Get stored cookies and add them to the request
      final prefs = await SharedPreferences.getInstance();
      final storedCookies = prefs.getString(_cookieStorageKey);

      final response = await http.get(
        Uri.parse('${baseUrl}session_heartbeat.php'),
        headers: {
          'Content-Type': 'application/json',
          if (storedCookies != null) 'Cookie': storedCookies,
        },
      );

      // Save any new cookies from response
      if (response.headers['set-cookie'] != null) {
        await _saveCookieFromHeader(response.headers['set-cookie']!);
      }

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
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
          await _cookieManager?.setCookie(
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

          print("📝 Saved cookies: ${cookieStrings.join('; ')}");
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
          print("✅ Restored cookies: $storedCookies");
        }
      }
    } catch (e) {
      print("❌ Error restoring cookies: $e");
    }
  }
}
