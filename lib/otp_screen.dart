import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:amora_florals_mobile/main.dart';
import 'package:amora_florals_mobile/services/auth_api.dart';

/// Enter the 6-digit email OTP before opening the shop home.
class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.email,
    this.debugOtp,
  });

  final String email;
  final String? debugOtp;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final otp = TextEditingController();
  final api = AuthApi();
  bool loading = false;
  bool resending = false;
  String? error;
  String? localHint;

  @override
  void initState() {
    super.initState();
    localHint = widget.debugOtp;
  }

  @override
  void dispose() {
    otp.dispose();
    super.dispose();
  }

  void _enterShop() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (context, animation, secondary) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: const DreamWorld(child: MainShell()),
        ),
      ),
      (_) => false,
    );
  }

  Future<void> _verify() async {
    final code = otp.text.trim();
    if (code.length != 6) {
      setState(() => error = 'Enter the 6-digit code from your email.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await api.verifyOtp(email: widget.email, otp: code);
      if (!mounted) return;
      _enterShop();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Cannot reach Laravel. Is php artisan serve running?';
      });
    }
  }

  Future<void> _resend() async {
    setState(() {
      resending = true;
      error = null;
    });
    try {
      final body = await api.resendOtp(email: widget.email);
      if (!mounted) return;
      setState(() {
        resending = false;
        localHint = body['debug_otp']?.toString();
        error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(body['message']?.toString() ?? 'Code resent.'),
          backgroundColor: Dream.roseDeep,
        ),
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        resending = false;
        error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        resending = false;
        error = 'Cannot reach Laravel right now.';
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
            child: SoftGlass(
              radius: 32,
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              glow: Dream.rose,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FlowerLogo(size: 52),
                  const SizedBox(height: 10),
                  Text('Verify email', style: F.display(22, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a 6-digit code to',
                    style: F.ui(13, color: Dream.mist),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    widget.email,
                    style: F.ui(13, color: Dream.roseDeep, weight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: TextField(
                      controller: otp,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: F.ui(22, weight: FontWeight.w800),
                      maxLength: 6,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      cursorColor: Dream.roseDeep,
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: '••••••',
                        hintStyle: F.ui(22, color: Dream.mist),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.85),
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Dream.blush.withValues(alpha: 0.7)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(color: Dream.blush.withValues(alpha: 0.7)),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                          borderSide: BorderSide(color: Dream.roseDeep, width: 1.4),
                        ),
                      ),
                    ),
                  ),
                  if (localHint != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Local test code: $localHint\n(Real inbox needs SMTP later)',
                      style: F.ui(11, color: Dream.roseDeep, weight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      error!,
                      style: F.ui(12, color: Dream.rust, weight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 18),
                  BloomTap(
                    onTap: loading ? null : _verify,
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
                              'Verify & continue',
                              style: F.ui(15, color: Colors.white, weight: FontWeight.w800),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: resending ? null : _resend,
                    child: Text(
                      resending ? 'Sending…' : 'Resend code',
                      style: F.ui(12, color: Dream.roseDeep, weight: FontWeight.w700),
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
