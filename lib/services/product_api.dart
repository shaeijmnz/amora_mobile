import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:amora_florals_mobile/services/api_config.dart';

class ApiProduct {
  ApiProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.priceLabel,
    required this.rating,
    required this.reviews,
    required this.imageUrl,
    required this.sizeId,
  });

  final int id;
  final String name;
  final String category;
  final String priceLabel;
  final String rating;
  final String reviews;
  final String imageUrl;
  final int? sizeId;

  factory ApiProduct.fromJson(Map<String, dynamic> json) {
    final sizes = (json['sizes'] as List?) ?? const [];
    final firstSize = sizes.isNotEmpty ? sizes.first as Map<String, dynamic> : null;
    return ApiProduct(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'flower',
      priceLabel: json['price_label']?.toString() ??
          'Php. ${((json['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
      rating: ((json['rating'] as num?)?.toDouble() ?? 4.5).toStringAsFixed(1),
      reviews: (json['reviews_count'] ?? 0).toString(),
      imageUrl: json['primary_image_url']?.toString() ?? '',
      sizeId: firstSize?['id'] as int?,
    );
  }
}

class ProductApi {
  Future<List<ApiProduct>> fetchProducts() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/products'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to load products (${response.statusCode})');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (body['data'] as List?) ?? const [];
    return data
        .map((e) => ApiProduct.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
