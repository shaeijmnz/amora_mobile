import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:amora_florals_mobile/services/api_config.dart';

class ApiProductSize {
  ApiProductSize({required this.id, required this.label, required this.price});

  final int? id;
  final String label;
  final double price;

  factory ApiProductSize.fromJson(Map<String, dynamic> json) {
    return ApiProductSize(
      id: json['id'] as int?,
      label: json['label']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
    );
  }
}

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
    this.gallery = const [],
    this.sizes = const [],
    this.description,
    this.note,
    this.isStem = false,
  });

  final int id;
  final String name;
  final String category;
  final String priceLabel;
  final String rating;
  final String reviews;
  final String imageUrl;
  final int? sizeId;
  final List<String> gallery;
  final List<ApiProductSize> sizes;
  final String? description;
  final String? note;
  final bool isStem;

  factory ApiProduct.fromJson(Map<String, dynamic> json) {
    final sizes = ((json['sizes'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => ApiProductSize.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final galleryRaw = (json['gallery_image_urls'] as List?) ??
        (json['images'] as List?) ??
        const [];
    final gallery = galleryRaw
        .map((e) => ApiConfig.resolveImageUrl(e.toString()))
        .where((e) => e.isNotEmpty)
        .toList();
    return ApiProduct(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'flower',
      priceLabel: json['price_label']?.toString() ??
          '₱${((json['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}',
      rating: ((json['rating'] as num?)?.toDouble() ?? 4.5).toStringAsFixed(1),
      reviews: (json['reviews_count'] ?? 0).toString(),
      imageUrl: ApiConfig.resolveImageUrl(json['primary_image_url']?.toString()),
      sizeId: sizes.isNotEmpty ? sizes.first.id : null,
      gallery: gallery,
      sizes: sizes,
      description: json['description']?.toString(),
      note: json['note']?.toString(),
      isStem: json['is_stem'] == true,
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
