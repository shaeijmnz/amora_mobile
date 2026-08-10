class ApiConfig {
  /// Local Laravel API. Keep `php artisan serve` running on port 8000.
  /// Chrome / iOS simulator: 127.0.0.1
  /// Android emulator: use 10.0.2.2 instead of 127.0.0.1
  static const baseUrl = 'http://127.0.0.1:8000/api';
}
