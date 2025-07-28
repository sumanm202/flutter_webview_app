import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class SessionManager {
  static const String baseUrl = 'https://firstfinance.xpresspaisa.in/api/';

  static Future<bool> checkSession(String? sessionId) async {
    if (sessionId == null) return false;
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}check_session.php'),
        headers: {'Cookie': 'PHPSESSID=$sessionId'},
      );
      final data = json.decode(response.body);
      return data['status'] == 'success';
    } catch (e) {
      print('❌ Session check error: $e');
      return false;
    }
  }

  static Future<String?> refreshSession(String sessionId) async {
    try {
      final response = await http.get(
        Uri.parse('${baseUrl}refresh_session.php'),
        headers: {'Cookie': 'PHPSESSID=$sessionId'},
      );
      final data = json.decode(response.body);
      return data['status'] == 'success' ? data['session_id'] : null;
    } catch (e) {
      print('❌ Session refresh error: $e');
      return null;
    }
  }

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
}
