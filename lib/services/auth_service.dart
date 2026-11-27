import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tickmark/services/app_const.dart';

class AuthService {
  static const FlutterSecureStorage storage = FlutterSecureStorage();
  static const String tokenKey = 'access_token';
  static const String userKey = 'user_data';
  static const String expiryKey = 'expires_at';

  // LOGIN
  static Future<bool> login(
    String email,
    String password,
  ) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final response = await http.post(
        Uri.parse('${AppConst.baseUrl}/login.php'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await storage.write(
          key: tokenKey,
          value: data['access_token'],
        );

        await storage.write(
          key: userKey,
          value: jsonEncode(data['user']),
        );

        await storage.write(
          key: expiryKey,
          value: data['expires_at'],
        );

        await prefs.setString('email', data['user']['email']);
        await prefs.setString('name', data['user']['name']);

        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  // GET SAVED TOKEN
  static Future<String?> getToken() async {
    return await storage.read(key: tokenKey);
  }

  // VALIDATE EXISTING SESSION
  static Future<bool> validateSession() async {
    try {
      final token = await getToken();

      if (token == null || token.isEmpty) {
        return false;
      }

      final response = await http.get(
        Uri.parse('${AppConst.baseUrl}/projects.php'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      // 200 means token is valid.
      // Empty projects list is also a valid session.
      if (response.statusCode == 200) {
        return true;
      }

      if (response.statusCode == 401) {
        await clearSession();
      }

      return false;
    } catch (e) {
      debugPrint('Session validation error: $e');
      // Do not delete a valid saved token just because
      // the server is temporarily unavailable.
      return false;
    }
  }

  // GET SAVED USER
  static Future<Map<String, dynamic>?> getUser() async {
    final user = await storage.read(key: userKey);

    if (user == null) return null;

    return jsonDecode(user);
  }

  // LOGOUT
  static Future<void> logout() async {
    final token = await getToken();

    if (token != null) {
      try {
        await http.post(
          Uri.parse('${AppConst.baseUrl}/logout.php'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
      } catch (e) {
        debugPrint('Logout API error: $e');
      }
    }

    await clearSession();
  }

  // CLEAR LOCAL SESSION
  static Future<void> clearSession() async {
    await storage.delete(key: tokenKey);
    await storage.delete(key: userKey);
    await storage.delete(key: expiryKey);
  }
}
