import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_customer_app/shared.dart';

/// CoverageCheckPage — public, unauthenticated self-order entry.
///
/// A prospective customer who doesn't yet have a customer-number lands
/// here from the login screen. We let them:
///   1. type an address (placeholder for a map picker — out of scope
///      for the first cut; a real implementation will swap in a
///      Mapbox / Google Maps tile and a draggable pin),
///   2. tap "Check coverage" to call /api/network/coverage/check via a
///      lightweight unauthenticated Dio instance (the endpoint is on
///      the public surface today; if we tighten that later we'll mint
///      a short-lived "coverage-only" token from the gateway), and
///   3. see one of: green/covered, amber/excess, red/no-coverage.
///
/// Submitting the lead is intentionally deferred — the gap doc calls
/// the full funnel a separate design spike. This page satisfies the
/// "we have an entry point" half of the gap so the rest can land in
/// follow-up PRs without re-touching login.
class CoverageCheckPage extends StatefulWidget {
  const CoverageCheckPage({super.key});

  @override
  State<CoverageCheckPage> createState() => _CoverageCheckPageState();
}

class _CoverageCheckPageState extends State<CoverageCheckPage> {
  final _address = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  Map<String, dynamic>? _result;
  String? _error;
  bool _busy = false;

  late final Dio _dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    headers: const {'Content-Type': 'application/json'},
  ));

  @override
  void dispose() {
    _address.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) {
      setState(() => _error = 'Enter both latitude and longitude');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      // Public portal endpoint — bypasses RequireAuth so a prospective
      // customer (no portal session yet) can probe coverage.
      final r = await _dio.post<Map<String, dynamic>>(
        '/portal/public/coverage-check',
        data: {'lat': lat, 'lng': lng},
      );
      setState(() => _result = r.data);
    } catch (e) {
      // Wave 29 — humanize error.
      setState(() => _error = IonError.humanize(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: const IonAppBar(title: 'Check coverage'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const FadeSlideIn(
            child: IonDisplayTitle(
              padding: EdgeInsets.zero,
              eyebrow: 'Step 1 of 2',
              title: 'Check coverage',
              subtitle: 'We\'ll see if your address is in our service area.',
            ),
          ),
          const SizedBox(height: 16),
          // Map placeholder — replaced by Mapbox in v2.
          Container(
            height: 180,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              // Wave 24 — align with standard 16-radius card recipe;
              // an 18-radius outlier was breaking the rhythm with
              // surrounding _Card / IonSection surfaces.
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.map_outlined,
                    size: 36, color: IonColors.ion500),
                SizedBox(height: 8),
                Text(
                  'Map picker coming soon',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: IonColors.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'For now, paste your latitude + longitude below.',
                  style: TextStyle(fontSize: 11, color: IonColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          IonField(
            label: 'Address',
            hint: 'House number, street, area',
            controller: _address,
            maxLines: 2,
            minLines: 1,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: IonField(
                  label: 'Latitude',
                  hint: '-6.200000',
                  controller: _lat,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true, decimal: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: IonField(
                  label: 'Longitude',
                  hint: '106.816000',
                  controller: _lng,
                  keyboardType:
                      const TextInputType.numberWithOptions(signed: true, decimal: true),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            IonErrorBanner(message: _error!),
          ],
          if (_result != null) ...[
            const SizedBox(height: 14),
            _ResultCard(result: _result!),
            if (_result!['verdict'] == 'covered' ||
                _result!['verdict'] == 'covered_with_excess') ...[
              const SizedBox(height: 12),
              IonPrimaryButton(
                label: 'Continue with this order',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => GoRouter.of(context).push(
                  '/self-order',
                  extra: {
                    'lat': double.tryParse(_lat.text.trim()) ?? 0.0,
                    'lng': double.tryParse(_lng.text.trim()) ?? 0.0,
                    'address': _address.text.trim(),
                    'coverage': _result,
                  },
                ),
              ),
            ],
          ],
          const SizedBox(height: 18),
          IonPrimaryButton(
            label: _busy ? 'Checking…' : 'Check coverage',
            icon: Icons.search_rounded,
            loading: _busy,
            onPressed: _check,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () => GoRouter.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 14),
            label: const Text('Back to sign in'),
            style: TextButton.styleFrom(
              foregroundColor: IonColors.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Need help? Call ION sales — full self-service ordering is launching soon.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: IonColors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final verdict = (result['verdict'] as String?) ?? 'unknown';
    Color color;
    String headline;
    String subtitle;
    IconData icon;
    switch (verdict) {
      case 'covered':
        color = const Color(0xFF15803D);
        icon = Icons.check_circle_outline_rounded;
        headline = 'Great news — you\'re in our coverage area.';
        subtitle = 'Standard installation, no extra cable cost.';
        break;
      case 'covered_with_excess':
      case 'excess_distance':
        color = const Color(0xFFB45309);
        icon = Icons.straighten_rounded;
        final m = (result['cable_distance_m'] as num?)?.toStringAsFixed(0);
        final excess = (result['excess_charge'] as num?)?.toStringAsFixed(0);
        headline = 'Address is just outside our standard radius.';
        subtitle =
            'Distance to nearest node: $m m. One-time cable charge: Rp $excess.';
        break;
      case 'no_coverage':
      case 'uncovered':
        color = const Color(0xFFB91C1C);
        icon = Icons.cancel_outlined;
        headline = 'Not yet covered.';
        subtitle =
            'We don\'t serve this address today. Leave your details and we\'ll notify you when it lights up.';
        break;
      default:
        color = IonColors.inkMuted;
        icon = Icons.help_outline_rounded;
        headline = 'Unable to determine coverage.';
        subtitle = 'Try a more precise GPS pin or contact sales.';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: IonColors.ink, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
