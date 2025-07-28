import 'dart:io';
import 'package:http/http.dart' as http;

class SessionManager {
  static const String baseUrl = 'https://firstfinance.xpresspaisa.in/api/';

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
