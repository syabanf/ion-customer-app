import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_customer_app/shared.dart';

/// SelfOrderPage — the public self-order funnel.
///
/// Arrives from CoverageCheckPage with `extra` carrying the lat/lng,
/// address, and full coverage response (verdict, nearest_node_id,
/// cable_distance_m, excess_charge). User fills in contact + product,
/// optionally accepts the excess-cable charge, and we drop a lead row
/// via the public `/portal/public/self-order` endpoint.
///
/// On success we show a confirmation that a sales rep will follow up,
/// and pop the route. There's no auto-login — the customer doesn't
/// have a portal session yet; they only get one after the rep
/// converts the lead → order → account.
class SelfOrderPage extends StatefulWidget {
  const SelfOrderPage({super.key, required this.extra});
  final Map<String, dynamic> extra;

  @override
  State<SelfOrderPage> createState() => _SelfOrderPageState();
}

class _SelfOrderPageState extends State<SelfOrderPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _notes = TextEditingController();
  final List<Map<String, dynamic>> _products = [];
  String? _productId;
  bool _acceptExcess = false;
  bool _busy = false;
  String? _error;
  String? _success;

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    headers: const {'Content-Type': 'application/json'},
  ));

  Map<String, dynamic> get _coverage =>
      (widget.extra['coverage'] as Map?)?.cast<String, dynamic>() ?? const {};

  bool get _excessVerdict =>
      _coverage['verdict'] == 'covered_with_excess' ||
      _coverage['verdict'] == 'excess_distance';

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/portal/public/products');
      final items = (r.data?['items'] as List<dynamic>?) ?? const [];
      setState(() {
        _products
          ..clear()
          ..addAll(items.map((e) => Map<String, dynamic>.from(e as Map)));
      });
    } on DioException catch (_) {
      // Non-fatal — user can still submit without picking a product;
      // the lead will sit in `new` until the sales rep assigns one.
    }
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().length < 8) {
      setState(() => _error = 'Name and a valid phone number are required.');
      return;
    }
    if (_excessVerdict && !_acceptExcess) {
      setState(() => _error =
          'Please confirm you accept the excess-cable charge to continue.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final body = {
        'full_name': _name.text.trim(),
        'phone': _phone.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        'address': widget.extra['address'] ?? '',
        if (widget.extra['lat'] is num) 'gps_lat': widget.extra['lat'],
        if (widget.extra['lng'] is num) 'gps_lng': widget.extra['lng'],
        if (_productId != null) 'product_id': _productId,
        if (_coverage['nearest_node_id'] is String)
          'nearest_node_id': _coverage['nearest_node_id'],
        if (_coverage['cable_distance_m'] is num)
          'cable_distance_m': _coverage['cable_distance_m'],
        'accept_excess_cable': _acceptExcess,
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      };
      final r = await _dio.post<Map<String, dynamic>>(
        '/portal/public/self-order',
        data: body,
      );
      final leadNo = r.data?['lead_number'] as String? ?? 'submitted';
      setState(() => _success =
          'Your request ($leadNo) has been received. A sales representative '
          'will contact you within 1 business day.');
    } on DioException catch (e) {
      final body = e.response?.data;
      String msg = e.message ?? 'Network error';
      if (body is Map && body['error'] is Map) {
        msg = (body['error']['message'] as String?) ?? msg;
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_success != null) {
      return Scaffold(
        backgroundColor: IonForm.pageBg,
        appBar: const IonAppBar(title: 'Order submitted'),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  size: 64, color: Color(0xFF15803D)),
              const SizedBox(height: 12),
              const Text(
                'Thanks!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: IonColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _success!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: IonColors.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 24),
              IonPrimaryButton(
                label: 'Back to sign in',
                icon: Icons.home_rounded,
                onPressed: () => GoRouter.of(context).go('/login'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'Place an order'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const FadeSlideIn(
            child: IonDisplayTitle(
              padding: EdgeInsets.zero,
              eyebrow: 'New customer',
              title: 'Place an order',
              subtitle: 'Pick a plan, fill in your details, and we\'ll schedule install.',
            ),
          ),
          const SizedBox(height: 16),
          if (_excessVerdict)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                border: Border.all(color: const Color(0xFFFDE68A)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.straighten_rounded,
                          size: 18, color: Color(0xFFB45309)),
                      const SizedBox(width: 6),
                      Text(
                        'Excess-cable distance: ${_coverage['cable_distance_m']} m',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'A one-time cable cost of Rp ${_coverage['excess_charge']} '
                    'applies. Please confirm to continue.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF92400E),
                      height: 1.35,
                    ),
                  ),
                  SwitchListTile.adaptive(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'I accept the excess-cable charge',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E),
                      ),
                    ),
                    value: _acceptExcess,
                    onChanged: (v) => setState(() => _acceptExcess = v),
                  ),
                ],
              ),
            ),
          if (_excessVerdict) const SizedBox(height: 14),
          IonField(label: 'Full name', controller: _name),
          const SizedBox(height: 10),
          IonField(
            label: 'Phone (WhatsApp)',
            controller: _phone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          IonField(
            label: 'Email (optional)',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          if (_products.isNotEmpty) ...[
            const Text(
              'PICK A PLAN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: IonColors.inkMuted,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            ..._products.map(_buildProductTile),
            const SizedBox(height: 10),
          ],
          IonField(
            label: 'Notes (optional)',
            controller: _notes,
            maxLines: 3,
            minLines: 2,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            IonErrorBanner(message: _error!),
          ],
          const SizedBox(height: 16),
          IonPrimaryButton(
            label: _busy ? 'Submitting…' : 'Submit order',
            icon: Icons.send_rounded,
            loading: _busy,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildProductTile(Map<String, dynamic> p) {
    final id = (p['id'] as String?) ?? '';
    final selected = _productId == id;
    final monthly = (p['monthly_price'] as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _productId = id),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: selected ? IonColors.ion50 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? IonColors.ion500 : IonForm.surfaceBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? IonColors.ion500 : IonColors.inkMuted,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'] as String? ?? 'Plan',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IonColors.ink,
                      ),
                    ),
                    Text(
                      p['code'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: IonColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Rp ${monthly.toStringAsFixed(0)} /mo',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: IonColors.ion600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
