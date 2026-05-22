import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_customer_app/shared.dart';
import '../auth/portal_auth.dart';

/// BuyAddonPage — catalog grid; tap an add-on to buy. Install-
/// required addons spawn a maintenance WO automatically server-side.
class BuyAddonPage extends StatefulWidget {
  const BuyAddonPage({super.key, required this.api});
  final PortalAuthApi api;

  @override
  State<BuyAddonPage> createState() => _BuyAddonPageState();
}

class _BuyAddonPageState extends State<BuyAddonPage> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final res =
        await widget.api.dio.get<Map<String, dynamic>>('/portal/addons-catalog');
    return ((res.data?['items'] as List<dynamic>?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _buy(Map<String, dynamic> addon) async {
    setState(() {
      _busyId = (addon['id'] as String?) ?? '';
      _error = null;
    });
    try {
      final res = await widget.api.dio.post<Map<String, dynamic>>(
        '/portal/addons/buy',
        data: {'addon_id': addon['id'], 'quantity': 1},
      );
      if (!mounted) return;
      final requiresInstall = (res.data?['requires_install'] as bool?) ?? false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(requiresInstall
              ? 'Ordered. A tech will be in touch to schedule the install.'
              : 'Ordered. Add-on is now active.'),
        ),
      );
      GoRouter.of(context).pop(true);
    } catch (e) {
      // Wave 29 — humanize error.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'Buy add-on'),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: IonColors.ion500),
            );
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: IonErrorBanner(message: 'Failed: ${snap.error}'),
            );
          }
          final items = snap.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
            children: [
              const FadeSlideIn(
                child: IonDisplayTitle(
                  eyebrow: 'Services',
                  title: 'Buy add-on',
                  subtitle: 'Boost your plan with extra speed or features.',
                ),
              ),
              const SizedBox(height: 18),
              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: IonErrorBanner(message: _error!),
                ),
                const SizedBox(height: 12),
              ],
              for (final a in items) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _AddonRow(
                    addon: a,
                    busy: _busyId == a['id'],
                    onBuy: () => _buy(a),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AddonRow extends StatelessWidget {
  const _AddonRow({
    required this.addon,
    required this.busy,
    required this.onBuy,
  });
  final Map<String, dynamic> addon;
  final bool busy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: IonColors.ion100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(addon['addon_type'] as String? ?? ''),
                  color: IonColors.ion600,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addon['name'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IonColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      addon['code'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: IonColors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if ((addon['requires_install'] as bool?) ?? false)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'INSTALL',
                    style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFFB45309),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          if ((addon['description'] as String?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Text(
              addon['description'] as String,
              style: const TextStyle(
                fontSize: 12,
                color: IonColors.inkMuted,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _Price(
                label: 'One-time',
                amount: (addon['one_time_fee'] as num?)?.toDouble() ?? 0,
              ),
              const SizedBox(width: 18),
              _Price(
                label: 'Monthly',
                amount: (addon['monthly_fee'] as num?)?.toDouble() ?? 0,
              ),
              const Spacer(),
              IonPrimaryButton(
                label: busy ? 'Buying…' : 'Buy',
                icon: Icons.shopping_bag_rounded,
                loading: busy,
                onPressed: onBuy,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'speed_boost':
        return Icons.rocket_launch_outlined;
      case 'iptv':
        return Icons.live_tv_outlined;
      case 'cctv':
        return Icons.videocam_outlined;
      case 'static_ip':
        return Icons.dns_outlined;
      case 'wifi_extender':
        return Icons.wifi_outlined;
      default:
        return Icons.add_box_outlined;
    }
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.label, required this.amount});
  final String label;
  final double amount;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: IonColors.inkMuted,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          amount == 0 ? '—' : amount.toStringAsFixed(0),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: IonColors.ink,
          ),
        ),
      ],
    );
  }
}
