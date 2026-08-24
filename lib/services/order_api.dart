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
  Future<String?> _token() async {
    final token = await AuthApi().getToken();
    if (token == null || token.isEmpty) {
      throw OrderApiException('Please log in first.');
    }
    return token;
  }

  Map<String, dynamic> _body(http.Response response) {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    }
    return body;
  }

  Never _throw(Map<String, dynamic> body, int status) {
    var message = body['message']?.toString() ?? 'Checkout failed ($status).';
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) message = first.first.toString();
    }
    throw OrderApiException(message);
  }

  /// Create awaiting_payment order + PayMongo hosted checkout URL.
  Future<Map<String, dynamic>> checkout({
    required List<({int sizeId, int quantity})> items,
    required String recipientName,
    required String recipientContact,
    required String deliveryAddress,
    String? deliveryNotes,
    double deliveryFee = 0,
  }) async {
    if (items.isEmpty) {
      throw OrderApiException('Your cart is empty.');
    }

    final token = await _token();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/orders/checkout'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'recipient_name': recipientName,
        'recipient_contact': recipientContact,
        'delivery_address': deliveryAddress,
        if (deliveryNotes != null && deliveryNotes.trim().isNotEmpty)
          'delivery_notes': deliveryNotes.trim(),
        'delivery_fee': deliveryFee,
        'payment_method': 'paymongo',
        'items': [
          for (final item in items)
            {'size_id': item.sizeId, 'quantity': item.quantity},
        ],
      }),
    );

    final body = _body(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    _throw(body, response.statusCode);
  }

  Future<Map<String, dynamic>> paymentStatus(int orderId) async {
    final token = await _token();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/payment-status'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final body = _body(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    _throw(body, response.statusCode);
  }

  Future<List<Map<String, dynamic>>> listOrders() async {
    final token = await _token();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/orders'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final body = _body(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = body['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }
    _throw(body, response.statusCode);
  }

  /// @deprecated Prefer [checkout] for PayMongo.
  Future<Map<String, dynamic>> placeOrder({
    required List<({int sizeId, int quantity})> items,
    String recipientName = 'Amora Customer',
    String recipientContact = '09171234567',
    String deliveryAddress = 'Quezon City (mobile checkout)',
  }) {
    return checkout(
      items: items,
      recipientName: recipientName,
      recipientContact: recipientContact,
      deliveryAddress: deliveryAddress,
    );
  }
}
