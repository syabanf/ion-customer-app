import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_customer_app/shared.dart';
import '../auth/portal_auth.dart';

/// ChangePlanPage — pick a target product and submit an upgrade /
/// downgrade. Server records it as a pending plan_change_request;
/// a staff member approves it via the sales-app Approvals tab.
class ChangePlanPage extends StatefulWidget {
  const ChangePlanPage({super.key, required this.api, required this.currentPlan});
  final PortalAuthApi api;

  /// Current plan map from /portal/services so we can default the
  /// segment to upgrade and exclude the current product from picks.
  final Map<String, dynamic>? currentPlan;

  @override
  State<ChangePlanPage> createState() => _ChangePlanPageState();
}

class _ChangePlanPageState extends State<ChangePlanPage> {
  String _kind = 'upgrade';
  String? _toProductId;
  final _reason = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _loadProducts();
  }

  Future<List<Map<String, dynamic>>> _loadProducts() async {
    final res = await widget.api.dio.get<Map<String, dynamic>>('/portal/products');
    return ((res.data?['items'] as List<dynamic>?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_toProductId == null) {
      setState(() => _error = 'Pick a target plan first.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.dio.post<Map<String, dynamic>>(
        '/portal/plan-change',
        data: {
          'to_product_id': _toProductId,
          'change_kind': _kind,
          if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Plan change submitted. A team member will review it.')),
      );
      GoRouter.of(context).pop(true);
    } catch (e) {
      // Wave 29 — humanize error.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCode = widget.currentPlan?['code'] as String?;
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'Change plan'),
      body: Column(children: [
        const FadeSlideIn(
          child: Padding(
            padding: EdgeInsets.only(top: 8),
            child: IonDisplayTitle(
              eyebrow: 'Services',
              title: 'Change plan',
              subtitle: 'Upgrade or downgrade your subscription tier.',
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(child: ListView(
        padding: EdgeInsets.only(
          top: 4,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          IonSection(
            title: 'Direction',
            child: IonSegmented<String>(
              value: _kind,
              options: const [
                IonSegmentedOption('upgrade', 'Upgrade'),
                IonSegmentedOption('downgrade', 'Downgrade'),
              ],
              onChanged: (v) => setState(() => _kind = v),
            ),
          ),
          IonSection(
            title: 'Target plan',
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: IonColors.ion500),
                    ),
                  );
                }
                final products = (snap.data ?? const [])
                    .where((p) => (p['code'] as String?) != currentCode)
                    .toList();
                if (products.isEmpty) {
                  return const Text(
                    'No alternative plans available right now.',
                    style: TextStyle(color: IonColors.inkMuted),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final p in products) ...[
                      _PlanOption(
                        product: p,
                        selected: _toProductId == p['id'],
                        onTap: () =>
                            setState(() => _toProductId = p['id'] as String?),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
          IonSection(
            title: 'Reason (optional)',
            child: IonField(
              label: 'Why are you changing?',
              controller: _reason,
              maxLines: 4,
              minLines: 3,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: IonErrorBanner(message: _error!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: IonPrimaryButton(
              label: _busy ? 'Submitting…' : 'Request plan change',
              icon: Icons.upgrade_rounded,
              loading: _busy,
              onPressed: _submit,
            ),
          ),
        ],
      )),
      ]),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({
    required this.product,
    required this.selected,
    required this.onTap,
  });
  final Map<String, dynamic> product;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: selected ? IonColors.ion50 : IonColors.pageBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? IonColors.ion500 : IonColors.separatorLight,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked,
                color: selected ? IonColors.ion600 : IonColors.inkMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IonColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product['speed_mbps']} Mbps · '
                      '${(product['monthly_price'] as num?)?.toStringAsFixed(0) ?? '—'} IDR/mo',
                      style: const TextStyle(
                        fontSize: 12,
                        color: IonColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
