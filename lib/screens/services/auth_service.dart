import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _baseUrl = 'https://seguridadvial-mich.com/api';
  static const String _tokenKey = 'auth_token';

  /* ===================== LOGIN ===================== */
  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Accept': 'application/json'},
      body: {'email': email, 'password': password},
    );

    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body);

    final token = data['token'];
    if (token == null) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);

    return true;
  }

  /* ===================== TOKEN ===================== */
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /* ===================== SESIÓN ===================== */
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /* ===================== LOGOUT ===================== */
  static Future<void> logout() async {
    final token = await getToken();

    if (token != null) {
      await http.post(
        Uri.parse('$_baseUrl/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
