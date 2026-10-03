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

  /// Seeded bouquet files shipped inside the app. Anything else — including
  /// a photo uploaded from the admin — is loaded from the site itself.
  static const bundledProductImages = {
    'carnation.jpg',
    'carnation_1.jpg',
    'china_roses.jpg',
    'china_roses_1.jpg',
    'gerbera_daisy.jpg',
    'gerbera_daisy_1.jpg',
    'hydrangea.jpg',
    'hydrangea_1.jpg',
    'stargazer_lilies.jpg',
    'stargazer_lilies_1.jpg',
    'sunflower.jpg',
    'sunflower_1.jpg',
    'sunlight_chrysanthemum.jpg',
    'sunlight_chrysanthemum_1.jpg',
  };

  /// Laravel may return `/images/products/foo.jpg` or `/images/uploads/….jpg`.
  /// Use the bundled photo only when that exact file ships with the app.
  static String resolveImageUrl(String? raw) {
    final url = (raw ?? '').trim();
    if (url.isEmpty) return url;
    if (url.startsWith('assets/')) return url;

    final lower = url.toLowerCase();
    if (lower.contains('unsplash.com') || lower.contains('images.unsplash')) {
      return '';
    }

    final file = url.split('?').first.split('/').last.toLowerCase();
    if (bundledProductImages.contains(file)) {
      return 'assets/images/products/$file';
    }
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$origin$url';
    return '$origin/$url';
  }
}
