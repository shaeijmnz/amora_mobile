import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:amora_florals_mobile/auth.dart';
import 'package:amora_florals_mobile/services/api_config.dart';
import 'package:amora_florals_mobile/services/auth_api.dart';
import 'package:amora_florals_mobile/services/custom_request_api.dart';
import 'package:amora_florals_mobile/services/message_api.dart';
import 'package:amora_florals_mobile/services/order_api.dart';
import 'package:amora_florals_mobile/services/product_api.dart';
import 'package:amora_florals_mobile/web_url_clean.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AmoraFloralsApp());
}

class AmoraFloralsApp extends StatelessWidget {
  const AmoraFloralsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amora Florals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Opaque cream — transparent + failed first paint looks like a blank Safari page.
        scaffoldBackgroundColor: Dream.cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Dream.rose,
          primary: Dream.rose,
          surface: Dream.cream,
        ),
        // A rose seed makes Material's tertiary tones amber, which the delivery
        // time picker uses for the AM/PM block. Pin it back to the blush palette.
        timePickerTheme: TimePickerThemeData(
          dayPeriodColor: Dream.blush,
          dayPeriodTextColor: Dream.ink,
          dayPeriodBorderSide: const BorderSide(color: Dream.rose),
          hourMinuteColor: Dream.blush.withValues(alpha: 0.45),
          hourMinuteTextColor: Dream.ink,
          dialBackgroundColor: Dream.blush.withValues(alpha: 0.35),
          dialHandColor: Dream.rose,
          dialTextColor: Dream.ink,
          entryModeIconColor: Dream.roseDeep,
          helpTextStyle: const TextStyle(color: Dream.ink, fontWeight: FontWeight.w700),
        ),
        // Don't block first frame on Google Fonts network fetch (common Safari white screen).
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: Dream.ink,
          displayColor: Dream.ink,
        ),
      ),
      builder: (context, child) {
        ErrorWidget.builder = (details) {
          return Material(
            color: Dream.cream,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Something went wrong.\n${details.exceptionAsString()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Dream.ink, fontSize: 14),
                ),
              ),
            ),
          );
        };
        return child ?? const SizedBox.shrink();
      },
      home: const DreamWorld(child: SessionGate()),
    );
  }
}

/// Restores saved login so Safari refresh stays signed in.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  bool checking = true;
  bool signedIn = false;
  bool showAuth = false;
  bool startOnLogin = true;
  String? paymentReturn; // success | cancel
  int? paymentOrderId;

  @override
  void initState() {
    super.initState();
    final uri = Uri.base;
    paymentReturn = uri.queryParameters['payment'];
    paymentOrderId = int.tryParse(uri.queryParameters['order_id'] ?? '');
    _restore();
  }

  Future<void> _restore() async {
    try {
      final token = await AuthApi().getToken().timeout(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        signedIn = token != null && token.isNotEmpty;
        checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        signedIn = false;
        checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (checking) {
      return const Scaffold(
        backgroundColor: Dream.cream,
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6, color: Dream.roseDeep),
          ),
        ),
      );
    }
    if (!signedIn) {
      if (!showAuth) {
        return LandingScreen(
          onLogin: () => setState(() {
            startOnLogin = true;
            showAuth = true;
          }),
          onSignup: () => setState(() {
            startOnLogin = false;
            showAuth = true;
          }),
        );
      }
      return AuthScreen(
        startOnLogin: startOnLogin,
        onBack: () => setState(() => showAuth = false),
      );
    }

    if (paymentReturn == 'success' || paymentReturn == 'cancel') {
      return PaymentReturnScreen(
        success: paymentReturn == 'success',
        orderId: paymentOrderId,
        onDone: () {
          setState(() {
            paymentReturn = null;
            paymentOrderId = null;
          });
        },
      );
    }

    return const MainShell();
  }
}

/// First screen on the phone and in the browser, before login.
class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key, required this.onLogin, required this.onSignup});

  final VoidCallback onLogin;
  final VoidCallback onSignup;

  @override
  Widget build(BuildContext context) {
    return DreamWorld(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520;
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(22, compact ? 8 : 28, 22, compact ? 12 : 28),
                        child: _LandingStory(
                          compact: compact,
                          onLogin: onLogin,
                          onSignup: onSignup,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LandingStory extends StatelessWidget {
  const _LandingStory({required this.compact, required this.onLogin, required this.onSignup});

  final bool compact;
  final VoidCallback onLogin;
  final VoidCallback onSignup;

  Widget _action(String label, VoidCallback onTap, {required bool primary}) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: BloomTap(
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: primary ? Dream.petal : null,
            color: primary ? null : Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: primary ? null : Border.all(color: Dream.blush),
          ),
          child: Text(
            label,
            style: F.ui(15, color: primary ? Colors.white : Dream.roseDeep, weight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlowerLogo(size: compact ? 52 : 64),
          SizedBox(height: compact ? 2 : 8),
          Text(
            'Amora',
            style: F.script(compact ? 60 : 76, color: Dream.roseDeep),
            textAlign: TextAlign.center,
          ),
          Transform.translate(
            offset: const Offset(0, -6),
            child: Text(
              'Florals',
              style: F.display(compact ? 20 : 24, style: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A flower shop in Quezon City.',
            style: F.ui(compact ? 15 : 16, color: Dream.ink, height: 1.35),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: compact ? 14 : 18),
          const SoftGlass(
            radius: 18,
            padding: EdgeInsets.fromLTRB(14, 12, 14, 6),
            border: Dream.blush,
            child: Column(
              children: [
                _LandingPoint(icon: Icons.local_florist_rounded, title: 'Order', text: 'Choose a bouquet from the shop.'),
                _LandingPoint(icon: Icons.event_rounded, title: 'Delivery', text: 'Set the date and the time.'),
                _LandingPoint(icon: Icons.chat_bubble_outline_rounded, title: 'Message', text: 'Write the admin in one thread.'),
              ],
            ),
          ),
          SizedBox(height: compact ? 12 : 16),
          _action('Log in', onLogin, primary: true),
          const SizedBox(height: 10),
          _action('Create account', onSignup, primary: false),
        ],
      ),
    );
  }
}

class _LandingPoint extends StatelessWidget {
  const _LandingPoint({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: Dream.blush.withValues(alpha: 0.55), shape: BoxShape.circle),
            child: Icon(icon, color: Dream.roseDeep, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: F.display(16)),
                Text(text, style: F.ui(12, color: Dream.mist, height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Dream tokens (inspired by your moodboards)
// ═══════════════════════════════════════════
class Dream {
  // Logo palette — dusty rose + terracotta florals
  static const rose = Color(0xFFE8979E);
  static const roseDeep = Color(0xFFC97B85);
  static const blush = Color(0xFFF0C4C8);
  static const cream = Color(0xFFFBF6F3);
  static const peach = Color(0xFFF3E0D6);
  static const terracotta = Color(0xFFC47A5A);
  static const rust = Color(0xFFB86B55);
  static const lavender = Color(0xFFD4A5A8);
  static const sage = Color(0xFFB8A99A);
  static const ink = Color(0xFF4A3538);
  static const mist = Color(0xFF9A7F82);
  static const star = Color(0xFFE8B88A);
  static const archWhite = Color(0xFFFFFFF8);

  static LinearGradient get sky => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBF6F3), Color(0xFFF5E6E4), Color(0xFFEFD6D4)],
  );

  static LinearGradient get petal => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8979E), Color(0xFFC97B85), Color(0xFFC47A5A)],
  );

  static LinearGradient get softCard => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withValues(alpha: 0.94),
      const Color(0xFFFBF6F3).withValues(alpha: 0.9),
    ],
  );
}

class F {
  /// Calligraphic brand script (Sage-like flourishes).
  static TextStyle script(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w400,
  }) =>
      const TextStyle(
        fontFamily: 'Allura',
        height: 0.95,
      ).copyWith(
        fontSize: size,
        fontWeight: weight,
        color: color ?? Dream.ink,
      );

  static TextStyle display(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
    FontStyle? style,
  }) =>
      const TextStyle(
        fontFamily: 'CormorantGaramond',
        height: 1.15,
        letterSpacing: -0.3,
      ).copyWith(
        fontSize: size,
        fontWeight: weight,
        fontStyle: style,
        color: color ?? Dream.ink,
      );

  static TextStyle ui(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w500,
    double? height,
    double? tracking,
  }) =>
      const TextStyle(
        fontFamily: 'Quicksand',
      ).copyWith(
        fontSize: size,
        fontWeight: weight,
        color: color ?? Dream.ink,
        height: height,
        letterSpacing: tracking,
      );

  static TextStyle whisper(
    double size, {
    Color? color,
  }) =>
      TextStyle(
        fontFamily: 'Montserrat',
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: 2.4,
        color: color ?? Dream.lavender,
      );
}

// ═══════════════════════════════════════════
// Catalog + chat data
// ═══════════════════════════════════════════
class SizePrice {
  const SizePrice({this.id, required this.label, required this.priceFrom});
  final int? id;
  final String label;
  final int priceFrom;

  String get display {
    final raw = priceFrom.toString();
    final withComma = raw.length > 3
        ? '${raw.substring(0, raw.length - 3)},${raw.substring(raw.length - 3)}'
        : raw;
    return '₱$withComma+';
  }
}

class FlowerProduct {
  const FlowerProduct({
    this.id,
    this.sizeId,
    required this.name,
    required this.price,
    required this.rating,
    required this.reviews,
    required this.imageUrl,
    required this.category,
    this.gallery = const [],
    this.sizes = const [],
    this.description =
        'Pre-order bloom from Amora Florals. Prices may change without prior notice due to supply and seasonal fluctuations. Free greeting card included.',
    this.note,
    this.isStem = false,
  });

  final int? id;
  final int? sizeId;
  final String name;
  final String price;
  final String rating;
  final String reviews;
  final String imageUrl;
  final String category;
  final List<String> gallery;
  final List<SizePrice> sizes;
  final String description;
  final String? note;
  final bool isStem;

  List<String> get images => [imageUrl, ...gallery.where((g) => g != imageUrl)];

  int get sortPrice {
    if (sizes.isNotEmpty) return sizes.first.priceFrom;
    final digits = RegExp(r'\d+').allMatches(price).map((m) => m.group(0)!).join();
    return int.tryParse(digits) ?? 0;
  }
}

enum CatalogSort { featured, nameAsc, priceLow, priceHigh, rating }

const assortmentCategories = <(String, IconData)>[
  ('All', Icons.grid_view_rounded),
  ('Bouquets', Icons.local_florist_rounded),
  ('Roses', Icons.favorite_rounded),
  ('Stems', Icons.spa_rounded),
];

String normalizeCategory(String? label) {
  final n = (label ?? 'all').trim().toLowerCase();
  if (n.isEmpty || n == 'all' || n == 'flower' || n == 'flowers') return 'all';
  if (n.startsWith('bouquet')) return 'bouquets';
  if (n.startsWith('rose')) return 'roses';
  if (n.startsWith('stem')) return 'stems';
  return n;
}

bool productMatchesCategory(FlowerProduct p, String category) {
  switch (normalizeCategory(category)) {
    case 'all':
      return true;
    case 'bouquets':
      return p.category.contains('bouquet');
    case 'roses':
      return p.category.contains('rose');
    case 'stems':
      return p.isStem || p.category.contains('stem');
    default:
      final q = category.toLowerCase();
      return p.name.toLowerCase().contains(q) || p.category.toLowerCase().contains(q);
  }
}

List<FlowerProduct> catalogProducts({
  String query = '',
  String category = 'all',
  CatalogSort sort = CatalogSort.featured,
}) {
  final q = query.trim().toLowerCase();
  // If the typed query is itself a category word, prefer that category.
  final queryAsCategory = normalizeCategory(q);
  final effectiveCategory = (q.isNotEmpty && queryAsCategory != 'all' && normalizeCategory(category) == 'all')
      ? queryAsCategory
      : category;
  final textQuery = (q.isNotEmpty && normalizeCategory(q) != 'all' && q == queryAsCategory) ? '' : q;

  var list = products.where((p) {
    if (!productMatchesCategory(p, effectiveCategory)) return false;
    if (textQuery.isEmpty) return true;
    return p.name.toLowerCase().contains(textQuery) || p.category.toLowerCase().contains(textQuery);
  }).toList();

  switch (sort) {
    case CatalogSort.featured:
      break;
    case CatalogSort.nameAsc:
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case CatalogSort.priceLow:
      list.sort((a, b) => a.sortPrice.compareTo(b.sortPrice));
    case CatalogSort.priceHigh:
      list.sort((a, b) => b.sortPrice.compareTo(a.sortPrice));
    case CatalogSort.rating:
      list.sort((a, b) => (double.tryParse(b.rating) ?? 0).compareTo(double.tryParse(a.rating) ?? 0));
  }
  return list;
}

const _localCatalog = <FlowerProduct>[
  FlowerProduct(
    id: 1,
    sizeId: 1,
    name: 'China Roses Bouquet',
    price: '₱1+',
    rating: '4.9',
    reviews: '86',
    imageUrl: 'assets/images/products/china_roses.jpg',
    gallery: ['assets/images/products/china_roses_1.jpg'],
    category: 'bouquet rose',
    sizes: [
      SizePrice(id: 1, label: '1pc', priceFrom: 1),
      SizePrice(id: 2, label: '3pcs', priceFrom: 1),
      SizePrice(id: 3, label: '5pcs', priceFrom: 1),
      SizePrice(id: 4, label: '10pcs', priceFrom: 1),
    ],
  ),
  FlowerProduct(
    id: 2,
    sizeId: 5,
    name: 'Sunflower Bouquet',
    price: '₱1+',
    rating: '4.8',
    reviews: '74',
    imageUrl: 'assets/images/products/sunflower.jpg',
    gallery: ['assets/images/products/sunflower_1.jpg'],
    category: 'bouquet sunflower',
    sizes: [
      SizePrice(id: 5, label: '1pc', priceFrom: 1),
      SizePrice(id: 6, label: '3pcs', priceFrom: 1),
      SizePrice(id: 7, label: '5pcs', priceFrom: 1),
      SizePrice(id: 8, label: '10pcs', priceFrom: 1),
    ],
  ),
  FlowerProduct(
    name: 'Gerbera / Daisy Bouquet',
    price: '₱1+',
    rating: '4.8',
    reviews: '91',
    imageUrl: 'assets/images/products/gerbera_daisy.jpg',
    gallery: ['assets/images/products/gerbera_daisy_1.jpg'],
    category: 'bouquet daisy gerbera',
    sizes: [
      SizePrice(id: 9, label: '1pc', priceFrom: 1),
      SizePrice(id: 10, label: '3pcs', priceFrom: 1),
      SizePrice(id: 11, label: '5pcs', priceFrom: 1),
      SizePrice(id: 12, label: '10pcs', priceFrom: 1),
    ],
  ),
  FlowerProduct(
    name: 'Carnation Bouquet',
    price: '₱1+',
    rating: '4.7',
    reviews: '68',
    imageUrl: 'assets/images/products/carnation.jpg',
    gallery: ['assets/images/products/carnation_1.jpg'],
    category: 'bouquet carnation',
    sizes: [
      SizePrice(id: 13, label: '1pc', priceFrom: 1),
      SizePrice(id: 14, label: '3pcs', priceFrom: 1),
      SizePrice(id: 15, label: '5pcs', priceFrom: 1),
      SizePrice(id: 16, label: '10pcs', priceFrom: 1),
    ],
  ),
  FlowerProduct(
    id: 5,
    sizeId: 17,
    name: 'Stargazer Lilies',
    price: '₱1',
    rating: '4.9',
    reviews: '52',
    imageUrl: 'assets/images/products/stargazer_lilies.jpg',
    gallery: ['assets/images/products/stargazer_lilies_1.jpg'],
    category: 'stem lily',
    isStem: true,
    sizes: [SizePrice(id: 17, label: '1 stem', priceFrom: 1)],
    note: 'Price per stem, unarranged. Additional charges may apply if arranged as a bouquet.',
  ),
  FlowerProduct(
    id: 6,
    sizeId: 18,
    name: 'Sunlight Chrysanthemum',
    price: '₱1',
    rating: '4.7',
    reviews: '41',
    imageUrl: 'assets/images/products/sunlight_chrysanthemum.jpg',
    gallery: ['assets/images/products/sunlight_chrysanthemum_1.jpg'],
    category: 'stem chrysanthemum',
    isStem: true,
    sizes: [SizePrice(id: 18, label: '1 stem', priceFrom: 1)],
    note: 'Price per stem, unarranged. Additional charges may apply if arranged as a bouquet.',
  ),
  FlowerProduct(
    id: 7,
    sizeId: 19,
    name: 'Hydrangea',
    price: '₱1',
    rating: '4.8',
    reviews: '57',
    imageUrl: 'assets/images/products/hydrangea.jpg',
    gallery: ['assets/images/products/hydrangea_1.jpg'],
    category: 'stem hydrangea',
    isStem: true,
    sizes: [SizePrice(id: 19, label: '1 stem', priceFrom: 1)],
    note: 'Price per stem, unarranged. Additional charges may apply if arranged as a bouquet.',
  ),
];

/// Live catalog from Laravel `/api/products`. Falls back to [_localCatalog] if offline.
List<FlowerProduct> products = List<FlowerProduct>.from(_localCatalog);

class ChatThread {
  const ChatThread({
    required this.id,
    required this.name,
    required this.role,
    required this.avatar,
    required this.preview,
    required this.time,
    required this.unread,
    required this.online,
    required this.messages,
  });

  final String id;
  final String name;
  final String role;
  final String avatar;
  final String preview;
  final String time;
  final int unread;
  final bool online;
  final List<ChatMessage> messages;
}

class ChatMessage {
  const ChatMessage({
    this.id,
    required this.text,
    required this.mine,
    required this.time,
  });

  final int? id;
  final String text;
  final bool mine;
  final String time;
}

ChatThread studioThread({
  String preview = 'Ask the shop about a bouquet or an order.',
  String time = '',
  int unread = 0,
  List<ChatMessage> messages = const [],
}) {
  return ChatThread(
    id: 'amora',
    name: 'Admin',
    role: 'Amora Florals',
    avatar: '',
    preview: preview,
    time: time,
    unread: unread,
    online: true,
    messages: messages,
  );
}

ChatThread threadFromShop(ShopThread shop) {
  return studioThread(
    preview: shop.preview,
    time: shop.time,
    unread: shop.unread,
    messages: shop.messages
        .map((m) => ChatMessage(id: m.id, text: m.body, mine: m.mine, time: m.time))
        .toList(),
  );
}

// ═══════════════════════════════════════════
// Dreamy world atmosphere
// ═══════════════════════════════════════════
class DreamWorld extends StatefulWidget {
  const DreamWorld({super.key, required this.child});
  final Widget child;

  @override
  State<DreamWorld> createState() => _DreamWorldState();
}

class _DreamWorldState extends State<DreamWorld>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    // A full-screen sparkle loop repaints every frame. On Safari that makes
    // the catalog stutter while someone is scrolling through the demo, so the
    // web build keeps the same scene still.
    if (!kIsWeb) {
      _c = AnimationController(vsync: this, duration: const Duration(seconds: 14))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Widget _scene(double t, Widget? child) {
        return Stack(
          children: [
            Container(decoration: BoxDecoration(gradient: Dream.sky)),
            Positioned(
              top: -80 + 40 * math.sin(t * math.pi * 2),
              right: -40,
              child: _GlowOrb(size: 300, color: Dream.rose.withValues(alpha: 0.28)),
            ),
            Positioned(
              top: 180 + 30 * math.cos(t * math.pi * 2),
              left: -100,
              child: _GlowOrb(size: 260, color: Dream.lavender.withValues(alpha: 0.22)),
            ),
            Positioned(
              bottom: -30 + 25 * math.sin(t * math.pi * 2 + 1),
              right: 40,
              child: _GlowOrb(size: 200, color: Dream.peach.withValues(alpha: 0.55)),
            ),
            Positioned(
              bottom: 120,
              left: 30,
              child: _GlowOrb(size: 140, color: Dream.sage.withValues(alpha: 0.18)),
            ),
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _SparkleField(t))),
            ),
            Positioned.fill(
              child: IgnorePointer(child: CustomPaint(painter: _PetalDrift(t))),
            ),
            child!,
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    final motion = _c;
    if (motion == null) return _scene(0.35, widget.child);
    return AnimatedBuilder(
      animation: motion,
      builder: (context, child) => _scene(motion.value, child),
      child: widget.child,
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}

class _SparkleField extends CustomPainter {
  _SparkleField(this.t);
  final double t;

  static const pts = [
    (0.10, 0.12, 1.0),
    (0.28, 0.07, 0.55),
    (0.52, 0.16, 0.85),
    (0.76, 0.09, 0.5),
    (0.90, 0.24, 1.1),
    (0.14, 0.46, 0.6),
    (0.40, 0.40, 0.95),
    (0.66, 0.52, 0.5),
    (0.86, 0.66, 0.8),
    (0.22, 0.76, 0.55),
    (0.48, 0.86, 0.9),
    (0.72, 0.80, 0.45),
    (0.58, 0.30, 0.4),
    (0.34, 0.62, 0.7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < pts.length; i++) {
      final phase = (t + i * 0.07) % 1;
      final pulse = 0.55 + 0.45 * math.sin(phase * math.pi * 2);
      final drift = math.sin((t + i * 0.11) * math.pi * 2) * 6;
      final o = Offset(pts[i].$1 * size.width, pts[i].$2 * size.height + drift);
      final r = (5.5 + pts[i].$3 * 7) * (0.75 + pulse * 0.35);
      canvas.save();
      canvas.translate(o.dx, o.dy);
      canvas.rotate(t * math.pi * 0.4 + i * 0.2);
      DreamSparkle.paint(
        canvas,
        radius: r,
        points: i.isEven ? 8 : 4,
        opacity: 0.35 + pulse * 0.55,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleField old) => old.t != t;
}

/// Soft pink 4/8-point sparkles matching the reference art.
class DreamSparkle {
  static void paint(
    Canvas canvas, {
    required double radius,
    int points = 8,
    double opacity = 1,
  }) {
    final path = _starPath(radius, points);
    final fill = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFFDF9).withValues(alpha: opacity),
          const Color(0xFFF7A0B8).withValues(alpha: opacity * 0.85),
          const Color(0xFFE8789A).withValues(alpha: opacity * 0.35),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    canvas.drawPath(path, fill);

    final glow = Paint()
      ..color = const Color(0xFFF7A0B8).withValues(alpha: 0.22 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset.zero, radius * 0.35, glow);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, radius * 0.08)
      ..color = const Color(0xFFC45A7A).withValues(alpha: 0.75 * opacity);
    canvas.drawPath(path, stroke);
  }

  static Path _starPath(double radius, int points) {
    final path = Path();
    final count = points;
    for (var i = 0; i < count; i++) {
      final angle = -math.pi / 2 + (i * 2 * math.pi / count);
      final tip = Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      final midAngle = angle + math.pi / count;
      final waist = Offset(
        math.cos(midAngle) * radius * 0.16,
        math.sin(midAngle) * radius * 0.16,
      );
      if (i == 0) {
        path.moveTo(tip.dx, tip.dy);
      } else {
        path.lineTo(tip.dx, tip.dy);
      }
      path.lineTo(waist.dx, waist.dy);
    }
    path.close();
    return path;
  }
}

class SparkleMark extends StatelessWidget {
  const SparkleMark({
    super.key,
    this.size = 18,
    this.points = 8,
    this.opacity = 1,
  });

  final double size;
  final int points;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _SparkleMarkPainter(points: points, opacity: opacity),
    );
  }
}

class _SparkleMarkPainter extends CustomPainter {
  _SparkleMarkPainter({required this.points, required this.opacity});
  final int points;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    DreamSparkle.paint(
      canvas,
      radius: size.shortestSide / 2,
      points: points,
      opacity: opacity,
    );
  }

  @override
  bool shouldRepaint(covariant _SparkleMarkPainter old) =>
      old.points != points || old.opacity != opacity;
}

class TwinkleSparkle extends StatefulWidget {
  const TwinkleSparkle({
    super.key,
    this.size = 18,
    this.points = 8,
    this.delay = Duration.zero,
  });

  final double size;
  final int points;
  final Duration delay;

  @override
  State<TwinkleSparkle> createState() => _TwinkleSparkleState();
}

class _TwinkleSparkleState extends State<TwinkleSparkle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.scale(
          scale: 0.82 + t * 0.28,
          child: Opacity(
            opacity: 0.45 + t * 0.55,
            child: SparkleMark(size: widget.size, points: widget.points),
          ),
        );
      },
    );
  }
}

class FlowerLogo extends StatelessWidget {
  const FlowerLogo({super.key, this.size = 44});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Dream.petal,
              boxShadow: [
                BoxShadow(
                  color: Dream.rose.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
          ),
          Icon(
            Icons.local_florist_rounded,
            size: size * 0.52,
            color: Colors.white,
          ),
          Positioned(
            top: 2,
            right: 2,
            child: SparkleMark(size: size * 0.28, points: 4),
          ),
        ],
      ),
    );
  }
}

class _PetalDrift extends CustomPainter {
  _PetalDrift(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < 7; i++) {
      final x = ((0.1 + i * 0.13 + math.sin(t * math.pi * 2 + i) * 0.04) % 1) * size.width;
      final y = ((0.15 + i * 0.12 + t + i * 0.07) % 1) * size.height;
      paint.color = [
        Dream.rose,
        Dream.blush,
        Dream.lavender,
        Dream.peach,
      ][i % 4]
          .withValues(alpha: 0.14);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * math.pi * 2 + i);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 18, height: 10), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PetalDrift old) => old.t != t;
}

class SoftGlass extends StatelessWidget {
  const SoftGlass({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding,
    this.margin,
    this.blur = 16,
    this.fill = 0.55,
    this.border,
    this.glow,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blur;
  final double fill;
  final Color? border;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    // Avoid BackdropFilter — it often blanks/blurs the whole Flutter web UI.
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Color.lerp(Colors.white, Dream.cream, 0.35)!.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border!),
        boxShadow: [
          BoxShadow(
            color: (glow ?? Dream.rose).withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class BloomTap extends StatefulWidget {
  const BloomTap({super.key, required this.child, this.onTap, this.scale = 0.96});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<BloomTap> createState() => _BloomTapState();
}

class _BloomTapState extends State<BloomTap> {
  bool down = false;
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    final lift = hover && !down;
    return MouseRegion(
      onEnter: (_) => setState(() => hover = true),
      onExit: (_) => setState(() => hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => down = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => down = false),
        onTapCancel: widget.onTap == null ? null : () => setState(() => down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: down ? widget.scale : (lift ? 1.03 : 1),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            transform: Matrix4.translationValues(0, lift ? -6 : 0, 0),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class FloatIn extends StatelessWidget {
  const FloatIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.dy = 10,
  });

  final Widget child;
  final Duration delay;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Interval(
        (delay.inMilliseconds / 480).clamp(0.0, 0.6),
        1.0,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, (1 - t) * dy), child: child),
      ),
      child: child,
    );
  }
}

class NetImage extends StatelessWidget {
  const NetImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Dream.peach, Dream.blush])),
      child: const Icon(Icons.local_florist_rounded, color: Dream.roseDeep),
    );
    final resolved = ApiConfig.resolveImageUrl(url);
    if (resolved.startsWith('assets/')) {
      return Image.asset(
        resolved,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }
    return Image.network(
      resolved,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}

class HeartPop extends StatefulWidget {
  const HeartPop({
    super.key,
    required this.liked,
    required this.onToggle,
  });

  final bool liked;
  final VoidCallback onToggle;

  @override
  State<HeartPop> createState() => _HeartPopState();
}

class _HeartPopState extends State<HeartPop> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 480));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        widget.onToggle();
        _c.forward(from: 0);
      },
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final b = Curves.elasticOut.transform(_c.value.clamp(0.0, 1.0));
          return Transform.scale(
            scale: widget.liked ? 0.86 + b * 0.28 : 1,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Dream.rose.withValues(alpha: 0.18), blurRadius: 10),
                ],
              ),
              child: Icon(
                widget.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 16,
                color: widget.liked ? Dream.roseDeep : Dream.mist,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shared wishlist across Home / Search / Wishlist / Profile.
class WishlistController extends ChangeNotifier {
  final Set<String> _names = {};

  bool isWished(String name) => _names.contains(name);

  int get count => _names.length;

  List<FlowerProduct> get items =>
      products.where((p) => _names.contains(p.name)).toList(growable: false);

  void toggle(String name) {
    if (!_names.remove(name)) _names.add(name);
    notifyListeners();
  }

  void remove(String name) {
    if (_names.remove(name)) notifyListeners();
  }
}

class CartItem {
  CartItem({
    this.productId,
    required this.sizeId,
    required this.name,
    required this.imageUrl,
    required this.sizeLabel,
    required this.priceFrom,
    this.quantity = 1,
  });

  final int? productId;
  final int sizeId;
  final String name;
  final String imageUrl;
  final String sizeLabel;
  final int priceFrom;
  int quantity;

  String get priceDisplay {
    final raw = priceFrom.toString();
    final withComma = raw.length > 3
        ? '${raw.substring(0, raw.length - 3)},${raw.substring(raw.length - 3)}'
        : raw;
    return '₱$withComma+';
  }

  int get lineTotal => priceFrom * quantity;
}

class CartController extends ChangeNotifier {
  CartController() {
    load();
  }

  static const _storageKey = 'amora_cart_v1';

  final List<CartItem> _items = [];
  int _pulse = 0;

  int get count => _items.fold(0, (sum, item) => sum + item.quantity);
  int get pulse => _pulse;
  bool get isEmpty => _items.isEmpty;
  List<CartItem> get items => List.unmodifiable(_items);

  int get subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);

  String get subtotalDisplay {
    final raw = subtotal.toString();
    final withComma = raw.length > 3
        ? '${raw.substring(0, raw.length - 3)},${raw.substring(raw.length - 3)}'
        : raw;
    return '₱$withComma+';
  }

  /// Stable local key when API size ids are missing (offline catalog).
  static int localSizeKey(String name, String sizeLabel) {
    return Object.hash(name, sizeLabel).abs() % 900000 + 100000;
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _items
        ..clear()
        ..addAll(
          decoded.whereType<Map>().map((e) {
            final m = Map<String, dynamic>.from(e);
            return CartItem(
              productId: m['productId'] as int?,
              sizeId: (m['sizeId'] as num).toInt(),
              name: m['name']?.toString() ?? '',
              imageUrl: m['imageUrl']?.toString() ?? '',
              sizeLabel: m['sizeLabel']?.toString() ?? '',
              priceFrom: (m['priceFrom'] as num?)?.toInt() ?? 0,
              quantity: (m['quantity'] as num?)?.toInt() ?? 1,
            );
          }),
        );
      notifyListeners();
    } catch (_) {
      // Ignore corrupt local cart.
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = [
        for (final item in _items)
          {
            'productId': item.productId,
            'sizeId': item.sizeId,
            'name': item.name,
            'imageUrl': item.imageUrl,
            'sizeLabel': item.sizeLabel,
            'priceFrom': item.priceFrom,
            'quantity': item.quantity,
          },
      ];
      await prefs.setString(_storageKey, jsonEncode(payload));
    } catch (_) {}
  }

  void _changed({bool pulse = false}) {
    if (pulse) _pulse++;
    notifyListeners();
    _persist();
  }

  void addFromProduct(
    FlowerProduct product, {
    required String sizeLabel,
    required int quantity,
    int? sizeId,
    int? priceFrom,
  }) {
    final sid = sizeId ?? product.sizeId ?? localSizeKey(product.name, sizeLabel);
    final price = priceFrom ?? product.sortPrice;
    CartItem? existing;
    for (final item in _items) {
      if (item.sizeId == sid) {
        existing = item;
        break;
      }
    }
    if (existing != null) {
      existing.quantity += quantity;
    } else {
      _items.add(
        CartItem(
          productId: product.id,
          sizeId: sid,
          name: product.name,
          imageUrl: product.imageUrl,
          sizeLabel: sizeLabel,
          priceFrom: price,
          quantity: quantity,
        ),
      );
    }
    _changed(pulse: true);
  }

  void setQuantity(int sizeId, int qty) {
    if (qty <= 0) {
      remove(sizeId);
      return;
    }
    for (final item in _items) {
      if (item.sizeId == sizeId) {
        item.quantity = qty;
        _changed();
        return;
      }
    }
  }

  void remove(int sizeId) {
    _items.removeWhere((item) => item.sizeId == sizeId);
    _changed();
  }

  void clear() {
    _items.clear();
    _changed();
  }

  void removeMany(Iterable<int> sizeIds) {
    final ids = sizeIds.toSet();
    _items.removeWhere((item) => ids.contains(item.sizeId));
    _changed();
  }
}

class WishlistScope extends InheritedNotifier<WishlistController> {
  const WishlistScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);

  final WishlistController controller;

  static WishlistController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WishlistScope>();
    assert(scope != null, 'WishlistScope not found');
    return scope!.controller;
  }
}

class CartScope extends InheritedNotifier<CartController> {
  const CartScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);

  final CartController controller;

  static CartController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<CartScope>();
    assert(scope != null, 'CartScope not found');
    return scope!.controller;
  }

  static CartController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CartScope>()?.controller;
  }
}

const homeCategories = <(String, IconData)>[
  ('Bouquets', Icons.local_florist_rounded),
  ('Roses', Icons.favorite_rounded),
  ('Stems', Icons.spa_rounded),
];

String? productBadge(String name) {
  switch (name) {
    case 'China Roses Bouquet':
    case 'Sunflower Bouquet':
      return 'Best Seller';
    case 'Gerbera / Daisy Bouquet':
    case 'Carnation Bouquet':
      return 'Popular';
    case 'Stargazer Lilies':
      return 'Pre-order';
    default:
      return null;
  }
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.reviews, this.compact = false});
  final String rating;
  final String? reviews;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final v = double.tryParse(rating) ?? 0;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            Icon(
              i < v.floor()
                  ? Icons.star_rounded
                  : (i < v ? Icons.star_half_rounded : Icons.star_outline_rounded),
              size: compact ? 12 : 14,
              color: Dream.star,
            ),
          const SizedBox(width: 4),
          Text(
            reviews != null ? (compact ? rating : '($reviews)') : rating,
            style: F.ui(compact ? 10 : 11, color: Dream.mist, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// Shell
// ═══════════════════════════════════════════
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  List<ChatThread> threads = [studioThread()];
  late WishlistController wishlist;
  late CartController cart;
  Timer? _messagePoll;

  @override
  void initState() {
    super.initState();
    wishlist = WishlistController();
    cart = CartController();
    _loadCatalog();
    _loadThread();
    _messagePoll = Timer.periodic(const Duration(seconds: 8), (_) => _loadThread());
  }

  Future<void> _loadCatalog() async {
    try {
      final apiItems = await ProductApi().fetchProducts();
      if (!mounted || apiItems.isEmpty) return;
      final mapped = apiItems
          .map(
            (p) => FlowerProduct(
              id: p.id,
              sizeId: p.sizeId,
              name: p.name,
              price: p.priceLabel,
              rating: p.rating,
              reviews: p.reviews,
              imageUrl: _catalogImage(p.name, p.imageUrl),
              category: p.category,
              gallery: p.gallery
                  .map((url) => _catalogImage(p.name, url))
                  .where((url) => url.isNotEmpty)
                  .toList(),
              sizes: p.sizes
                  .map((s) => SizePrice(id: s.id, label: s.label, priceFrom: s.price.round()))
                  .toList(),
              description: p.description ??
                  'Pre-order bloom from Amora Florals. Prices may change without prior notice due to supply and seasonal fluctuations. Free greeting card included.',
              note: p.note,
              isStem: p.isStem,
            ),
          )
          .where((p) => p.imageUrl.isNotEmpty)
          .toList();
      if (mapped.isEmpty) return;
      setState(() => products = mapped);
    } catch (_) {
      // Keep [_localCatalog] when Laravel is offline.
    }
  }

  String _catalogImage(String name, String url) {
    if (url.isNotEmpty && !url.toLowerCase().contains('unsplash')) {
      return url;
    }
    for (final local in _localCatalog) {
      if (local.name.toLowerCase() == name.toLowerCase()) {
        return local.imageUrl;
      }
    }
    return url;
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot reload can leave newly-added controllers uninitialized — recreate safely.
    wishlist = WishlistController();
    cart = CartController();
  }

  @override
  void dispose() {
    _messagePoll?.cancel();
    wishlist.dispose();
    cart.dispose();
    super.dispose();
  }

  Future<void> _loadThread() async {
    try {
      final shop = await MessageApi().fetch();
      if (!mounted) return;
      setState(() => threads = [threadFromShop(shop)]);
    } catch (_) {
      // Keep the Amora Studio thread so the inbox still opens offline.
    }
  }

  void _rememberThread(ChatThread next) {
    if (!mounted) return;
    setState(() => threads = [next]);
  }

  Future<void> _openStudioChat({String? productHint}) async {
    if (productHint != null) {
      try {
        final shop = await MessageApi().send('Hi! I\'d love to ask about $productHint');
        _rememberThread(threadFromShop(shop));
      } catch (_) {}
    } else {
      await _loadThread();
    }
    if (!mounted) return;
    final thread = threads.isEmpty ? studioThread() : threads.first;
    await Navigator.push(
      context,
      _dreamRoute(ChatRoomScreen(
        thread: thread,
        onUpdated: _rememberThread,
      )),
    );
    _loadThread();
  }

  void _openInbox({String? focusId, String? productHint}) {
    if (focusId != null || productHint != null) {
      _openStudioChat(productHint: productHint);
      return;
    }
    setState(() => index = 2);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        onProductChat: (p) => _openInbox(productHint: p),
        onOpenWishlist: () => setState(() => index = 3),
        onOpenCart: () {
          Navigator.of(context).push(
            _dreamRoute(
              WishlistScope(
                controller: wishlist,
                child: CartScope(
                  controller: cart,
                  child: const CartScreen(),
                ),
              ),
            ),
          );
        },
      ),
      const MyOrdersScreen(),
      InboxScreen(
        threads: threads,
        onOpen: (t) {
          Navigator.push(
            context,
            _dreamRoute(ChatRoomScreen(
              thread: t,
              onUpdated: _rememberThread,
            )),
          ).then((_) => _loadThread());
        },
      ),
      WishlistScreen(
        onBrowse: () => setState(() => index = 0),
        onProductChat: (p) => _openInbox(productHint: p),
      ),
      ProfileScreen(
        onOpenOrders: () => setState(() => index = 1),
        onOpenMessages: () => setState(() => index = 2),
      ),
    ];

    return WishlistScope(
      controller: wishlist,
      child: CartScope(
        controller: cart,
        child: DreamWorld(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: pages[index],
            bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: SizedBox(
              height: 72,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xF2FBF6F3),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Dream.rose.withValues(alpha: 0.14),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _NavItem(
                            selected: index == 0,
                            icon: Icons.home_rounded,
                            label: 'Home',
                            onTap: () => setState(() => index = 0),
                          ),
                          _NavItem(
                            selected: index == 1,
                            icon: Icons.receipt_long_rounded,
                            label: 'Orders',
                            onTap: () => setState(() => index = 1),
                          ),
                          const SizedBox(width: 56),
                          _NavItem(
                            selected: index == 3,
                            icon: Icons.favorite_border_rounded,
                            label: 'Favorites',
                            onTap: () => setState(() => index = 3),
                          ),
                          _NavItem(
                            selected: index == 4,
                            icon: Icons.person_outline_rounded,
                            label: 'Profile',
                            onTap: () => setState(() => index = 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    child: BloomTap(
                      onTap: () => setState(() => index = 2),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: Dream.petal,
                              boxShadow: [
                                BoxShadow(
                                  color: Dream.rose.withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_florist_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          if (threads.any((t) => t.unread > 0))
                            Positioned(
                              right: -2,
                              top: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Dream.roseDeep,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Text(
                                  '${threads.fold<int>(0, (sum, t) => sum + t.unread)}',
                                  style: F.ui(10, color: Colors.white, weight: FontWeight.w800),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

Route<T> _dreamRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondary) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: page,
      ),
    ),
  );
}

/// Keep wishlist + cart state available on pushed routes.
Widget keepWishlist(BuildContext context, Widget child) {
  return WishlistScope(
    controller: WishlistScope.of(context),
    child: CartScope(
      controller: CartScope.of(context),
      child: child,
    ),
  );
}

void openCartScreen(BuildContext context) {
  final cart = CartScope.maybeOf(context);
  final wish = context.dependOnInheritedWidgetOfExactType<WishlistScope>()?.controller;

  if (cart == null || wish == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text('Could not open cart. Please try again.', style: F.ui(13, color: Colors.white)),
      ),
    );
    return;
  }

  Navigator.of(context).push(
    _dreamRoute(
      WishlistScope(
        controller: wish,
        child: CartScope(
          controller: cart,
          child: const CartScreen(),
        ),
      ),
    ),
  );
}

void showAddedToCartFeedback(
  BuildContext context, {
  required String label,
  VoidCallback? onViewCart,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      backgroundColor: Dream.roseDeep,
      duration: const Duration(seconds: 2),
      content: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.85 + (value * 0.15),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Added $label to cart', style: F.ui(13, color: Colors.white)),
          ),
        ],
      ),
      action: onViewCart == null
          ? null
          : SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: onViewCart,
            ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Dream.roseDeep : Dream.mist;
    return Expanded(
      child: BloomTap(
        onTap: onTap,
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: F.ui(
                  9,
                  color: color,
                  weight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SoftPlaceholder extends StatelessWidget {
  const SoftPlaceholder({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SoftGlass(
        radius: 32,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Dream.roseDeep),
            const SizedBox(height: 10),
            Text(title, style: F.script(36, color: Dream.roseDeep)),
            Text(subtitle, style: F.whisper(10)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// WISHLIST
// ═══════════════════════════════════════════
class WishlistScreen extends StatelessWidget {
  const WishlistScreen({
    super.key,
    required this.onBrowse,
    required this.onProductChat,
  });

  final VoidCallback onBrowse;
  final ValueChanged<String> onProductChat;

  @override
  Widget build(BuildContext context) {
    final wish = WishlistScope.of(context);
    final items = wish.items;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Wishlist', style: F.script(42, color: Dream.roseDeep)),
                      Text(
                        items.isEmpty
                            ? 'Tap ♥ on flowers to save them here'
                            : '${items.length} saved bloom${items.length == 1 ? '' : 's'}',
                        style: F.ui(13, color: Dream.mist),
                      ),
                    ],
                  ),
                ),
                const TwinkleSparkle(size: 18, points: 8),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: SoftGlass(
                      radius: 28,
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite_border_rounded, size: 42, color: Dream.roseDeep),
                          const SizedBox(height: 10),
                          Text('No daydreams yet', style: F.display(22)),
                          const SizedBox(height: 6),
                          Text(
                            'Save flowers you love and find them here.',
                            style: F.ui(13, color: Dream.mist),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          BloomTap(
                            onTap: onBrowse,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: Dream.petal,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'Browse flowers',
                                style: F.ui(13, color: Colors.white, weight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return FloatIn(
                        delay: Duration(milliseconds: i * 40),
                        child: FlowerCard(
                          product: p,
                          heroTag: 'wish-${p.name}',
                          onTap: () => Navigator.push(
                            context,
                            _dreamRoute(keepWishlist(
                              context,
                              ProductDetailsScreen(
                                product: p,
                                onChat: () => onProductChat(p.name),
                                heroTag: 'wish-${p.name}',
                              ),
                            )),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// PROFILE
// ═══════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.onOpenOrders,
    required this.onOpenMessages,
  });

  final VoidCallback onOpenOrders;
  final VoidCallback onOpenMessages;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String name = '…';
  String email = '';
  int orderCount = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = AuthApi();
    final saved = await api.getSavedUser();
    if (mounted && saved != null) {
      setState(() {
        name = saved['name']?.toString() ?? 'Customer';
        email = saved['email']?.toString() ?? '';
      });
    }
    try {
      final user = await api.fetchMe() ?? saved;
      final orders = await OrderApi().listOrders();
      final paid = orders.where((o) => o['payment_status'] == 'paid').length;
      if (!mounted) return;
      setState(() {
        name = user?['name']?.toString() ?? name;
        email = user?['email']?.toString() ?? email;
        orderCount = paid;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await AuthApi().clearSession();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondary) => FadeTransition(
          opacity: animation,
          child: const DreamWorld(child: SessionGate()),
        ),
      ),
      (_) => false,
    );
  }

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'A';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          FloatIn(
            child: SoftGlass(
              radius: 28,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: Dream.petal,
                    ),
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: Dream.rose.withValues(alpha: 0.25),
                      child: Text(
                        _initials,
                        style: F.ui(22, color: Dream.roseDeep, weight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loading && name == '…' ? 'Loading…' : name,
                          style: F.script(34, color: Dream.roseDeep),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          email.isEmpty ? '—' : email,
                          style: F.ui(12, color: Dream.mist),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Dream.rose.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Soft Bloom Club',
                            style: F.ui(11, color: Dream.roseDeep, weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const TwinkleSparkle(size: 16, points: 8),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FloatIn(
            delay: const Duration(milliseconds: 50),
            child: SoftGlass(
              radius: 18,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: BloomTap(
                onTap: widget.onOpenOrders,
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: Dream.roseDeep, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('My Orders', style: F.ui(14, weight: FontWeight.w800)),
                          Text(
                            loading ? 'Loading…' : '$orderCount paid order${orderCount == 1 ? '' : 's'}',
                            style: F.ui(12, color: Dream.mist),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Dream.mist),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Account', style: F.display(22)),
          const SizedBox(height: 8),
          SoftGlass(
            radius: 22,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _ProfileTile(
                  icon: Icons.receipt_long_rounded,
                  title: 'Order tracking',
                  subtitle: 'See checkout status & delivery',
                  onTap: widget.onOpenOrders,
                ),
                _ProfileTile(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Custom bouquet request',
                  subtitle: 'Ask the florist for a made-to-order arrangement',
                  onTap: () => Navigator.of(context).push(
                    _dreamRoute(const CustomRequestScreen()),
                  ),
                ),
                _ProfileTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Messages',
                  subtitle: 'Chat with the admin',
                  onTap: widget.onOpenMessages,
                ),
                _ProfileTile(
                  icon: Icons.local_shipping_outlined,
                  title: 'Delivery area',
                  subtitle: 'Quezon City, Metro Manila',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.payments_outlined,
                  title: 'Payment',
                  subtitle: 'QR Ph via PayMongo',
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          BloomTap(
            onTap: () => _logout(context),
            child: SoftGlass(
              radius: 20,
              padding: const EdgeInsets.symmetric(vertical: 14),
              border: Dream.roseDeep.withValues(alpha: 0.45),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, color: Dream.roseDeep, size: 18),
                  const SizedBox(width: 8),
                  Text('Log out', style: F.ui(14, color: Dream.roseDeep, weight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BloomTap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Dream.rose.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Dream.roseDeep, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: F.ui(14, weight: FontWeight.w700)),
                  Text(subtitle, style: F.ui(11, color: Dream.mist)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Dream.mist),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// HOME
// ═══════════════════════════════════════════
class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onOpenCart});
  final VoidCallback onOpenCart;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Amora', style: F.script(44, color: Dream.roseDeep)),
              Transform.translate(
                offset: const Offset(0, -10),
                child: Text(
                  'FLORALS',
                  style: F.whisper(9, color: Dream.ink.withValues(alpha: 0.55)),
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            child: _CartBagButton(onOpenCart: onOpenCart),
          ),
        ],
      ),
    );
  }
}

class _CartBagButton extends StatefulWidget {
  const _CartBagButton({required this.onOpenCart});
  final VoidCallback onOpenCart;

  @override
  State<_CartBagButton> createState() => _CartBagButtonState();
}

class _CartBagButtonState extends State<_CartBagButton> with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.32), weight: 45),
    TweenSequenceItem(tween: Tween(begin: 1.32, end: 1.0), weight: 55),
  ]).animate(CurvedAnimation(parent: _bounce, curve: Curves.easeOutBack));
  int _lastPulse = 0;

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _syncPulse(CartController cart) {
    if (cart.pulse != _lastPulse) {
      _lastPulse = cart.pulse;
      if (_lastPulse > 0) _bounce.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.maybeOf(context);
    final cartCount = cart?.count ?? 0;

    return ListenableBuilder(
      listenable: cart ?? Listenable.merge(const []),
      builder: (context, _) {
        if (cart != null) _syncPulse(cart);
        return ScaleTransition(
          scale: _scale,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.onOpenCart,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Dream.rose.withValues(alpha: 0.18),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: Dream.ink, size: 18),
                    if (cartCount > 0)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(scale: animation, child: child);
                          },
                          child: Container(
                            key: ValueKey(cartCount),
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              gradient: Dream.petal,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '$cartCount',
                              style: F.ui(9, color: Colors.white, weight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onProductChat,
    required this.onOpenWishlist,
    required this.onOpenCart,
  });

  final ValueChanged<String> onProductChat;
  final VoidCallback onOpenWishlist;
  final VoidCallback onOpenCart;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final search = TextEditingController();
  final trendingKey = GlobalKey();
  int banner = 0;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void _open(FlowerProduct p) {
    Navigator.push(
      context,
      _dreamRoute(keepWishlist(
        context,
        ProductDetailsScreen(
          product: p,
          onChat: () => widget.onProductChat(p.name),
          heroTag: 'home-${p.name}',
        ),
      )),
    );
  }

  void _search({String? q, String category = 'all', bool openSort = false}) {
    Navigator.push(
      context,
      _dreamRoute(keepWishlist(
        context,
        SearchScreen(
          initialQuery: q ?? search.text,
          initialCategory: category,
          openSortOnStart: openSort,
          onProductChat: widget.onProductChat,
        ),
      )),
    );
  }

  void _scrollTrending() {
    final ctx = trendingKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 480),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _addToCart(FlowerProduct p) {
    if (p.sizes.length > 1) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => keepWishlist(
          context,
          VariantSheet(product: p, checkoutMode: false),
        ),
      );
      return;
    }

    final size = p.sizes.isNotEmpty ? p.sizes.first : null;
    final sizeLabel = size?.label ?? (p.isStem ? '1 stem' : 'Standard');
    final sizeId = size?.id ??
        p.sizeId ??
        CartController.localSizeKey(p.name, sizeLabel);

    CartScope.of(context).addFromProduct(
      p,
      sizeLabel: sizeLabel,
      quantity: 1,
      sizeId: sizeId,
      priceFrom: size?.priceFrom ?? p.sortPrice,
    );
    showAddedToCartFeedback(
      context,
      label: p.name,
      onViewCart: widget.onOpenCart,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: WishlistScope.of(context),
        builder: (context, _) {
          return CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FloatIn(child: _BrandHeader(onOpenCart: widget.onOpenCart)),
                  const SizedBox(height: 6),
                  FloatIn(
                    delay: const Duration(milliseconds: 30),
                    child: SoftGlass(
                      radius: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_rounded, color: Dream.mist, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: search,
                                textInputAction: TextInputAction.search,
                                onSubmitted: (_) => _search(),
                                style: F.ui(13, height: 1.2),
                                cursorColor: Dream.roseDeep,
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: "Search 'Roses' here",
                                  hintStyle: F.ui(13, color: Dream.mist, height: 1.2),
                                ),
                              ),
                            ),
                            BloomTap(
                              onTap: () => _search(openSort: true),
                              child: const Icon(Icons.tune_rounded, color: Dream.mist, size: 18),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FloatIn(
                    delay: const Duration(milliseconds: 60),
                    child: _DreamBanner(
                      index: banner,
                      onShop: _scrollTrending,
                      onPage: (i) => setState(() => banner = i),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FloatIn(
                    delay: const Duration(milliseconds: 90),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final c in homeCategories)
                          Expanded(
                            child: BloomTap(
                              onTap: () => _search(category: c.$1),
                              child: Column(
                                children: [
                                  SoftGlass(
                                    radius: 999,
                                    padding: const EdgeInsets.all(12),
                                    child: Icon(c.$2, color: Dream.roseDeep, size: 20),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    c.$1,
                                    style: F.ui(10, weight: FontWeight.w700, color: Dream.ink),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FloatIn(
                    delay: const Duration(milliseconds: 110),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Trending Flowers', style: F.display(22)),
                        ),
                        BloomTap(
                          onTap: () => _search(category: 'All'),
                          child: Text(
                            'View All >',
                            style: F.ui(12, color: Dream.roseDeep, weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(key: trendingKey, height: 8),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.58,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final p = products[i];
                  return FloatIn(
                    delay: Duration(milliseconds: 50 + i * 30),
                    dy: 12,
                    child: FlowerCard(
                      product: p,
                      heroTag: 'home-${p.name}',
                      onTap: () => _open(p),
                      onAddCart: () => _addToCart(p),
                    ),
                  );
                },
                childCount: products.length,
              ),
            ),
          ),
        ],
      );
        },
      ),
    );
  }
}

class _DreamBanner extends StatefulWidget {
  const _DreamBanner({
    required this.index,
    required this.onShop,
    required this.onPage,
  });

  final int index;
  final VoidCallback onShop;
  final ValueChanged<int> onPage;

  @override
  State<_DreamBanner> createState() => _DreamBannerState();
}

class _DreamBannerState extends State<_DreamBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _shine =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BloomTap(
          onTap: widget.onShop,
          scale: 0.985,
          child: SoftGlass(
            radius: 28,
            padding: EdgeInsets.zero,
            glow: Dream.rose,
            child: SizedBox(
              height: 158,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFE8F0), Color(0xFFFAE9D7), Color(0xFFF5D6EA)],
                      ),
                    ),
                  ),
                  const Positioned(
                    right: -8,
                    bottom: -20,
                    top: 12,
                    width: 180,
                    child: NetImage(
                      url: 'assets/images/products/china_roses.jpg',
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFFFE8F0).withValues(alpha: 0.95),
                            const Color(0xFFFFE8F0).withValues(alpha: 0.45),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.45, 0.82],
                        ),
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _shine,
                    builder: (context, child) => IgnorePointer(
                      child: Transform.translate(
                        offset: Offset((_shine.value * 2 - 1) * 240, 0),
                        child: Container(
                          width: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0),
                                Colors.white.withValues(alpha: 0.28),
                                Colors.white.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 110, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amora Special', style: F.display(22, weight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          'Customizable flower arrangements for every occasion.',
                          style: F.ui(11, color: Dream.ink.withValues(alpha: 0.7), height: 1.35),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        BloomTap(
                          onTap: widget.onShop,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: Dream.petal,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: [
                                BoxShadow(
                                  color: Dream.rose.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Shop Now', style: F.ui(11, color: Colors.white, weight: FontWeight.w800)),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final on = i == widget.index;
            return GestureDetector(
              onTap: () => widget.onPage(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: on ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: on ? Dream.roseDeep : Dream.rose.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class FlowerCard extends StatelessWidget {
  const FlowerCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onAddCart,
    this.heroTag,
  });

  final FlowerProduct product;
  final VoidCallback onTap;
  final VoidCallback? onAddCart;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final wish = WishlistScope.of(context);
    final liked = wish.isWished(product.name);
    final badge = productBadge(product.name);

    return BloomTap(
      onTap: onTap,
      child: SoftGlass(
        radius: 22,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      child: Hero(
                        tag: heroTag ?? 'flower-${product.name}',
                        child: NetImage(url: product.imageUrl),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: HeartPop(
                      liked: liked,
                      onToggle: () => wish.toggle(product.name),
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              badge == 'Best Seller' ? Icons.star_rounded : Icons.local_fire_department_rounded,
                              size: 12,
                              color: Dream.roseDeep,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              badge,
                              style: F.ui(9, color: Dream.roseDeep, weight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: F.display(16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  StarRow(rating: product.rating, reviews: product.reviews, compact: true),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.price,
                          style: F.ui(12, color: Dream.roseDeep, weight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (onAddCart != null)
                        BloomTap(
                          onTap: onAddCart,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: Dream.petal,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Dream.rose.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.shopping_bag_outlined, size: 15, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// MY ORDERS (replaces Categories tab)
// ═══════════════════════════════════════════
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  bool loading = true;
  String? error;
  List<Map<String, dynamic>> orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final list = await OrderApi().listOrders();
      if (!mounted) return;
      setState(() {
        orders = list;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  String _prettyStatus(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    return raw.replaceAll('_', ' ');
  }

  String _trackingLabel(Map<String, dynamic> o) {
    final payment = o['payment_status']?.toString() ?? '';
    if (payment == 'awaiting_payment' || payment == 'unpaid') {
      return 'Awaiting payment';
    }
    if (payment != 'paid') return _prettyStatus(payment);

    final delivery = o['delivery_status']?.toString();
    if (delivery != null && delivery.isNotEmpty && delivery != 'unscheduled') {
      return _prettyStatus(delivery);
    }
    return _prettyStatus(o['status']?.toString());
  }

  Color _statusColor(Map<String, dynamic> o) {
    final label = _trackingLabel(o).toLowerCase();
    if (label.contains('awaiting') || label.contains('unpaid')) return Dream.mist;
    if (label.contains('delivered') || label.contains('completed')) return const Color(0xFF5B8C6A);
    if (label.contains('fail') || label.contains('cancel')) return Dream.rust;
    return Dream.roseDeep;
  }

  String _money(dynamic amount) {
    final n = (amount is num) ? amount.toDouble() : double.tryParse('$amount') ?? 0;
    final raw = n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
    return '₱$raw';
  }

  String _itemsSummary(Map<String, dynamic> o) {
    final items = o['items'];
    if (items is! List || items.isEmpty) return 'No items';
    final names = items
        .whereType<Map>()
        .map((e) {
          final qty = e['quantity'] ?? 1;
          final name = e['product_name'] ?? 'Bloom';
          return '$qty× $name';
        })
        .take(2)
        .join(', ');
    final extra = items.length > 2 ? ' +${items.length - 2} more' : '';
    return '$names$extra';
  }

  /// Steps come from the API so mobile and admin always agree on progress.
  List<Map<String, dynamic>> _trackingSteps(Map<String, dynamic> o) {
    final raw = o['tracking'];
    if (raw is List) {
      return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Orders', style: F.script(42, color: Dream.roseDeep)),
                      Text(
                        'Track checkout & delivery status',
                        style: F.ui(13, color: Dream.mist),
                      ),
                    ],
                  ),
                ),
                BloomTap(
                  onTap: loading ? null : _load,
                  child: SoftGlass(
                    radius: 14,
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.refresh_rounded, size: 18, color: Dream.roseDeep),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.6, color: Dream.roseDeep),
                    ),
                  )
                : error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: SoftGlass(
                            radius: 22,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(error!, style: F.ui(13, color: Dream.mist), textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                BloomTap(
                                  onTap: _load,
                                  child: Text('Retry', style: F.ui(13, color: Dream.roseDeep, weight: FontWeight.w800)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : orders.isEmpty
                        ? Center(
                            child: SoftGlass(
                              radius: 28,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 40, color: Dream.rose.withValues(alpha: 0.7)),
                                  const SizedBox(height: 10),
                                  Text('No orders yet', style: F.display(22)),
                                  Text('Checkout blooms to track them here.', style: F.ui(13, color: Dream.mist)),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: Dream.roseDeep,
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                              itemCount: orders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final o = orders[i];
                                final status = _trackingLabel(o);
                                final color = _statusColor(o);
                                return SoftGlass(
                                  radius: 22,
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              o['order_number']?.toString() ?? 'Order',
                                              style: F.ui(14, color: Dream.roseDeep, weight: FontWeight.w800),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.14),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              status,
                                              style: F.ui(11, color: color, weight: FontWeight.w800),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(_itemsSummary(o), style: F.ui(13, weight: FontWeight.w600)),
                                      const SizedBox(height: 4),
                                      Text(
                                        o['delivery_address']?.toString() ?? '',
                                        style: F.ui(12, color: Dream.mist),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Text(
                                            _money(o['total']),
                                            style: F.ui(15, color: Dream.roseDeep, weight: FontWeight.w800),
                                          ),
                                          const Spacer(),
                                          if (o['payment_status'] == 'paid')
                                            Text(
                                              'Paid',
                                              style: F.ui(11, color: const Color(0xFF5B8C6A), weight: FontWeight.w800),
                                            )
                                          else
                                            Text(
                                              _prettyStatus(o['payment_status']?.toString()),
                                              style: F.ui(11, color: Dream.mist, weight: FontWeight.w700),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      _OrderScheduleRow(order: o),
                                      const SizedBox(height: 12),
                                      _OrderTracker(steps: _trackingSteps(o)),
                                      if (o['failed_reason'] != null) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                          decoration: BoxDecoration(
                                            color: Dream.rust.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Note from the shop: ${o['failed_reason']}',
                                            style: F.ui(11, color: Dream.rust, weight: FontWeight.w700),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

/// Buyer-facing copy of the slot they picked at checkout, plus the rider the
/// shop assigned to it.
class _OrderScheduleRow extends StatelessWidget {
  const _OrderScheduleRow({required this.order});

  final Map<String, dynamic> order;

  String get _slot {
    final date = (order['scheduled_date'] ?? order['requested_delivery_date'])?.toString();
    final time = (order['scheduled_time'] ?? order['requested_delivery_time'])?.toString();
    if (date == null || date.isEmpty) return 'To be scheduled';
    final parsed = DateTime.tryParse(date);
    final pretty = parsed == null ? date : _fmtDate(parsed);
    if (time == null || time.isEmpty) return pretty;
    return '$pretty · ${_fmtTime(time)}';
  }

  static String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static String _fmtTime(String raw) {
    final parts = raw.split(':');
    final hour = int.tryParse(parts.first);
    if (hour == null) return raw;
    final minute = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12:$minute $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final rider = order['assigned_rider']?.toString();
    return Row(
      children: [
        Icon(Icons.event_available_rounded, size: 14, color: Dream.roseDeep),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _slot,
            style: F.ui(11, color: Dream.ink, weight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.delivery_dining_rounded,
          size: 14,
          color: rider == null || rider.isEmpty ? Dream.mist : Dream.roseDeep,
        ),
        const SizedBox(width: 5),
        Text(
          rider == null || rider.isEmpty ? 'Rider pending' : rider,
          style: F.ui(11, color: Dream.mist, weight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Vertical progress rail driven by the API's tracking steps.
class _OrderTracker extends StatelessWidget {
  const _OrderTracker({required this.steps});

  final List<Map<String, dynamic>> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();

    final lastDone = steps.lastIndexWhere((s) => s['done'] == true);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Dream.cream.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Dream.blush.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order tracking',
            style: F.ui(11, color: Dream.roseDeep, weight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            _TrackerStep(
              label: steps[i]['label']?.toString() ?? '',
              at: steps[i]['at']?.toString(),
              done: steps[i]['done'] == true,
              current: i == lastDone,
              isLast: i == steps.length - 1,
              failed: (steps[i]['label']?.toString() ?? '').toLowerCase().contains('fail'),
            ),
        ],
      ),
    );
  }
}

class _TrackerStep extends StatelessWidget {
  const _TrackerStep({
    required this.label,
    required this.at,
    required this.done,
    required this.current,
    required this.isLast,
    required this.failed,
  });

  final String label;
  final String? at;
  final bool done;
  final bool current;
  final bool isLast;
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final active = failed && done
        ? Dream.rust
        : done
            ? const Color(0xFF5B8C6A)
            : Dream.blush;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: done ? active : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: active, width: 1.8),
              ),
              child: done
                  ? Icon(
                      failed ? Icons.close_rounded : Icons.check_rounded,
                      size: 10,
                      color: Colors.white,
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 22,
                margin: const EdgeInsets.symmetric(vertical: 2),
                color: done ? active.withValues(alpha: 0.5) : Dream.blush.withValues(alpha: 0.6),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: F.ui(
                    12,
                    color: done ? Dream.ink : Dream.mist,
                    weight: current || done ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                if (at != null && at!.isNotEmpty)
                  Text(at!, style: F.ui(10, color: Dream.mist)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({
    super.key,
    required this.onSearchCategory,
    this.onPick,
  });

  final ValueChanged<String> onSearchCategory;
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          Text('Categories', style: F.script(42, color: Dream.roseDeep)),
          Text('Browse by assortment', style: F.ui(13, color: Dream.mist)),
          const SizedBox(height: 16),
          for (final c in assortmentCategories) ...[
            BloomTap(
              onTap: () {
                onPick?.call(c.$1);
                onSearchCategory(c.$1);
              },
              child: SoftGlass(
                radius: 20,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    SoftGlass(
                      radius: 16,
                      padding: const EdgeInsets.all(12),
                      glow: Colors.transparent,
                      child: Icon(c.$2, color: Dream.roseDeep),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.$1, style: F.display(20)),
                          Text(
                            switch (normalizeCategory(c.$1)) {
                              'all' => '${products.length} flowers available',
                              'bouquets' => '${catalogProducts(category: 'bouquets').length} arranged bouquets',
                              'roses' => '${catalogProducts(category: 'roses').length} rose picks',
                              'stems' => '${catalogProducts(category: 'stems').length} per-stem blooms',
                              _ => 'Shop this assortment',
                            },
                            style: F.ui(12, color: Dream.mist),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Dream.mist),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// SEARCH
// ═══════════════════════════════════════════
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.initialQuery = '',
    this.initialCategory = 'All',
    this.openSortOnStart = false,
    required this.onProductChat,
  });

  final String initialQuery;
  final String initialCategory;
  final bool openSortOnStart;
  final ValueChanged<String> onProductChat;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final controller = TextEditingController(text: widget.initialQuery);
  late String category = widget.initialCategory;
  CatalogSort sort = CatalogSort.featured;

  List<FlowerProduct> get results => catalogProducts(
        query: controller.text,
        category: category,
        sort: sort,
      );

  @override
  void initState() {
    super.initState();
    if (widget.openSortOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openSort());
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  String get _sortLabel => switch (sort) {
        CatalogSort.featured => 'Featured',
        CatalogSort.nameAsc => 'Name A–Z',
        CatalogSort.priceLow => 'Price: Low to High',
        CatalogSort.priceHigh => 'Price: High to Low',
        CatalogSort.rating => 'Top rated',
      };

  void _openSort() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: Container(
            color: const Color(0xF5FFF8FB),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Dream.rose.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Text('Sort assortment', style: F.display(22)),
                  const SizedBox(height: 8),
                  for (final option in CatalogSort.values)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        switch (option) {
                          CatalogSort.featured => 'Featured',
                          CatalogSort.nameAsc => 'Name A–Z',
                          CatalogSort.priceLow => 'Price: Low to High',
                          CatalogSort.priceHigh => 'Price: High to Low',
                          CatalogSort.rating => 'Top rated',
                        },
                        style: F.ui(14, weight: FontWeight.w700),
                      ),
                      trailing: sort == option
                          ? const Icon(Icons.check_rounded, color: Dream.roseDeep)
                          : null,
                      onTap: () {
                        setState(() => sort = option);
                        Navigator.pop(ctx);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = results;
    return DreamWorld(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    BloomTap(
                      onTap: () => Navigator.pop(context),
                      child: SoftGlass(
                        radius: 16,
                        padding: const EdgeInsets.all(10),
                        child: const Icon(Icons.arrow_back_rounded, color: Dream.roseDeep, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SoftGlass(
                        radius: 20,
                        border: Dream.rose.withValues(alpha: 0.45),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          controller: controller,
                          onChanged: (_) => setState(() {}),
                          style: F.ui(14),
                          cursorColor: Dream.roseDeep,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search flowers',
                            hintStyle: F.ui(14, color: Dream.mist),
                            icon: const Icon(Icons.search_rounded, color: Dream.roseDeep, size: 20),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    BloomTap(
                      onTap: _openSort,
                      child: SoftGlass(
                        radius: 16,
                        padding: const EdgeInsets.all(10),
                        child: const Icon(Icons.tune_rounded, size: 18, color: Dream.ink),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: assortmentCategories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = assortmentCategories[i];
                    final on = normalizeCategory(category) == normalizeCategory(c.$1);
                    return BloomTap(
                      onTap: () => setState(() => category = c.$1),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: on ? Dream.rose.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: on ? Dream.roseDeep : Dream.blush, width: on ? 1.5 : 1),
                        ),
                        child: Row(
                          children: [
                            Icon(c.$2, size: 16, color: on ? Dream.roseDeep : Dream.mist),
                            const SizedBox(width: 6),
                            Text(
                              c.$1,
                              style: F.ui(12, weight: FontWeight.w800, color: on ? Dream.roseDeep : Dream.ink),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${items.length} flower${items.length == 1 ? '' : 's'} · $_sortLabel',
                        style: F.ui(12, color: Dream.mist, weight: FontWeight.w600),
                      ),
                    ),
                    BloomTap(
                      onTap: _openSort,
                      child: Text('Sort', style: F.ui(12, color: Dream.roseDeep, weight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text('No flowers in this assortment', style: F.ui(14, color: Dream.mist)),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.62,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final p = items[i];
                          return FloatIn(
                            delay: Duration(milliseconds: i * 40),
                            child: FlowerCard(
                              product: p,
                              heroTag: 'search-${p.name}',
                              onTap: () => Navigator.push(
                                context,
                                _dreamRoute(keepWishlist(
                                  context,
                                  ProductDetailsScreen(
                                    product: p,
                                    onChat: () => widget.onProductChat(p.name),
                                    heroTag: 'search-${p.name}',
                                  ),
                                )),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// PRODUCT DETAILS
// ═══════════════════════════════════════════
class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.onChat,
    this.heroTag,
  });

  final FlowerProduct product;
  final VoidCallback onChat;
  final String? heroTag;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  void _variants({required bool checkout}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => keepWishlist(
        context,
        VariantSheet(product: widget.product, checkoutMode: checkout),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final wish = WishlistScope.of(context);
    final liked = wish.isWished(p.name);
    return DreamWorld(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 330,
                  pinned: true,
                  backgroundColor: Dream.cream.withValues(alpha: 0.8),
                  elevation: 0,
                  leading: const SizedBox.shrink(),
                  flexibleSpace: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: widget.heroTag ?? 'flower-${p.name}',
                        child: NetImage(url: p.imageUrl),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.12),
                              Colors.transparent,
                              Dream.cream.withValues(alpha: 0.96),
                            ],
                            stops: const [0, 0.5, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        top: MediaQuery.paddingOf(context).top + 8,
                        left: 16,
                        right: 16,
                        child: SoftGlass(
                          radius: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            children: [
                              BloomTap(
                                onTap: () => Navigator.pop(context),
                                child: const CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white,
                                  child: Icon(Icons.arrow_back_rounded, color: Dream.roseDeep, size: 16),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(p.name, style: F.display(18)),
                              ),
                              HeartPop(
                                liked: liked,
                                onToggle: () => wish.toggle(p.name),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 130),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FloatIn(child: Text(p.name, style: F.script(44, color: Dream.roseDeep))),
                        FloatIn(
                          delay: const Duration(milliseconds: 40),
                          child: StarRow(rating: p.rating, reviews: '${p.reviews} reviews'),
                        ),
                        const SizedBox(height: 8),
                        FloatIn(
                          delay: const Duration(milliseconds: 70),
                          child: Text(
                            p.price,
                            style: F.ui(22, color: Dream.roseDeep, weight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 18),
                        FloatIn(
                          delay: const Duration(milliseconds: 100),
                          child: SoftGlass(
                            radius: 24,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('About ${p.name}', style: F.display(22)),
                                const SizedBox(height: 8),
                                Text(
                                  p.description,
                                  style: F.ui(13, color: Dream.mist, height: 1.55),
                                ),
                                if (p.note != null) ...[
                                  const SizedBox(height: 10),
                                  Text(
                                    p.note!,
                                    style: F.ui(12, color: Dream.roseDeep, weight: FontWeight.w600, height: 1.45),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Text(
                                  'Free greeting card included ♡',
                                  style: F.ui(12, color: Dream.roseDeep, weight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (p.sizes.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text('Pre-order sizes', style: F.display(20)),
                          const SizedBox(height: 10),
                          SoftGlass(
                            radius: 24,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                for (final s in p.sizes)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Text(s.label, style: F.ui(14, weight: FontWeight.w700)),
                                        const Spacer(),
                                        Text(s.display, style: F.ui(14, color: Dream.roseDeep, weight: FontWeight.w800)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text('Product Description', style: F.display(20)),
                        const SizedBox(height: 10),
                        SoftGlass(
                          radius: 24,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Dream.rose.withValues(alpha: 0.25),
                                    child: const Icon(Icons.person_rounded, size: 16, color: Dream.roseDeep),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Amora Florals', style: F.ui(13, weight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const StarRow(rating: '5.0'),
                              Text(
                                p.isStem ? 'Sold per stem (unarranged)' : 'Pre-order bouquet',
                                style: F.ui(11, color: Dream.mist),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Prices may change without prior notice due to supply and seasonal fluctuations.',
                                style: F.ui(13),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  for (var i = 0; i < p.images.length && i < 3; i++)
                                    Container(
                                      margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                      width: 70,
                                      height: 70,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: NetImage(url: p.images[i]),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(context).bottom),
                    decoration: BoxDecoration(
                      color: const Color(0xF2FFF8FB),
                      boxShadow: [
                        BoxShadow(
                          color: Dream.rose.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _FootAction(icon: Icons.chat_bubble_outline_rounded, label: 'Chat Now', onTap: widget.onChat),
                        const SizedBox(width: 8),
                        _FootAction(
                          icon: Icons.add_shopping_cart_rounded,
                          label: 'Add to Cart',
                          onTap: () => _variants(checkout: false),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: BloomTap(
                            onTap: () => _variants(checkout: true),
                            child: Container(
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: Dream.petal,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Dream.rose.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Text('Buy Now', style: F.ui(14, color: Colors.white, weight: FontWeight.w800)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _FootAction extends StatelessWidget {
  const _FootAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BloomTap(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Dream.roseDeep, size: 20),
          Text(label, style: F.ui(10, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════
// VARIANT SHEET
// ═══════════════════════════════════════════
class VariantSheet extends StatefulWidget {
  const VariantSheet({super.key, required this.product, required this.checkoutMode});
  final FlowerProduct product;
  final bool checkoutMode;

  @override
  State<VariantSheet> createState() => _VariantSheetState();
}

class _VariantSheetState extends State<VariantSheet> {
  late String sizeLabel;
  int qty = 1;
  int box = 0;

  @override
  void initState() {
    super.initState();
    sizeLabel = widget.product.sizes.isNotEmpty ? widget.product.sizes.first.label : '1 stem';
  }

  SizePrice? get selectedSize {
    final sizes = widget.product.sizes;
    if (sizes.isEmpty) return null;
    return sizes.firstWhere((s) => s.label == sizeLabel, orElse: () => sizes.first);
  }

  String get priceLabel {
    final size = selectedSize;
    if (size != null) return size.display;
    return widget.product.price;
  }

  void _commit({required bool addOnly}) {
    final p = widget.product;
    final size = selectedSize;
    final sizeId = size?.id ??
        p.sizeId ??
        CartController.localSizeKey(p.name, sizeLabel);

    // Capture before pop — sheet context becomes invalid after dismiss.
    final cart = CartScope.of(context);
    final wishlist = WishlistScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    cart.addFromProduct(
      p,
      sizeLabel: sizeLabel,
      quantity: qty,
      sizeId: sizeId,
      priceFrom: size?.priceFrom ?? p.sortPrice,
    );

    navigator.pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (addOnly) {
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
            backgroundColor: Dream.roseDeep,
            duration: const Duration(seconds: 2),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Added $qty× ${p.name} to cart',
                    style: F.ui(13, color: Colors.white),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                navigator.push(
                  _dreamRoute(
                    WishlistScope(
                      controller: wishlist,
                      child: CartScope(
                        controller: cart,
                        child: const CartScreen(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
        return;
      }

      navigator.push(
        _dreamRoute(
          WishlistScope(
            controller: wishlist,
            child: CartScope(
              controller: cart,
              child: const CartScreen(),
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: Container(
          color: const Color(0xF5FFF8FB),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Dream.rose.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(99)),
                  ),
                ),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: NetImage(
                        url: p.images[box.clamp(0, p.images.length - 1)],
                        width: 88,
                        height: 88,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: F.display(22)),
                          Text(priceLabel, style: F.ui(15, color: Dream.roseDeep, weight: FontWeight.w800)),
                          Text('$sizeLabel · Qty $qty', style: F.ui(12, color: Dream.mist)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (p.sizes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Choose Size', style: F.ui(14, weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: p.sizes.map((s) {
                      final on = sizeLabel == s.label;
                      return BloomTap(
                        onTap: () => setState(() => sizeLabel = s.label),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: on ? Dream.rose.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: on ? Dream.roseDeep : Dream.blush, width: on ? 1.6 : 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.label, style: F.ui(13, color: on ? Dream.roseDeep : Dream.ink, weight: FontWeight.w800)),
                              Text(s.display, style: F.ui(11, color: Dream.mist, weight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ] else if (p.note != null) ...[
                  const SizedBox(height: 16),
                  SoftGlass(
                    radius: 16,
                    padding: const EdgeInsets.all(12),
                    child: Text(p.note!, style: F.ui(12, color: Dream.mist, height: 1.4)),
                  ),
                ],
                const SizedBox(height: 18),
                Text(p.isStem ? 'Stems' : 'Quantity', style: F.ui(14, weight: FontWeight.w700)),
                const SizedBox(height: 10),
                SoftGlass(
                  radius: 16,
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: 132,
                    height: 44,
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: qty > 1 ? () => setState(() => qty--) : null,
                            child: const Icon(Icons.remove_rounded, color: Dream.mist),
                          ),
                        ),
                        Text('$qty', style: F.ui(16, color: Dream.roseDeep, weight: FontWeight.w800)),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => qty++),
                            child: const Icon(Icons.add_rounded, color: Dream.mist),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (p.images.length > 1) ...[
                  const SizedBox(height: 18),
                  Text('Photos', style: F.ui(14, weight: FontWeight.w700)),
                  Text('Only this flower\'s looks', style: F.ui(12, color: Dream.mist)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (var i = 0; i < p.images.length; i++)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: i < p.images.length - 1 ? 10 : 0),
                            child: BloomTap(
                              onTap: () => setState(() => box = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                height: 86,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: box == i ? Dream.roseDeep : Dream.blush, width: box == i ? 2 : 1),
                                  boxShadow: box == i
                                      ? [BoxShadow(color: Dream.rose.withValues(alpha: 0.25), blurRadius: 12)]
                                      : null,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: NetImage(url: p.images[i]),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    if (!widget.checkoutMode)
                      Expanded(
                        child: BloomTap(
                          onTap: () => _commit(addOnly: true),
                          child: Container(
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Dream.roseDeep, width: 1.5),
                            ),
                            child: Text('Add to Cart', style: F.ui(13, color: Dream.roseDeep, weight: FontWeight.w800)),
                          ),
                        ),
                      ),
                    if (!widget.checkoutMode) const SizedBox(width: 10),
                    Expanded(
                      child: BloomTap(
                        onTap: () => _commit(addOnly: false),
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: Dream.petal,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Dream.rose.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.checkoutMode ? 'Buy Now' : 'Check Out',
                                style: F.ui(12, color: Colors.white, weight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ),
    );
  }
}

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool placing = false;
  final Set<int> selected = {};
  final Set<int> knownIds = {};
  bool seeded = false;

  void _syncSelection(CartController cart) {
    final ids = cart.items.map((e) => e.sizeId).toSet();
    selected.removeWhere((id) => !ids.contains(id));
    knownIds.removeWhere((id) => !ids.contains(id));

    if (!seeded) {
      selected.addAll(ids);
      knownIds.addAll(ids);
      seeded = true;
      return;
    }

    // Only auto-select brand-new cart lines; keep user deselects.
    for (final id in ids) {
      if (!knownIds.contains(id)) {
        selected.add(id);
        knownIds.add(id);
      }
    }
  }

  String _money(int amount) {
    final raw = amount.toString();
    final withComma = raw.length > 3
        ? '${raw.substring(0, raw.length - 3)},${raw.substring(raw.length - 3)}'
        : raw;
    return '₱$withComma+';
  }

  List<CartItem> _selectedItems(CartController cart) {
    return cart.items.where((item) => selected.contains(item.sizeId)).toList();
  }

  void _toggleAll(CartController cart) {
    setState(() {
      if (selected.length == cart.items.length) {
        selected.clear();
      } else {
        selected
          ..clear()
          ..addAll(cart.items.map((e) => e.sizeId));
      }
    });
  }

  void _goCheckout(CartController cart) {
    final lines = _selectedItems(cart);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select at least one bloom to checkout.', style: F.ui(13, color: Colors.white)),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      _dreamRoute(
        keepWishlist(
          context,
          CheckoutScreen(items: List<CartItem>.from(lines)),
        ),
      ),
    );
  }

  Widget _checkBox({required bool on, required VoidCallback? onTap}) {
    return BloomTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: on ? Dream.petal : null,
          color: on ? null : Colors.white,
          border: Border.all(color: on ? Dream.roseDeep : Dream.blush, width: 1.6),
        ),
        child: on ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);

    return DreamWorld(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Dream.ink,
          title: Text('Your Cart', style: F.script(34, color: Dream.roseDeep)),
        ),
        body: ListenableBuilder(
          listenable: cart,
          builder: (context, _) {
            _syncSelection(cart);

            if (cart.isEmpty) {
              return Center(
                child: SoftGlass(
                  radius: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_outlined, size: 42, color: Dream.rose.withValues(alpha: 0.7)),
                      const SizedBox(height: 12),
                      Text('Your cart is empty', style: F.display(22)),
                      const SizedBox(height: 6),
                      Text('Browse blooms and add your favorites.', style: F.ui(13, color: Dream.mist)),
                      const SizedBox(height: 18),
                      BloomTap(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: Dream.petal,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('Continue Shopping', style: F.ui(13, color: Colors.white, weight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final picked = _selectedItems(cart);
            final selectedQty = picked.fold<int>(0, (sum, item) => sum + item.quantity);
            final selectedTotal = picked.fold<int>(0, (sum, item) => sum + item.lineTotal);
            final allOn = selected.length == cart.items.length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: SoftGlass(
                    radius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        _checkBox(
                          on: allOn,
                          onTap: placing ? null : () => _toggleAll(cart),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            allOn ? 'Deselect all' : 'Select all',
                            style: F.ui(13, weight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${selected.length}/${cart.items.length} selected',
                          style: F.ui(12, color: Dream.mist),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      final on = selected.contains(item.sizeId);
                      return FloatIn(
                        child: SoftGlass(
                          radius: 24,
                          padding: const EdgeInsets.all(14),
                          border: on ? Dream.rose.withValues(alpha: 0.55) : null,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 30),
                                child: _checkBox(
                                  on: on,
                                  onTap: placing
                                      ? null
                                      : () => setState(() {
                                            if (on) {
                                              selected.remove(item.sizeId);
                                            } else {
                                              selected.add(item.sizeId);
                                            }
                                          }),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: NetImage(url: item.imageUrl, width: 84, height: 84),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name, style: F.display(18)),
                                    const SizedBox(height: 4),
                                    Text('Size: ${item.sizeLabel}', style: F.ui(12, color: Dream.mist)),
                                    Text(item.priceDisplay, style: F.ui(14, color: Dream.roseDeep, weight: FontWeight.w800)),
                                    const SizedBox(height: 10),
                                    SoftGlass(
                                      radius: 14,
                                      padding: EdgeInsets.zero,
                                      child: SizedBox(
                                        width: 118,
                                        height: 36,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                onTap: placing
                                                    ? null
                                                    : () => cart.setQuantity(item.sizeId, item.quantity - 1),
                                                child: const Icon(Icons.remove_rounded, color: Dream.mist, size: 18),
                                              ),
                                            ),
                                            Text(
                                              '${item.quantity}',
                                              style: F.ui(14, color: Dream.roseDeep, weight: FontWeight.w800),
                                            ),
                                            Expanded(
                                              child: InkWell(
                                                onTap: placing
                                                    ? null
                                                    : () => cart.setQuantity(item.sizeId, item.quantity + 1),
                                                child: const Icon(Icons.add_rounded, color: Dream.mist, size: 18),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              BloomTap(
                                onTap: placing
                                    ? null
                                    : () {
                                        selected.remove(item.sizeId);
                                        cart.remove(item.sizeId);
                                      },
                                child: const Icon(Icons.close_rounded, color: Dream.mist, size: 18),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
                  decoration: BoxDecoration(
                    color: const Color(0xF2FFF8FB),
                    boxShadow: [
                      BoxShadow(
                        color: Dream.rose.withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            picked.isEmpty
                                ? 'No items selected'
                                : 'Selected ($selectedQty pcs)',
                            style: F.ui(13, color: Dream.mist),
                          ),
                          const Spacer(),
                          Text(
                            picked.isEmpty ? '₱0' : _money(selectedTotal),
                            style: F.ui(18, color: Dream.roseDeep, weight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: BloomTap(
                              onTap: placing ? null : () => Navigator.pop(context),
                              child: Container(
                                height: 50,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Dream.roseDeep, width: 1.5),
                                ),
                                child: Text(
                                  'Continue Shopping',
                                  style: F.ui(11, color: Dream.roseDeep, weight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: BloomTap(
                              onTap: picked.isEmpty ? null : () => _goCheckout(cart),
                              child: Opacity(
                                opacity: picked.isEmpty ? 0.45 : 1,
                                child: Container(
                                  height: 50,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: Dream.petal,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Dream.rose.withValues(alpha: 0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    picked.isEmpty
                                        ? 'Select to checkout'
                                        : 'Checkout (${picked.length})',
                                    style: F.ui(11, color: Colors.white, weight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// CHECKOUT + PAYMONGO RETURN
// ═══════════════════════════════════════════
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.items});
  final List<CartItem> items;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final formKey = GlobalKey<FormState>();
  final recipient = TextEditingController();
  final contact = TextEditingController();
  final address = TextEditingController(text: 'Quezon City');
  final notes = TextEditingController();
  bool submitting = false;
  static const deliveryFee = 0;

  DateTime? deliveryDate;
  TimeOfDay? deliveryTime;

  int get subtotal => widget.items.fold(0, (sum, i) => sum + i.lineTotal);
  int get total => subtotal + deliveryFee;

  String get _dateValue {
    final d = deliveryDate;
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String get _timeValue {
    final t = deliveryTime;
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  String get _dateLabel {
    final d = deliveryDate;
    if (d == null) return 'Choose date';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String get _timeLabel {
    final t = deliveryTime;
    if (t == null) return 'Choose time';
    final hour12 = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final suffix = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:${t.minute.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: deliveryDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      helpText: 'Pick your delivery date',
    );
    if (picked != null) setState(() => deliveryDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: deliveryTime ?? const TimeOfDay(hour: 10, minute: 0),
      helpText: 'Pick your delivery time',
    );
    if (picked != null) setState(() => deliveryTime = picked);
  }

  String _money(int amount) {
    final raw = amount.toString();
    final withComma = raw.length > 3
        ? '${raw.substring(0, raw.length - 3)},${raw.substring(raw.length - 3)}'
        : raw;
    return '₱$withComma';
  }

  @override
  void dispose() {
    recipient.dispose();
    contact.dispose();
    address.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (deliveryDate == null || deliveryTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please choose your delivery date and time.',
            style: F.ui(13, color: Colors.white),
          ),
        ),
      );
      return;
    }
    setState(() => submitting = true);
    try {
      final result = await OrderApi().checkout(
        items: [
          for (final item in widget.items)
            (sizeId: item.sizeId, quantity: item.quantity),
        ],
        recipientName: recipient.text.trim(),
        recipientContact: contact.text.trim(),
        deliveryAddress: address.text.trim(),
        requestedDate: _dateValue,
        requestedTime: _timeValue,
        deliveryNotes: notes.text.trim().isEmpty ? null : notes.text.trim(),
        deliveryFee: deliveryFee.toDouble(),
      );
      if (!mounted) return;

      final data = result['data'] as Map<String, dynamic>? ?? {};
      final checkoutUrl = data['checkout_url']?.toString();
      final orderId = data['id'];
      final demoPaid = data['demo_paid'] == true || data['payment_status'] == 'paid';

      if (demoPaid) {
        final cart = CartScope.maybeOf(context);
        for (final item in widget.items) {
          cart?.remove(item.sizeId);
        }
        if (!mounted) return;
        final orderNumber = data['order_number']?.toString() ?? 'your order';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Paid! $orderNumber is in admin Orders.',
              style: F.ui(13, color: Colors.white),
            ),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw OrderApiException('No PayMongo checkout URL returned. Check PAYMONGO_SECRET_KEY.');
      }

      // Persist pending checkout so return page can clear cart lines.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'amora_pending_checkout',
        jsonEncode({
          'order_id': orderId,
          'size_ids': [for (final i in widget.items) i.sizeId],
        }),
      );

      // Flutter web: full-page redirect (launchUrl often does nothing in Safari).
      if (openExternalUrl(checkoutUrl)) return;

      final uri = Uri.parse(checkoutUrl);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open payment page. URL: $checkoutUrl', style: F.ui(13, color: Colors.white))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), style: F.ui(13, color: Colors.white))),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DreamWorld(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Dream.ink,
          title: Text('Checkout', style: F.script(34, color: Dream.roseDeep)),
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              SoftGlass(
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery details', style: F.display(22)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: recipient,
                      style: F.ui(14),
                      decoration: _fieldDeco('Recipient name'),
                      validator: (v) => (v == null || v.trim().length < 2) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: contact,
                      style: F.ui(14),
                      keyboardType: TextInputType.phone,
                      decoration: _fieldDeco('Contact number'),
                      validator: (v) => (v == null || v.trim().length < 10) ? 'Enter a valid number' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: address,
                      style: F.ui(14),
                      maxLines: 2,
                      decoration: _fieldDeco('Delivery address'),
                      validator: (v) => (v == null || v.trim().length < 5) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: notes,
                      style: F.ui(14),
                      maxLines: 2,
                      decoration: _fieldDeco('Notes / greeting (optional)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SoftGlass(
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delivery schedule', style: F.display(22)),
                    const SizedBox(height: 4),
                    Text(
                      'Pick when you want your blooms delivered.',
                      style: F.ui(12, color: Dream.mist),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SchedulePick(
                            icon: Icons.calendar_month_rounded,
                            label: 'Date',
                            value: _dateLabel,
                            chosen: deliveryDate != null,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SchedulePick(
                            icon: Icons.schedule_rounded,
                            label: 'Time',
                            value: _timeLabel,
                            chosen: deliveryTime != null,
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SoftGlass(
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Order summary', style: F.display(22)),
                    const SizedBox(height: 10),
                    for (final item in widget.items) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity}× ${item.name} (${item.sizeLabel})',
                              style: F.ui(13, weight: FontWeight.w600),
                            ),
                          ),
                          Text(_money(item.lineTotal), style: F.ui(13, color: Dream.roseDeep, weight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Divider(height: 20),
                    Row(
                      children: [
                        Text('Subtotal', style: F.ui(13, color: Dream.mist)),
                        const Spacer(),
                        Text(_money(subtotal), style: F.ui(13, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text('Delivery', style: F.ui(13, color: Dream.mist)),
                        const Spacer(),
                        Text(deliveryFee == 0 ? 'Free' : _money(deliveryFee), style: F.ui(13, weight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Total', style: F.ui(15, weight: FontWeight.w800)),
                        const Spacer(),
                        Text(_money(total), style: F.ui(18, color: Dream.roseDeep, weight: FontWeight.w800)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.paddingOf(context).bottom),
          child: BloomTap(
            onTap: submitting ? null : _pay,
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: Dream.petal,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(color: Dream.rose.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6)),
                ],
              ),
              child: submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text('Checkout', style: F.ui(15, color: Colors.white, weight: FontWeight.w800)),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: F.ui(12, color: Dream.mist),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.85),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Dream.blush)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Dream.blush)),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Dream.roseDeep, width: 1.4),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// CUSTOM ARRANGEMENT REQUEST
// ═══════════════════════════════════════════
class CustomRequestScreen extends StatefulWidget {
  const CustomRequestScreen({super.key});

  @override
  State<CustomRequestScreen> createState() => _CustomRequestScreenState();
}

class _CustomRequestScreenState extends State<CustomRequestScreen> {
  final formKey = GlobalKey<FormState>();
  final occasion = TextEditingController();
  final flowers = TextEditingController();
  final colors = TextEditingController();
  final budget = TextEditingController();
  final message = TextEditingController();

  String size = 'Medium';
  DateTime? wantedDate;
  bool submitting = false;
  bool loadingList = true;
  List<Map<String, dynamic>> mine = [];

  static const sizes = ['Small', 'Medium', 'Large', 'Grand'];

  @override
  void initState() {
    super.initState();
    _loadMine();
  }

  @override
  void dispose() {
    occasion.dispose();
    flowers.dispose();
    colors.dispose();
    budget.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> _loadMine() async {
    setState(() => loadingList = true);
    try {
      final list = await CustomRequestApi().list();
      if (!mounted) return;
      setState(() {
        mine = list;
        loadingList = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loadingList = false);
    }
  }

  String get _dateValue => wantedDate == null
      ? ''
      : '${wantedDate!.year.toString().padLeft(4, '0')}-'
          '${wantedDate!.month.toString().padLeft(2, '0')}-'
          '${wantedDate!.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: wantedDate ?? now.add(const Duration(days: 2)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => wantedDate = picked);
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (wantedDate == null) {
      _toast('Please choose when you need the arrangement.');
      return;
    }

    setState(() => submitting = true);
    try {
      final result = await CustomRequestApi().submit(
        occasion: occasion.text.trim(),
        budget: double.parse(budget.text.trim()),
        requestedDate: _dateValue,
        preferredFlowers: flowers.text,
        preferredColors: colors.text,
        bouquetSize: size,
        message: message.text,
      );
      if (!mounted) return;
      final number = result['data']?['request_number']?.toString() ?? 'Your request';
      _toast('$number sent! The shop will review it shortly.');
      occasion.clear();
      flowers.clear();
      colors.clear();
      budget.clear();
      message.clear();
      setState(() => wantedDate = null);
      _loadMine();
    } catch (e) {
      if (!mounted) return;
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text, style: F.ui(13, color: Colors.white))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DreamWorld(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Dream.roseDeep),
          title: Text('Custom bouquet', style: F.display(20, color: Dream.roseDeep)),
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
            children: [
              Text(
                'Tell us your dream arrangement and the florist will quote it for you.',
                style: F.ui(13, color: Dream.mist),
              ),
              const SizedBox(height: 14),
              SoftGlass(
                radius: 24,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: occasion,
                      style: F.ui(14),
                      decoration: _requestDeco('Occasion (e.g. Anniversary)'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: flowers,
                      style: F.ui(14),
                      decoration: _requestDeco('Preferred flowers (optional)'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: colors,
                      style: F.ui(14),
                      decoration: _requestDeco('Preferred colors (optional)'),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: budget,
                      style: F.ui(14),
                      keyboardType: TextInputType.number,
                      decoration: _requestDeco('Budget in pesos'),
                      validator: (v) {
                        final amount = double.tryParse((v ?? '').trim());
                        if (amount == null) return 'Enter a number';
                        if (amount < 0) return 'Must be positive';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Text('Bouquet size', style: F.ui(12, color: Dream.mist, weight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in sizes)
                          BloomTap(
                            onTap: () => setState(() => size = s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: size == s ? Dream.roseDeep : Colors.white.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: size == s ? Dream.roseDeep : Dream.blush),
                              ),
                              child: Text(
                                s,
                                style: F.ui(
                                  12,
                                  color: size == s ? Colors.white : Dream.ink,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _SchedulePick(
                      icon: Icons.calendar_month_rounded,
                      label: 'Needed by',
                      value: wantedDate == null
                          ? 'Choose date'
                          : _OrderScheduleRow._fmtDate(wantedDate!),
                      chosen: wantedDate != null,
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: message,
                      style: F.ui(14),
                      maxLines: 3,
                      decoration: _requestDeco('Message or special details (optional)'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              BloomTap(
                onTap: submitting ? null : _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: Dream.petal,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Dream.rose.withValues(alpha: 0.35), blurRadius: 18),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      submitting ? 'Sending…' : 'Send request',
                      style: F.ui(15, color: Colors.white, weight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text('My requests', style: F.display(20)),
              const SizedBox(height: 8),
              if (loadingList)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Dream.roseDeep),
                    ),
                  ),
                )
              else if (mine.isEmpty)
                SoftGlass(
                  radius: 20,
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    'No custom requests yet. Send one above and track the florist\'s reply here.',
                    style: F.ui(13, color: Dream.mist),
                  ),
                )
              else
                for (final r in mine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SoftGlass(
                      radius: 20,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  r['request_number']?.toString() ?? 'Request',
                                  style: F.ui(13, color: Dream.roseDeep, weight: FontWeight.w800),
                                ),
                              ),
                              Text(
                                (r['status']?.toString() ?? '').replaceAll('_', ' '),
                                style: F.ui(11, color: Dream.mist, weight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${r['occasion']} · ${r['bouquet_size'] ?? 'custom'}',
                            style: F.ui(13, weight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r['estimated_price'] != null
                                ? 'Florist quote: ₱${r['estimated_price']}'
                                : 'Budget: ₱${r['budget']} · awaiting quote',
                            style: F.ui(12, color: Dream.mist),
                          ),
                          if (r['admin_notes'] != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Florist: ${r['admin_notes']}',
                              style: F.ui(12, color: Dream.ink),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _requestDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: F.ui(12, color: Dream.mist),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.85),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Dream.blush)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Dream.blush)),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Dream.roseDeep, width: 1.4),
      ),
    );
  }
}

class _SchedulePick extends StatelessWidget {
  const _SchedulePick({
    required this.icon,
    required this.label,
    required this.value,
    required this.chosen,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BloomTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: chosen ? Dream.roseDeep : Dream.blush, width: chosen ? 1.4 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: Dream.roseDeep),
                const SizedBox(width: 6),
                Text(label, style: F.ui(11, color: Dream.mist, weight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: F.ui(
                13,
                weight: FontWeight.w700,
                color: chosen ? Dream.ink : Dream.mist,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentReturnScreen extends StatefulWidget {
  const PaymentReturnScreen({
    super.key,
    required this.success,
    required this.onDone,
    this.orderId,
  });

  final bool success;
  final int? orderId;
  final VoidCallback onDone;

  @override
  State<PaymentReturnScreen> createState() => _PaymentReturnScreenState();
}

class _PaymentReturnScreenState extends State<PaymentReturnScreen> {
  bool checking = true;
  bool paid = false;
  String message = 'Confirming payment…';
  String? orderNumber;

  @override
  void initState() {
    super.initState();
    if (widget.success) {
      _confirm();
    } else {
      checking = false;
      message = 'Payment cancelled. Your cart items are still saved.';
    }
  }

  Future<void> _confirm() async {
    var orderId = widget.orderId;
    List<int> sizeIds = [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('amora_pending_checkout');
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        orderId ??= (map['order_id'] as num?)?.toInt();
        sizeIds = ((map['size_ids'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList();
      }

      if (orderId == null) {
        setState(() {
          checking = false;
          message = 'Payment returned, but order id is missing. Check Orders in admin after a moment.';
        });
        return;
      }

      Map<String, dynamic>? last;
      for (var i = 0; i < 8; i++) {
        last = await OrderApi().paymentStatus(orderId);
        paid = last['paid'] == true || (last['data'] as Map?)?['payment_status'] == 'paid';
        orderNumber = (last['data'] as Map?)?['order_number']?.toString();
        if (paid) break;
        await Future<void>.delayed(const Duration(milliseconds: 900));
      }

      if (paid && sizeIds.isNotEmpty) {
        // Clear checked-out lines from persisted cart on next MainShell load
        final cartRaw = prefs.getString('amora_cart_v1');
        if (cartRaw != null) {
          final list = (jsonDecode(cartRaw) as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) => !sizeIds.contains((e['sizeId'] as num).toInt()))
              .toList();
          await prefs.setString('amora_cart_v1', jsonEncode(list));
        }
        await prefs.remove('amora_pending_checkout');
      }

      if (!mounted) return;
      setState(() {
        checking = false;
        message = paid
            ? 'Payment received! Your bloom order is confirmed.'
            : 'Still waiting for PayMongo confirmation. If you already paid, refresh in a few seconds or check admin Orders.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        checking = false;
        message = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SoftGlass(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (checking)
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: Dream.roseDeep),
                  )
                else
                  Icon(
                    paid ? Icons.check_circle_rounded : (widget.success ? Icons.hourglass_top_rounded : Icons.cancel_outlined),
                    size: 48,
                    color: paid ? Dream.roseDeep : Dream.mist,
                  ),
                const SizedBox(height: 14),
                Text(
                  widget.success ? (paid ? 'Payment successful' : 'Confirming…') : 'Payment cancelled',
                  style: F.display(26),
                  textAlign: TextAlign.center,
                ),
                if (orderNumber != null) ...[
                  const SizedBox(height: 6),
                  Text(orderNumber!, style: F.ui(13, color: Dream.roseDeep, weight: FontWeight.w800)),
                ],
                const SizedBox(height: 10),
                Text(message, style: F.ui(13, color: Dream.mist, height: 1.4), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                BloomTap(
                  onTap: checking
                      ? null
                      : () {
                          cleanBrowserQuery();
                          widget.onDone();
                        },
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: Dream.petal,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      paid ? 'Back to shop' : 'Continue',
                      style: F.ui(14, color: Colors.white, weight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
// MESSAGING — Inbox + Chat Room
// ═══════════════════════════════════════════
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.threads, required this.onOpen});

  final List<ChatThread> threads;
  final ValueChanged<ChatThread> onOpen;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final threads = widget.threads.where((t) {
      final q = query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return t.name.toLowerCase().contains(q) || t.preview.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 8),
            child: FloatIn(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Messages', style: F.script(44, color: Dream.roseDeep)),
                  const SizedBox(height: 6),
                  Text(
                    'Message the shop. Replies from the admin show up here.',
                    style: F.ui(13, color: Dream.mist),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: SoftGlass(
              radius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: TextField(
                style: F.ui(13),
                cursorColor: Dream.roseDeep,
                onChanged: (value) => setState(() => query = value),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search conversations',
                  hintStyle: F.ui(13, color: Dream.mist),
                  icon: const Icon(Icons.search_rounded, color: Dream.mist, size: 18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
              physics: const BouncingScrollPhysics(),
              itemCount: threads.length,
              itemBuilder: (context, i) {
                final t = threads[i];
                return FloatIn(
                  delay: Duration(milliseconds: 60 + i * 70),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: BloomTap(
                      onTap: () => widget.onOpen(t),
                      child: SoftGlass(
                        radius: 24,
                        padding: const EdgeInsets.all(14),
                        glow: t.unread > 0 ? Dream.lavender : Dream.rose,
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: Dream.petal,
                                  ),
                                  child: _ThreadAvatar(url: t.avatar, radius: 26),
                                ),
                                if (t.online)
                                  Positioned(
                                    right: 2,
                                    bottom: 2,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Dream.sage,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(t.name, style: F.display(18)),
                                      ),
                                      Text(t.time, style: F.ui(11, color: Dream.mist)),
                                    ],
                                  ),
                                  Text(t.role, style: F.ui(11, color: Dream.lavender, weight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.preview,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: F.ui(
                                      12,
                                      color: Dream.mist,
                                      weight: t.unread > 0 ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (t.unread > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: Dream.petal,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('${t.unread}', style: F.ui(11, color: Colors.white, weight: FontWeight.w800)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.thread,
    required this.onUpdated,
  });

  final ChatThread thread;
  final ValueChanged<ChatThread> onUpdated;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  List<ChatMessage> messages = [];
  final controller = TextEditingController();
  final scroll = ScrollController();
  Timer? _poll;
  bool sending = false;

  @override
  void initState() {
    super.initState();
    messages = List.of(widget.thread.messages);
    _refresh();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    try {
      final shop = await MessageApi().fetch(markRead: true);
      if (!mounted) return;
      final next = threadFromShop(shop);
      setState(() => messages = next.messages);
      widget.onUpdated(next);
      if (!silent) _scrollDown();
    } catch (error) {
      if (silent || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString(), style: F.ui(13, color: Colors.white))),
      );
    }
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (!scroll.hasClients) return;
      scroll.animateTo(
        scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    controller.clear();
    try {
      final shop = await MessageApi().send(text);
      if (!mounted) return;
      final next = threadFromShop(shop);
      setState(() => messages = next.messages);
      widget.onUpdated(next);
      _scrollDown();
    } catch (error) {
      if (!mounted) return;
      controller.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString(), style: F.ui(13, color: Colors.white))),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.thread;
    return DreamWorld(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                child: SoftGlass(
                  radius: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: Row(
                    children: [
                      BloomTap(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_rounded, color: Dream.roseDeep),
                      ),
                      const SizedBox(width: 8),
                      _ThreadAvatar(url: t.avatar, radius: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name, style: F.display(18)),
                            Text(
                              t.online ? 'Online · shop admin' : 'Away',
                              style: F.ui(11, color: t.online ? Dream.sage : Dream.mist, weight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      SoftGlass(
                        radius: 14,
                        padding: const EdgeInsets.all(8),
                        child: const Icon(Icons.local_florist_rounded, color: Dream.roseDeep, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('you were the beautiful dream i dreamed', style: F.whisper(8)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    return FloatIn(
                      delay: Duration(milliseconds: (i * 30).clamp(0, 180)),
                      dy: 10,
                      child: _Bubble(message: m),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 12 + MediaQuery.paddingOf(context).bottom),
                child: SoftGlass(
                  radius: 28,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  glow: Dream.lavender,
                  child: Row(
                    children: [
                      SoftGlass(
                        radius: 16,
                        padding: const EdgeInsets.all(10),
                        child: const Icon(Icons.image_outlined, size: 18, color: Dream.mist),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: F.ui(14),
                          cursorColor: Dream.roseDeep,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Write something soft…',
                            hintStyle: F.ui(14, color: Dream.mist),
                          ),
                        ),
                      ),
                      BloomTap(
                        onTap: _send,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: Dream.petal,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Dream.rose.withValues(alpha: 0.35), blurRadius: 14),
                            ],
                          ),
                          child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadAvatar extends StatelessWidget {
  const _ThreadAvatar({required this.url, required this.radius});

  final String url;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty || url.contains('unsplash')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Dream.blush,
        child: Icon(Icons.local_florist_rounded, color: Dream.roseDeep, size: radius),
      );
    }
    return CircleAvatar(radius: radius, backgroundImage: NetworkImage(url));
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: mine
              ? Dream.petal
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.82),
                    Dream.peach.withValues(alpha: 0.65),
                  ],
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(mine ? 22 : 6),
            bottomRight: Radius.circular(mine ? 6 : 22),
          ),
          boxShadow: [
            BoxShadow(
              color: (mine ? Dream.rose : Dream.lavender).withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
          border: mine ? null : Border.all(color: Colors.white.withValues(alpha: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: F.ui(
                14,
                color: mine ? Colors.white : Dream.ink,
                height: 1.4,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: F.ui(
                10,
                color: mine ? Colors.white.withValues(alpha: 0.8) : Dream.mist,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
