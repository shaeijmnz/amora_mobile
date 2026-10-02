import 'package:flutter/foundation.dart';

class ApiConfig {
  /// On the web, call the API on the same host as the page so Chrome can open
  /// the app from a public link. Native builds still use the local Laravel port.
  static String get baseUrl {
    final webOrigin = _webOrigin;
    if (webOrigin != null) return '$webOrigin/api';
    return 'http://127.0.0.1:8000/api';
  }

  static String get origin => _webOrigin ?? 'http://127.0.0.1:8000';

  static String? get _webOrigin {
    if (!kIsWeb) return null;
    final origin = Uri.base.origin;
    if (origin.isEmpty || origin == 'null') return null;
    return origin;
  }

  /// Laravel may return `/images/products/foo.jpg`. Use bundled bouquet
  /// photos when we have the same file. Never keep Unsplash placeholders.
  static String resolveImageUrl(String? raw) {
    final url = (raw ?? '').trim();
    if (url.isEmpty) return url;
    if (url.startsWith('assets/')) return url;

    final lower = url.toLowerCase();
    if (lower.contains('unsplash.com') || lower.contains('images.unsplash')) {
      return '';
    }

    final file = url.split('?').first.split('/').last;
    if (file.isNotEmpty && (url.contains('products/') || url.contains('images/'))) {
      return 'assets/images/products/$file';
    }
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$origin$url';
    return '$origin/$url';
  }
}
