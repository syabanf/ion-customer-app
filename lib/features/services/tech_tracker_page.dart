import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ion_customer_app/shared.dart';
import '../auth/portal_auth.dart';

/// Wave 67 (C1) — Customer-facing live tech tracker.
///
/// PRD §6.2 — during an active install / maintenance WO the customer
/// should see roughly where the technician is. Backend exposes
/// `GET /portal/active-wo/tech-location` which returns the latest
/// GPS ping for the customer's most recent open WO. We poll every
/// 15 seconds while the page is foregrounded.
///
/// No map tile in round-1 (no Maps provider key in customer_app yet):
///   - Show last-seen timestamp + accuracy
///   - Surface coords as a tappable "Open in Maps" link
///   - When no active WO, show a friendly empty state
class TechTrackerPage extends StatefulWidget {
  const TechTrackerPage({super.key, required this.api});
  final PortalAuthApi api;

  @override
  State<TechTrackerPage> createState() => _TechTrackerPageState();
}

class _TechTrackerPageState extends State<TechTrackerPage> {
  static const _pollInterval = Duration(seconds: 15);

  Timer? _timer;
  bool _loading = true;
  String? _error;

  bool _hasActiveWO = false;
  String? _woId;
  String? _woStatus;
  String? _address;
  double? _lat;
  double? _lng;
  double? _accuracyM;
  DateTime? _capturedAt;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(_pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final res = await widget.api.dio.get<Map<String, dynamic>>(
        '/portal/active-wo/tech-location',
      );
      final body = res.data ?? const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = null;
        _hasActiveWO = body['has_active_wo'] as bool? ?? false;
        _woId = body['wo_id'] as String?;
        _woStatus = body['wo_status'] as String?;
        _address = body['address'] as String?;
        final ping = (body['tech_ping'] as Map?)?.cast<String, dynamic>();
        if (ping != null) {
          _lat = (ping['lat'] as num?)?.toDouble();
          _lng = (ping['lng'] as num?)?.toDouble();
          _accuracyM = (ping['accuracy_m'] as num?)?.toDouble();
          _capturedAt =
              DateTime.tryParse(ping['captured_at'] as String? ?? '');
        } else {
          _lat = _lng = _accuracyM = null;
          _capturedAt = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = IonError.humanize(e);
      });
    }
  }

  Future<void> _openInMaps() async {
    if (_lat == null || _lng == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$_lat,$_lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatRelative(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: IonAppBar(
        title: 'Track your technician',
        actions: [
          IonAppBarAction(
            icon: Icons.refresh_rounded,
            onTap: _refresh,
            tooltip: 'Refresh now',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FadeSlideIn(
              child: IonDisplayTitle(
                eyebrow: 'Service · Tracking',
                title: 'On the way',
                subtitle: 'Position auto-refreshes every 15 seconds.',
              ),
            ),
            const SizedBox(height: 12),
            if (_loading) const IonListSkeleton(count: 2),
            if (!_loading && _error != null)
              IonErrorBanner(message: _error!),
            if (!_loading && _error == null && !_hasActiveWO)
              _NoActiveWOCard(),
            if (!_loading && _error == null && _hasActiveWO)
              _ActiveWOCard(
                woId: _woId,
                woStatus: _woStatus,
                address: _address,
                lat: _lat,
                lng: _lng,
                accuracyM: _accuracyM,
                capturedAt: _capturedAt,
                onOpenMaps: _openInMaps,
                relative: _capturedAt == null
                    ? null
                    : _formatRelative(_capturedAt!),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoActiveWOCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: IonForm.surfaceBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.person_search_rounded, size: 32, color: Colors.black54),
          SizedBox(height: 8),
          Text(
            'No active visit',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          SizedBox(height: 6),
          Text(
            'When you have a scheduled installation, maintenance, or '
            'service visit, the technician\'s live position will show '
            'up here once they start their journey.',
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ActiveWOCard extends StatelessWidget {
  const _ActiveWOCard({
    required this.woId,
    required this.woStatus,
    required this.address,
    required this.lat,
    required this.lng,
    required this.accuracyM,
    required this.capturedAt,
    required this.relative,
    required this.onOpenMaps,
  });

  final String? woId;
  final String? woStatus;
  final String? address;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final DateTime? capturedAt;
  final String? relative;
  final VoidCallback onOpenMaps;

  String _statusLabel() {
    switch (woStatus) {
      case 'assigned':
        return 'Technician assigned — getting ready to go';
      case 'dispatched':
        return 'Technician is heading your way';
      case 'in_progress':
        return 'Technician on-site';
      default:
        return woStatus ?? '—';
    }
  }

  IonStatusTone _statusTone() {
    return switch (woStatus) {
      'in_progress' => IonStatusTone.success,
      'dispatched' => IonStatusTone.info,
      _ => IonStatusTone.neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    final hasPing = lat != null && lng != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: IonForm.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IonStatusPill(
                tone: _statusTone(),
                label: _statusLabel(),
              ),
              const SizedBox(height: 10),
              if (address != null && address!.isNotEmpty) ...[
                const Text(
                  'Visit address',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address!,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: IonForm.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.my_location_rounded,
                      size: 18, color: Colors.black54),
                  SizedBox(width: 6),
                  Text(
                    'Last position',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!hasPing)
                const Text(
                  'Waiting for the technician to share their position. '
                  'They\'ll show up here once they start the journey.',
                  style: TextStyle(color: Colors.black54, height: 1.4),
                )
              else ...[
                Text(
                  '${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (relative != null)
                      Text(
                        'Updated $relative',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    if (accuracyM != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        '± ${accuracyM!.toStringAsFixed(0)} m',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                IonPrimaryButton(
                  label: 'Open in Maps',
                  icon: Icons.map_rounded,
                  onPressed: onOpenMaps,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
