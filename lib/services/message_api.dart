import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:amora_florals_mobile/services/api_config.dart';
import 'package:amora_florals_mobile/services/auth_api.dart';

class MessageApiException implements Exception {
  MessageApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ShopMessage {
  const ShopMessage({
    required this.id,
    required this.body,
    required this.mine,
    required this.time,
  });

  final int id;
  final String body;
  final bool mine;
  final String time;

  factory ShopMessage.fromJson(Map<String, dynamic> json) {
    return ShopMessage(
      id: json['id'] as int,
      body: json['body']?.toString() ?? '',
      mine: json['mine'] == true,
      time: json['time']?.toString() ?? '',
    );
  }
}

class ShopThread {
  const ShopThread({
    required this.preview,
    required this.time,
    required this.unread,
    required this.messages,
  });

  final String preview;
  final String time;
  final int unread;
  final List<ShopMessage> messages;

  factory ShopThread.fromJson(Map<String, dynamic> json) {
    final raw = (json['messages'] as List?) ?? const [];
    return ShopThread(
      preview: json['preview']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      unread: (json['unread'] as num?)?.toInt() ?? 0,
      messages: raw
          .whereType<Map>()
          .map((e) => ShopMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class MessageApi {
  Future<ShopThread> fetch({bool markRead = false}) async {
    final token = await _token();
    final query = markRead ? '?mark_read=1' : '';
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/messages$query'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return _thread(response);
  }

  Future<ShopThread> send(String body) async {
    final token = await _token();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/messages'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'body': body}),
    );
    return _thread(response);
  }

  Future<String> _token() async {
    final token = await AuthApi().getToken();
    if (token == null || token.isEmpty) {
      throw MessageApiException('Please log in first.');
    }
    return token;
  }

  ShopThread _thread(http.Response response) {
    Map<String, dynamic> body = {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) body = decoded;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = body['message']?.toString() ?? 'Could not load messages (${response.statusCode}).';
      final errors = body['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) message = first.first.toString();
      }
      throw MessageApiException(message);
    }
    return ShopThread.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }
}
