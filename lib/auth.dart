import 'package:flutter/material.dart';

import 'package:amora_florals_mobile/main.dart';
import 'package:amora_florals_mobile/otp_screen.dart';
import 'package:amora_florals_mobile/services/auth_api.dart';

/// Demo customer already verified in Laravel seeder.
class DemoCustomer {
  static const name = 'Amora Customer';
  static const email = 'customer@amoraflorals.com';
  static const password = 'customer123';
}

/// Login / Sign up gate → OTP (signup) → flower shop ([MainShell]).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.startOnLogin = false, this.onBack});

  final bool startOnLogin;
  final VoidCallback? onBack;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late bool signup = !widget.startOnLogin;
  bool obscure = true;
  bool loading = false;
  String? authError;

  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final formKey = GlobalKey<FormState>();
  final api = AuthApi();

  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _bloom.dispose();
    name.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void _enterShop() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (context, animation, secondary) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: const DreamWorld(child: MainShell()),
        ),
      ),
    );
  }

  void _openOtp({required String emailAddress, String? debugOtp}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondary) => FadeTransition(
          opacity: animation,
          child: DreamWorld(
            child: OtpScreen(
              email: emailAddress,
              debugOtp: debugOtp,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    setState(() {
      loading = true;
      authError = null;
    });

    try {
      if (signup) {
        final body = await api.register(
          name: name.text,
          email: email.text,
          password: password.text,
        );
        if (!mounted) return;
        setState(() => loading = false);
        _openOtp(
          emailAddress: body['email']?.toString() ?? email.text.trim(),
          debugOtp: body['debug_otp']?.toString(),
        );
      } else {
        await api.login(
          email: email.text,
          password: password.text,
        );
        if (!mounted) return;
        setState(() => loading = false);
        _enterShop();
      }
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      if (e.needsVerification) {
        _openOtp(emailAddress: e.email ?? email.text.trim(), debugOtp: e.debugOtp);
        return;
      }
      setState(() => authError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        authError =
            'Cannot reach Laravel API. Keep php artisan serve running on :8000.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            physics: const BouncingScrollPhysics(),
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _bloom, curve: Curves.easeOut),
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                    .animate(CurvedAnimation(parent: _bloom, curve: Curves.easeOutCubic)),
                child: SoftGlass(
                  radius: 32,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  glow: Dream.rose,
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.onBack != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: BloomTap(
                              onTap: widget.onBack,
                              child: const Padding(
                                padding: EdgeInsets.only(bottom: 6),
                                child: Icon(Icons.arrow_back_rounded, color: Dream.roseDeep),
                              ),
                            ),
                          ),
                        const FlowerLogo(size: 58),
                        const SizedBox(height: 8),
                        Text('Amora', style: F.script(54, color: Dream.roseDeep)),
                        Transform.translate(
                          offset: const Offset(0, -6),
                          child: Text(
                            'Florals',
                            style: F.display(18, style: FontStyle.italic),
                          ),
                        ),
                        Text(
                          signup
                              ? 'Create your soft bloom account'
                              : 'Welcome back, dreamer',
                          style: F.ui(13, color: Dream.mist),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          signup
                              ? 'After sign up, enter the code sent to your email'
                              : 'Demo: ${DemoCustomer.email} / ${DemoCustomer.password}',
                          style: F.ui(11, color: Dream.roseDeep, weight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        _ModeSwitch(
                          signup: signup,
                          onChanged: (v) => setState(() {
                            signup = v;
                            authError = null;
                          }),
                        ),
                        const SizedBox(height: 16),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: signup
                              ? Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _AuthField(
                                    controller: name,
                                    label: 'Full name',
                                    icon: Icons.person_outline_rounded,
                                    validator: (v) {
                                      if (!signup) return null;
                                      if (v == null || v.trim().length < 2) {
                                        return 'Enter your name';
                                      }
                                      return null;
                                    },
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        _AuthField(
                          controller: email,
                          label: 'Email',
                          icon: Icons.mail_outline_rounded,
                          keyboard: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || !v.contains('@')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        _AuthField(
                          controller: password,
                          label: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: obscure,
                          suffix: IconButton(
                            onPressed: () => setState(() => obscure = !obscure),
                            icon: Icon(
                              obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Dream.mist,
                              size: 18,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.length < 6) {
                              return 'At least 6 characters';
                            }
                            return null;
                          },
                        ),
                        if (authError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            authError!,
                            style: F.ui(12, color: Dream.rust, weight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 18),
                        BloomTap(
                          onTap: loading ? null : _submit,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: double.infinity,
                            height: 50,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: Dream.petal,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Dream.rose.withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    signup ? 'Create account' : 'Log in',
                                    style: F.ui(
                                      15,
                                      color: Colors.white,
                                      weight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => signup = !signup),
                          child: Text.rich(
                            TextSpan(
                              text: signup
                                  ? 'Already have an account? '
                                  : 'New here? ',
                              style: F.ui(12, color: Dream.mist),
                              children: [
                                TextSpan(
                                  text: signup ? 'Log in' : 'Sign up',
                                  style: F.ui(
                                    12,
                                    color: Dream.roseDeep,
                                    weight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SparkleMark(size: 12, points: 4),
                            SizedBox(width: 8),
                            SparkleMark(size: 16, points: 8),
                            SizedBox(width: 8),
                            SparkleMark(size: 12, points: 4),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.signup, required this.onChanged});

  final bool signup;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SoftGlass(
      radius: 18,
      padding: const EdgeInsets.all(4),
      glow: Colors.transparent,
      child: Row(
        children: [
          _chip('Sign up', signup, () => onChanged(true)),
          _chip('Log in', !signup, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback tap) {
    return Expanded(
      child: BloomTap(
        onTap: tap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: on ? Dream.petal : null,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: F.ui(
              13,
              color: on ? Colors.white : Dream.mist,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.keyboard,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboard;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        validator: validator,
        style: F.ui(14),
        cursorColor: Dream.roseDeep,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: F.ui(12, color: Dream.mist),
          prefixIcon: Icon(icon, color: Dream.roseDeep, size: 20),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.85),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Dream.blush.withValues(alpha: 0.7)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Dream.blush.withValues(alpha: 0.7)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Dream.roseDeep, width: 1.4),
          ),
        ),
      ),
    );
  }
}
