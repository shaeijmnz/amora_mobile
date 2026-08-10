import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:amora_florals_mobile/auth.dart';
import 'package:amora_florals_mobile/services/auth_api.dart';
import 'package:amora_florals_mobile/services/product_api.dart';

void main() => runApp(const AmoraFloralsApp());

class AmoraFloralsApp extends StatelessWidget {
  const AmoraFloralsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amora Florals',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Dream.rose,
          primary: Dream.rose,
          surface: Dream.cream,
        ),
        textTheme: GoogleFonts.quicksandTextTheme().apply(
          bodyColor: Dream.ink,
          displayColor: Dream.ink,
        ),
      ),
      home: const DreamWorld(child: AuthScreen()),
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
      GoogleFonts.allura(
        fontSize: size,
        fontWeight: weight,
        color: color ?? Dream.ink,
        height: 0.95,
      );

  static TextStyle display(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w600,
    FontStyle? style,
  }) =>
      GoogleFonts.cormorantGaramond(
        fontSize: size,
        fontWeight: weight,
        fontStyle: style,
        color: color ?? Dream.ink,
        height: 1.15,
        letterSpacing: -0.3,
      );

  static TextStyle ui(
    double size, {
    Color? color,
    FontWeight weight = FontWeight.w500,
    double? height,
    double? tracking,
  }) =>
      GoogleFonts.quicksand(
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
      GoogleFonts.montserrat(
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: 2.4,
        color: color ?? Dream.lavender,
      );
}

// ═══════════════════════════════════════════
// Catalog + chat data
// ═══════════════════════════════════════════
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
  });

  final int? id;
  final int? sizeId;
  final String name;
  final String price;
  final String rating;
  final String reviews;
  final String imageUrl;
  final String category;
}

/// Fallback while Laravel catalog loads (or if offline).
const _fallbackProducts = <FlowerProduct>[
  FlowerProduct(
    name: 'Daisy',
    price: 'Php. 125.00',
    rating: '4.5',
    reviews: '128',
    imageUrl: 'https://plus.unsplash.com/premium_photo-1667867937010-77fd5161cf8d?fm=jpg&q=60&w=3000&auto=format&fit=crop',
    category: 'flower',
  ),
];

/// Live customer catalog — filled from Laravel `/api/products`.
List<FlowerProduct> products = List<FlowerProduct>.from(_fallbackProducts);

const flowerBoxes = [
  'https://images.unsplash.com/photo-1487530811176-3780de880c2d?w=300',
  'https://images.unsplash.com/photo-1561181286-d3fee7f52978?w=300',
  'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=300',
];

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
    required this.text,
    required this.mine,
    required this.time,
  });

  final String text;
  final bool mine;
  final String time;
}

List<ChatThread> seedThreads() => [
  ChatThread(
    id: 'amora',
    name: 'Amora Studio',
    role: 'Boutique florist',
    avatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
    preview: 'We can wrap your tulips in a blush box ✨',
    time: '2m',
    unread: 2,
    online: true,
    messages: const [
      ChatMessage(
        text: 'Hi love! Looking for anniversary blooms?',
        mine: false,
        time: '10:02',
      ),
      ChatMessage(
        text: 'Yes — soft tulips, something dreamy.',
        mine: true,
        time: '10:04',
      ),
      ChatMessage(
        text: 'We can wrap your tulips in a blush box ✨',
        mine: false,
        time: '10:05',
      ),
      ChatMessage(
        text: 'Same-day Quezon City delivery is open until 4pm.',
        mine: false,
        time: '10:06',
      ),
    ],
  ),
  ChatThread(
    id: 'mira',
    name: 'Mira',
    role: 'Floral stylist',
    avatar: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200',
    preview: 'Your lavender bundle is being arranged.',
    time: '1h',
    unread: 0,
    online: true,
    messages: const [
      ChatMessage(
        text: 'Your lavender bundle is being arranged.',
        mine: false,
        time: '09:20',
      ),
      ChatMessage(
        text: 'Thank you! Can you add a handwritten note?',
        mine: true,
        time: '09:22',
      ),
      ChatMessage(
        text: 'Of course — leave the message anytime 💌',
        mine: false,
        time: '09:23',
      ),
    ],
  ),
  ChatThread(
    id: 'support',
    name: 'Bloom Concierge',
    role: 'Order support',
    avatar: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200',
    preview: 'Payment confirmed via GCash.',
    time: 'Yesterday',
    unread: 0,
    online: false,
    messages: const [
      ChatMessage(
        text: 'Payment confirmed via GCash.',
        mine: false,
        time: '18:40',
      ),
      ChatMessage(
        text: 'Perfect, thank you!',
        mine: true,
        time: '18:41',
      ),
    ],
  ),
];

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
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  )..repeat();

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
        final t = _c.value;
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
      },
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
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Dream.peach, Dream.blush])),
        child: const Icon(Icons.local_florist_rounded, color: Dream.roseDeep),
      ),
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

class CartController extends ChangeNotifier {
  final Map<String, int> _qty = {};

  int get count => _qty.values.fold(0, (a, b) => a + b);

  void add(String name, [int quantity = 1]) {
    _qty[name] = (_qty[name] ?? 0) + quantity;
    notifyListeners();
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
  ('Tulips', Icons.spa_rounded),
  ('Roses', Icons.favorite_rounded),
];

String? productBadge(String name) {
  switch (name) {
    case 'Daisy':
    case 'Tulips':
    case 'Peony':
      return 'Best Seller';
    case 'Sunflower':
    case 'Red Rose':
    case 'Lavender':
      return 'Popular';
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
  late List<ChatThread> threads;
  late WishlistController wishlist;
  late CartController cart;
  bool catalogLoading = true;

  @override
  void initState() {
    super.initState();
    threads = seedThreads();
    wishlist = WishlistController();
    cart = CartController();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final apiItems = await ProductApi().fetchProducts();
      if (!mounted) return;
      setState(() {
        products = apiItems
            .map(
              (p) => FlowerProduct(
                id: p.id,
                sizeId: p.sizeId,
                name: p.name,
                price: p.priceLabel,
                rating: p.rating,
                reviews: p.reviews,
                imageUrl: p.imageUrl,
                category: p.category,
              ),
            )
            .toList();
        catalogLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => catalogLoading = false);
    }
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
    wishlist.dispose();
    cart.dispose();
    super.dispose();
  }

  void _openInbox({String? focusId, String? productHint}) {
    if (focusId != null || productHint != null) {
      final thread = threads.firstWhere(
        (t) => t.id == (focusId ?? 'amora'),
        orElse: () => threads.first,
      );
      var msgs = List<ChatMessage>.from(thread.messages);
      if (productHint != null) {
        msgs = [
          ...msgs,
          ChatMessage(
            text: 'Hi! I\'d love to ask about $productHint 🌷',
            mine: true,
            time: 'now',
          ),
        ];
      }
      Navigator.push(
        context,
        _dreamRoute(ChatRoomScreen(
          thread: ChatThread(
            id: thread.id,
            name: thread.name,
            role: thread.role,
            avatar: thread.avatar,
            preview: thread.preview,
            time: thread.time,
            unread: 0,
            online: thread.online,
            messages: msgs,
          ),
          onSend: (text) {},
        )),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                cart.count == 0 ? 'Your cart is empty' : '${cart.count} items in cart',
                style: F.ui(13, color: Colors.white),
              ),
            ),
          );
        },
      ),
      CategoriesScreen(
        onPick: (label) {
          setState(() => index = 0);
          // Home will handle via callback if needed — open search from here:
        },
        onSearchCategory: (label) {
          Navigator.push(
            context,
            _dreamRoute(keepWishlist(
              context,
              SearchScreen(
                initialQuery: label.toLowerCase() == 'bouquets' ? 'flower' : label,
                onProductChat: (p) => _openInbox(productHint: p),
              ),
            )),
          );
        },
      ),
      InboxScreen(
        threads: threads,
        onOpen: (t) => Navigator.push(
          context,
          _dreamRoute(ChatRoomScreen(
            thread: t,
            onSend: (text) {
              setState(() {
                final i = threads.indexWhere((x) => x.id == t.id);
                if (i >= 0) {
                  threads[i] = ChatThread(
                    id: t.id,
                    name: t.name,
                    role: t.role,
                    avatar: t.avatar,
                    preview: text,
                    time: 'now',
                    unread: 0,
                    online: t.online,
                    messages: [
                      ...t.messages,
                      ChatMessage(text: text, mine: true, time: 'now'),
                    ],
                  );
                }
              });
            },
          )),
        ),
      ),
      WishlistScreen(
        onBrowse: () => setState(() => index = 0),
        onProductChat: (p) => _openInbox(productHint: p),
      ),
      ProfileScreen(
        onOpenWishlist: () => setState(() => index = 3),
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
                            icon: Icons.grid_view_rounded,
                            label: 'Categories',
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
                      child: Container(
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
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.onOpenWishlist,
    required this.onOpenMessages,
  });

  final VoidCallback onOpenWishlist;
  final VoidCallback onOpenMessages;

  void _logout(BuildContext context) async {
    await AuthApi().clearSession();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondary) => FadeTransition(
          opacity: animation,
          child: const DreamWorld(child: AuthScreen()),
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wish = WishlistScope.of(context);

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
                    child: const CircleAvatar(
                      radius: 34,
                      backgroundImage: NetworkImage(
                        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200',
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amora Member', style: F.script(34, color: Dream.roseDeep)),
                        Text('bloom.lover@amora.app', style: F.ui(12, color: Dream.mist)),
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
            child: Row(
              children: [
                _ProfileStat(label: 'Wishlist', value: '${wish.count}', onTap: onOpenWishlist),
                const SizedBox(width: 10),
                _ProfileStat(label: 'Orders', value: '3', onTap: () {}),
                const SizedBox(width: 10),
                _ProfileStat(label: 'Points', value: '240', onTap: () {}),
              ],
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
                  icon: Icons.favorite_rounded,
                  title: 'My Wishlist',
                  subtitle: wish.count == 0 ? 'No saved flowers yet' : '${wish.count} saved',
                  onTap: onOpenWishlist,
                ),
                _ProfileTile(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Messages',
                  subtitle: 'Chat with florists',
                  onTap: onOpenMessages,
                ),
                _ProfileTile(
                  icon: Icons.local_shipping_outlined,
                  title: 'Delivery address',
                  subtitle: 'Quezon City, Metro Manila',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.payments_outlined,
                  title: 'Payment methods',
                  subtitle: 'GCash · Cash on delivery',
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

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: BloomTap(
        onTap: onTap,
        child: SoftGlass(
          radius: 18,
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(value, style: F.display(22, color: Dream.roseDeep)),
              Text(label, style: F.ui(11, color: Dream.mist, weight: FontWeight.w600)),
            ],
          ),
        ),
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
    final cartCount = CartScope.maybeOf(context)?.count ?? 0;
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
            child: BloomTap(
              onTap: onOpenCart,
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
                        child: Container(
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
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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

  void _search([String? q]) {
    Navigator.push(
      context,
      _dreamRoute(keepWishlist(
        context,
        SearchScreen(
          initialQuery: q ?? search.text,
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
    CartScope.of(context).add(p.name);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${p.name} to cart', style: F.ui(13, color: Colors.white))),
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
                                  hintText: "Search 'Tulips' here",
                                  hintStyle: F.ui(13, color: Dream.mist, height: 1.2),
                                ),
                              ),
                            ),
                            BloomTap(
                              onTap: () => _search(),
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
                              onTap: () => _search(c.$1),
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
                          onTap: () => _search('flower'),
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
                      url: 'https://images.unsplash.com/photo-1490750967868-88aa4486c946?w=700',
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
          Text('Pick a bloom mood', style: F.ui(13, color: Dream.mist)),
          const SizedBox(height: 16),
          for (final c in homeCategories) ...[
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
                      child: Text(c.$1, style: F.display(20)),
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
    required this.onProductChat,
  });

  final String initialQuery;
  final ValueChanged<String> onProductChat;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final controller = TextEditingController(text: widget.initialQuery);
  late List<FlowerProduct> results = _filter(widget.initialQuery);

  List<FlowerProduct> _filter(String q) {
    final n = q.trim().toLowerCase();
    if (n.isEmpty) return List.of(products);
    return products
        .where((p) => p.name.toLowerCase().contains(n) || p.category.toLowerCase().contains(n))
        .toList();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DreamWorld(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                          onChanged: (v) => setState(() => results = _filter(v)),
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
                    SoftGlass(
                      radius: 16,
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.tune_rounded, size: 18, color: Dream.ink),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final p = results[i];
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
      builder: (_) => VariantSheet(product: widget.product, checkoutMode: checkout),
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
                                  'Brighten any space with their graceful petals and stunning variety of colors. Perfect for gifts, home decor, or special occasions, these timeless blooms add a touch of charm and sophistication wherever they are displayed.',
                                  style: F.ui(13, color: Dream.mist, height: 1.55),
                                ),
                              ],
                            ),
                          ),
                        ),
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
                                  Text('J*********o', style: F.ui(13, weight: FontWeight.w700)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const StarRow(rating: '5.0'),
                              Text('Variation: Orange', style: F.ui(11, color: Dream.mist)),
                              const SizedBox(height: 8),
                              Text('Depende kung 3 yan...................', style: F.ui(13)),
                              const SizedBox(height: 12),
                              Row(
                                children: List.generate(
                                  3,
                                  (i) => Container(
                                    margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                    width: 70,
                                    height: 70,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: NetImage(url: p.imageUrl),
                                    ),
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
  String color = 'Orange';
  int qty = 3;
  int box = 0;
  final colors = const ['Orange', 'Red', 'Blue', 'Pink'];

  @override
  Widget build(BuildContext context) {
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
                      child: NetImage(url: widget.product.imageUrl, width: 88, height: 88),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.product.name, style: F.display(22)),
                          Text(widget.product.price, style: F.ui(15, color: Dream.roseDeep, weight: FontWeight.w800)),
                          Text('$color · Qty $qty', style: F.ui(12, color: Dream.mist)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Choose Color', style: F.ui(14, weight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: colors.map((c) {
                    final on = color == c;
                    return BloomTap(
                      onTap: () => setState(() => color = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: on ? Dream.rose.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: on ? Dream.roseDeep : Dream.blush, width: on ? 1.6 : 1),
                        ),
                        child: Text(c, style: F.ui(13, color: on ? Dream.roseDeep : Dream.ink, weight: FontWeight.w700)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text('Quantity', style: F.ui(14, weight: FontWeight.w700)),
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
                const SizedBox(height: 18),
                Text('Customize (Optional)', style: F.ui(14, weight: FontWeight.w700)),
                Text('Flower Box', style: F.ui(12, color: Dream.mist)),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(3, (i) {
                    final on = box == i;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                        child: BloomTap(
                          onTap: () => setState(() => box = i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            height: 86,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: on ? Dream.roseDeep : Dream.blush, width: on ? 2 : 1),
                              boxShadow: on
                                  ? [BoxShadow(color: Dream.rose.withValues(alpha: 0.25), blurRadius: 12)]
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: NetImage(url: flowerBoxes[i]),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: BloomTap(
                        onTap: () {
                          final cart = CartScope.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final name = widget.product.name;
                          final n = qty;
                          Navigator.pop(context);
                          cart.add(name, n);
                          messenger.showSnackBar(
                            SnackBar(content: Text('Added $n × $name', style: F.ui(13, color: Colors.white))),
                          );
                        },
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
                    const SizedBox(width: 10),
                    Expanded(
                      child: BloomTap(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            _dreamRoute(CartScreen(product: widget.product, quantity: qty, color: color)),
                          );
                        },
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
                                widget.checkoutMode ? 'Check Out' : 'Check Out',
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

class CartScreen extends StatelessWidget {
  const CartScreen({
    super.key,
    required this.product,
    required this.quantity,
    required this.color,
  });

  final FlowerProduct product;
  final int quantity;
  final String color;

  @override
  Widget build(BuildContext context) {
    return DreamWorld(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Dream.ink,
          title: Text('Your Cart', style: F.script(34, color: Dream.roseDeep)),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: FloatIn(
            child: SoftGlass(
              radius: 24,
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: NetImage(url: product.imageUrl, width: 84, height: 84),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: F.display(20)),
                        Text('Color: $color · Qty: $quantity', style: F.ui(12, color: Dream.mist)),
                        Text(product.price, style: F.ui(15, color: Dream.roseDeep, weight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
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
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key, required this.threads, required this.onOpen});

  final List<ChatThread> threads;
  final ValueChanged<ChatThread> onOpen;

  @override
  Widget build(BuildContext context) {
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
                    'Chat with florists, track blooms, leave love notes.',
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
                      onTap: () => onOpen(t),
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
                                  child: CircleAvatar(
                                    radius: 26,
                                    backgroundImage: NetworkImage(t.avatar),
                                  ),
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
    required this.onSend,
  });

  final ChatThread thread;
  final ValueChanged<String> onSend;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  late List<ChatMessage> messages = List.of(widget.thread.messages);
  final controller = TextEditingController();
  final scroll = ScrollController();

  @override
  void dispose() {
    controller.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      messages.add(ChatMessage(text: text, mine: true, time: 'now'));
    });
    widget.onSend(text);
    controller.clear();
    Future.delayed(const Duration(milliseconds: 80), () {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });

    // soft florist reply
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        messages.add(const ChatMessage(
          text: 'Noted with love — we\'ll keep it dreamy ✨',
          mine: false,
          time: 'now',
        ));
      });
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    });
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
                      CircleAvatar(radius: 20, backgroundImage: NetworkImage(t.avatar)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.name, style: F.display(18)),
                            Text(
                              t.online ? 'Online · arranging blooms' : 'Away',
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
