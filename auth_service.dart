import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

class AuthService {
  static Future<Map<String, dynamic>> signup({
    required String fullname,
    required String email,
    required String password,
    required String appType,
  }) async {
    final response = await http.post(
      Uri.parse(AppConfig.signup),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "fullname": fullname,
        "email": email,
        "password": password,
        "app_type": appType,
      }),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> signin({
    required String email,
    required String password,
    required String appType,
  }) async {
    final response = await http.post(
      Uri.parse(AppConfig.signin),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
        "app_type": appType,
      }),
    );

    return jsonDecode(response.body);
  }
}