class ApiConfig {
  /// Local Laravel API. Keep `php artisan serve` running on port 8000.
  /// Chrome / iOS simulator: 127.0.0.1
  /// Android emulator: use 10.0.2.2 instead of 127.0.0.1
  static const baseUrl = 'http://127.0.0.1:8000/api';

  static const origin = 'http://127.0.0.1:8000';

  /// Laravel may return `/images/products/foo.jpg`. Use bundled assets when
  /// we have the same file, otherwise load from the API host.
  static String resolveImageUrl(String? raw) {
    final url = (raw ?? '').trim();
    if (url.isEmpty) return url;
    if (url.startsWith('assets/')) return url;

    final file = url.split('/').last;
    if (file.isNotEmpty && url.contains('products/')) {
      return 'assets/images/products/$file';
    }
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '$origin$url';
    return '$origin/$url';
  }
}
