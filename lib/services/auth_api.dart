import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:amora_florals_mobile/services/api_config.dart';

class AuthSession {
  AuthSession({required this.token, required this.user});

  final String token;
  final Map<String, dynamic> user;
}

class AuthApiException implements Exception {
  AuthApiException(this.message, {this.needsVerification = false, this.email, this.debugOtp});

  final String message;
  final bool needsVerification;
  final String? email;
  final String? debugOtp;

  @override
  String toString() => message;
}

class AuthApi {
  static const _tokenKey = 'amora_auth_token';
  static const _userKey = 'amora_auth_user';

  Future<Map<String, dynamic>> _decode(http.Response response) {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    }
    return Future.value(body);
  }

  String _errorMessage(Map<String, dynamic> body, int status) {
    if (body['message'] is String && (body['message'] as String).isNotEmpty) {
      return body['message'] as String;
    }
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      return first.toString();
    }
    return 'Something went wrong ($status). Is Laravel running?';
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/register'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      }),
    );

    final body = await _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw AuthApiException(_errorMessage(body, response.statusCode));
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/login'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
      }),
    );

    final body = await _decode(response);

    if (response.statusCode == 403 && body['needs_verification'] == true) {
      throw AuthApiException(
        body['message']?.toString() ?? 'Please verify your email first.',
        needsVerification: true,
        email: body['email']?.toString() ?? email.trim(),
        debugOtp: body['debug_otp']?.toString(),
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final session = AuthSession(
        token: body['token'] as String,
        user: Map<String, dynamic>.from(body['user'] as Map),
      );
      await saveSession(session);
      return session;
    }

    throw AuthApiException(_errorMessage(body, response.statusCode));
  }

  Future<AuthSession> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/verify-otp'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email.trim(),
        'otp': otp.trim(),
      }),
    );

    final body = await _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final session = AuthSession(
        token: body['token'] as String,
        user: Map<String, dynamic>.from(body['user'] as Map),
      );
      await saveSession(session);
      return session;
    }
    throw AuthApiException(_errorMessage(body, response.statusCode));
  }

  Future<Map<String, dynamic>> resendOtp({required String email}) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/resend-otp'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'email': email.trim()}),
    );

    final body = await _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    throw AuthApiException(_errorMessage(body, response.statusCode));
  }

  Future<void> saveSession(AuthSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(_userKey, jsonEncode(session.user));
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
