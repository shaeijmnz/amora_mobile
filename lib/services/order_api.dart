import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:amora_florals_mobile/services/api_config.dart';
import 'package:amora_florals_mobile/services/auth_api.dart';

class OrderApiException implements Exception {
  OrderApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class OrderApi {
  Future<Map<String, dynamic>> placeOrder({
    required int sizeId,
    required int quantity,
    String recipientName = 'Amora Customer',
    String recipientContact = '09171234567',
    String deliveryAddress = 'Quezon City (mobile checkout)',
  }) async {
    final token = await AuthApi().getToken();
    if (token == null || token.isEmpty) {
      throw OrderApiException('Please log in first.');
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/orders'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'recipient_name': recipientName,
        'recipient_contact': recipientContact,
        'delivery_address': deliveryAddress,
        'payment_method': 'cod',
        'items': [
          {'size_id': sizeId, 'quantity': quantity},
        ],
      }),
    );

    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    var message = body['message']?.toString() ?? 'Checkout failed (${response.statusCode}).';
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) message = first.first.toString();
    }
    throw OrderApiException(message);
  }
}
