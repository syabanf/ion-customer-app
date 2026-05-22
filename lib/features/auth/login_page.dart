import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_customer_app/shared.dart';
import 'portal_auth.dart';

/// CustomerLoginPage — OTP-based sign-in.
///
/// Two steps in one form:
///   1. Customer enters their customer-number + last 4 digits of phone
///   2. Backend sends an OTP; customer enters it
///
/// Demo mode (CRM_PORTAL_OTP_DEMO=true on the server) returns the OTP
/// in the request response so a demoer doesn't need WhatsApp wired.
/// The page surfaces it as a small hint when present.
class CustomerLoginPage extends StatefulWidget {
  const CustomerLoginPage({super.key, required this.api, required this.onSignedIn});
  final PortalAuthApi api;
  final VoidCallback onSignedIn;

  @override
  State<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends State<CustomerLoginPage> {
  final _custNumber = TextEditingController();
  final _phoneLast4 = TextEditingController();
  final _otp = TextEditingController();

  bool _busy = false;
  bool _otpSent = false;
  String? _debugOtp;
  String? _error;

  @override
  void dispose() {
    _custNumber.dispose();
    _phoneLast4.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _busy = true;
      _error = null;
      _debugOtp = null;
    });
    try {
      final r = await widget.api.requestOtp(
        customerNumber: _custNumber.text.trim(),
        phoneLast4: _phoneLast4.text.trim(),
      );
      setState(() {
        _otpSent = true;
        _debugOtp = r.debugOtp;
      });
    } on PortalException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.verifyOtp(
        customerNumber: _custNumber.text.trim(),
        otp: _otp.text.trim(),
      );
      widget.onSignedIn();
      if (!mounted) return;
      GoRouter.of(context).go('/');
    } on PortalException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: IonColors.ion500,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              const _BrandHero(),
              Positioned.fill(
                top: MediaQuery.of(context).size.height * 0.32,
                child: _Sheet(child: _form(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: IonColors.separatorLight,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Text(
          _otpSent ? 'Enter the code' : 'Sign in',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: IonColors.ink,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _otpSent
              ? 'We sent a 6-digit code to your registered phone.'
              : 'Use your ION customer number and the last 4 digits of your registered phone.',
          style: const TextStyle(
            fontSize: 13,
            color: IonColors.inkMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        if (!_otpSent) ...[
          IonField(
            label: 'Customer number',
            hint: 'CUST-20260513-…',
            controller: _custNumber,
            leading: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          IonField(
            label: 'Phone — last 4 digits',
            hint: '2333',
            controller: _phoneLast4,
            keyboardType: TextInputType.number,
            maxLength: 4,
            leading: Icons.phone_outlined,
          ),
        ] else ...[
          IonField(
            label: 'OTP',
            hint: '6 digits',
            controller: _otp,
            keyboardType: TextInputType.number,
            maxLength: 6,
            leading: Icons.lock_outline_rounded,
          ),
          if (_debugOtp != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: IonColors.ion50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.bug_report_outlined,
                      color: IonColors.ion700, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Demo OTP: $_debugOtp',
                    style: const TextStyle(
                      color: IonColors.ion700,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          IonErrorBanner(message: _error!),
        ],
        const SizedBox(height: 22),
        IonPrimaryButton(
          label: _otpSent ? (_busy ? 'Verifying…' : 'Sign in') : (_busy ? 'Sending…' : 'Send code'),
          icon: _otpSent ? Icons.login_rounded : Icons.send_rounded,
          loading: _busy,
          onPressed: _otpSent ? _verifyOtp : _requestOtp,
        ),
        if (_otpSent) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                      _otpSent = false;
                      _otp.clear();
                      _debugOtp = null;
                    }),
            child: const Text(
              'Use a different number',
              style: TextStyle(
                fontSize: 13,
                color: IonColors.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Trouble signing in? Contact ION support.',
            style: TextStyle(fontSize: 12, color: IonColors.inkMuted),
          ),
        ),
        const SizedBox(height: 28),
        // Self-order entry — prospective customers without a customer
        // number can request service from here. The full funnel is a
        // separate design spike; this is the entrypoint placeholder.
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => GoRouter.of(context).push('/coverage-check'),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [IonColors.ion500, IonColors.ion600],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: IonColors.ion500.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering_rounded,
                    color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'New to ION?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Check coverage at your address and place an order',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandHero extends StatelessWidget {
  const _BrandHero();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // Wave 23 — login hero now uses the brand "aurora" gradient
        // (indigo → ion-blue → mint) so it feels editorial + on-brand
        // while staying consistent with home AuroraCard.
        gradient: IonColors.auroraGradient,
      ),
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wave 20 hardening — wrap the wordmark Row in ClipRect so
          // sub-pixel rounding (Flutter web reports 1.5 px overflow on
          // some viewport widths even with Expanded + ellipsis) is
          // silently clipped instead of polluting the console with
          // repeated layout assertions on every paint.
          ClipRect(
            child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(Icons.bolt_rounded, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'ION',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'CUSTOMER',
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
            ],
            ),
          ),
          const Spacer(),
          const Text(
            'Welcome back',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Manage your ION services',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            28,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: child,
        ),
      ),
    );
  }
}
