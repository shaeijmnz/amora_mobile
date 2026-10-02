import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:amora_florals_mobile/services/api_config.dart';
import 'package:amora_florals_mobile/services/auth_api.dart';

class CustomRequestApiException implements Exception {
  CustomRequestApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CustomRequestApi {
  Future<String> _token() async {
    final token = await AuthApi().getToken();
    if (token == null || token.isEmpty) {
      throw CustomRequestApiException('Please log in first.');
    }
    return token;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.body.isEmpty) return {};
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : {};
  }

  Never _throw(Map<String, dynamic> body, int status) {
    var message = body['message']?.toString() ?? 'Request failed ($status).';
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) message = first.first.toString();
    }
    throw CustomRequestApiException(message);
  }

  Future<Map<String, dynamic>> submit({
    required String occasion,
    required double budget,
    required String requestedDate,
    String? preferredFlowers,
    String? preferredColors,
    String? bouquetSize,
    String? requestedTime,
    String? message,
  }) async {
    final token = await _token();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/custom-requests'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'occasion': occasion,
        'budget': budget,
        'requested_delivery_date': requestedDate,
        if (requestedTime != null && requestedTime.isNotEmpty)
          'requested_delivery_time': requestedTime,
        if (preferredFlowers != null && preferredFlowers.trim().isNotEmpty)
          'preferred_flowers': preferredFlowers.trim(),
        if (preferredColors != null && preferredColors.trim().isNotEmpty)
          'preferred_colors': preferredColors.trim(),
        if (bouquetSize != null && bouquetSize.isNotEmpty) 'bouquet_size': bouquetSize,
        if (message != null && message.trim().isNotEmpty)
          'personalized_message': message.trim(),
      }),
    );

    final body = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    _throw(body, response.statusCode);
  }

  Future<List<Map<String, dynamic>>> list() async {
    final token = await _token();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/custom-requests'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = _decode(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is List) {
        return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    }
    _throw(body, response.statusCode);
  }
}
