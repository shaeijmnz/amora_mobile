# Amora Florals — Mobile + Laravel Backend

Customer mobile app (Flutter) + Laravel API/database backup.

## Folders

| Folder | What |
|--------|------|
| `/` (root) | Flutter customer mobile app |
| `laravel/` | Laravel API + SQLite database (shared backend for mobile & admin) |

## Run Flutter (customer)

```bash
flutter pub get
flutter run -d chrome --web-port=8080
# or: flutter run -d web-server --web-hostname=127.0.0.1 --web-port=8080
```

API base URL: `lib/services/api_config.dart` → `http://127.0.0.1:8000/api`

## Run Laravel API

```bash
cd laravel
composer install
cp .env.example .env   # then set APP_KEY, mail, etc.
php artisan key:generate
# sqlite file already at database/database.sqlite (or run migrate --seed)
php artisan serve --host=127.0.0.1 --port=8000
```

### Demo accounts (seeded)

- Customer: `customer@amoraflorals.com` / `customer123`
- Admin: `admin@amoraflorals.com` / `password123`

### Notes

- Do **not** commit `laravel/.env` (Gmail SMTP secrets stay local).
- Admin web is in a separate project (`amoraweb`) — not in this repo yet.
