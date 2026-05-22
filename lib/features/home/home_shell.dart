import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:ion_customer_app/shared.dart';
import '../auth/portal_auth.dart';

/// Bottom-tab shell — Home / Services / Bills / Support / Account.
/// Uses the same shared widget vocabulary as the staff apps.
class CustomerHomeShell extends StatefulWidget {
  const CustomerHomeShell({super.key, required this.api});
  final PortalAuthApi api;

  @override
  State<CustomerHomeShell> createState() => _CustomerHomeShellState();
}

class _CustomerHomeShellState extends State<CustomerHomeShell> {
  int _tab = 0;
  Map<String, dynamic>? _me;
  Map<String, dynamic>? _services;
  List<dynamic> _invoices = const [];
  List<dynamic> _tickets = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = widget.api.dio;
      final meR = await dio.get<Map<String, dynamic>>('/portal/me');
      final svcR = await dio.get<Map<String, dynamic>>('/portal/services');
      final invR = await dio.get<Map<String, dynamic>>('/portal/invoices');
      final tktR = await dio.get<Map<String, dynamic>>('/portal/tickets');
      setState(() {
        _me = meR.data;
        _services = svcR.data;
        // Wave 20 — null-tolerant cast: if the backend returns no
        // `items` key, or returns null, render an empty list instead
        // of throwing a TypeError that blanks the page.
        _invoices = (invR.data?['items'] as List<dynamic>?) ?? const [];
        _tickets = (tktR.data?['items'] as List<dynamic>?) ?? const [];
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = _msg(e);
        _loading = false;
      });
    } catch (e) {
      // Catch-all so an unexpected JSON shape can't blank the canvas.
      setState(() {
        _error = 'Could not load your account: $e';
        _loading = false;
      });
    }
  }

  String _msg(DioException e) {
    final body = e.response?.data;
    if (body is Map && body['error'] is Map) {
      return (body['error']['message'] as String?) ?? 'Error';
    }
    return e.message ?? 'Network error';
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _HomeTab(me: _me, services: _services, invoices: _invoices, tickets: _tickets, onJumpToTab: (i) => setState(() => _tab = i), api: widget.api),
      _ServicesTab(services: _services, onReload: _reload),
      _BillsTab(items: _invoices, api: widget.api, onPaid: _reload),
      _SupportTab(items: _tickets, onCreated: _reload),
      _AccountTab(me: _me, api: widget.api),
    ];
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: IonAppBar(
        title: _title(_tab),
        actions: [
          IonAppBarAction(
            icon: Icons.search_rounded,
            onTap: () => _openSearch(context),
          ),
          IonAppBarAction(
            icon: Icons.notifications_none_rounded,
            onTap: () => GoRouter.of(context).push('/notifications'),
          ),
          IonAppBarAction(icon: Icons.refresh_rounded, onTap: _reload),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: IonColors.ion500))
          : (_error != null
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: IonErrorBanner(message: _error!),
                )
              : IonAnimatedTabs(index: _tab, children: tabs)),
      bottomNavigationBar: _BottomNav(
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
        unpaidCount: _unpaidCount(),
        openTickets: _openTicketCount(),
      ),
    );
  }

  String _title(int t) {
    switch (t) {
      case 0:
        return 'Home';
      case 1:
        return 'Services';
      case 2:
        return 'Bills';
      case 3:
        return 'Support';
      case 4:
        return 'Account';
    }
    return '';
  }

  int _unpaidCount() => _invoices.whereType<Map<String, dynamic>>().where((i) => i['status'] != 'paid').length;
  int _openTicketCount() => _tickets.whereType<Map<String, dynamic>>().where((t) => !['resolved', 'closed'].contains(t['status'])).length;

  /// Global search — pulls invoices + tickets + a few top-level
  /// destinations into a unified IonSearchSheet so the user can jump
  /// anywhere from one place.
  Future<void> _openSearch(BuildContext context) async {
    final entries = <IonSearchEntry>[
      // Top-level destinations (always available).
      const IonSearchEntry(
        id: 'tab:home',
        title: 'Home',
        subtitle: 'Plan summary + quick actions',
        icon: Icons.home_rounded,
        tag: 'PAGE',
      ),
      const IonSearchEntry(
        id: 'tab:services',
        title: 'Services',
        subtitle: 'Active plans, add-ons, upgrades',
        icon: Icons.dashboard_customize_rounded,
        tag: 'PAGE',
      ),
      const IonSearchEntry(
        id: 'tab:bills',
        title: 'Bills',
        subtitle: 'Invoices, payments, history',
        icon: Icons.receipt_long_rounded,
        tag: 'PAGE',
      ),
      const IonSearchEntry(
        id: 'tab:support',
        title: 'Support',
        subtitle: 'Tickets, FAQ, contact CS',
        icon: Icons.support_agent_rounded,
        tag: 'PAGE',
      ),
      const IonSearchEntry(
        id: 'route:/notifications',
        title: 'Notifications',
        subtitle: 'Your account activity feed',
        icon: Icons.notifications_none_rounded,
        tag: 'PAGE',
      ),
      // Invoices (dynamic).
      for (final inv in _invoices.whereType<Map<String, dynamic>>().take(10))
        IonSearchEntry(
          id: 'invoice:${inv['id'] ?? inv['invoice_no']}',
          title: 'Invoice ${inv['invoice_no'] ?? inv['id']}',
          subtitle: 'Status: ${inv['status'] ?? '—'}',
          icon: Icons.receipt_outlined,
          accent: IonColors.indigo500,
          tag: 'INVOICE',
        ),
      // Tickets (dynamic).
      for (final t in _tickets.whereType<Map<String, dynamic>>().take(10))
        IonSearchEntry(
          id: 'ticket:${t['id'] ?? t['ticket_no']}',
          title: 'Ticket ${t['ticket_no'] ?? t['id']}',
          subtitle: '${t['subject'] ?? t['title'] ?? 'Open ticket'}',
          icon: Icons.support_agent_rounded,
          accent: IonColors.mint500,
          tag: 'TICKET',
        ),
    ];

    final picked = await IonSearchSheet.show(
      context,
      entries: entries,
      placeholder: 'Search bills, tickets, pages…',
    );
    if (picked == null) return;
    if (!mounted) return;
    final id = picked.id;
    if (id.startsWith('tab:')) {
      final names = {'home': 0, 'services': 1, 'bills': 2, 'support': 3};
      final next = names[id.substring(4)];
      if (next != null) setState(() => _tab = next);
    } else if (id.startsWith('route:')) {
      GoRouter.of(context).push(id.substring(6));
    } else if (id.startsWith('ticket:')) {
      GoRouter.of(context).push('/support/tickets/${id.substring(7)}');
    } else if (id.startsWith('invoice:')) {
      setState(() => _tab = 2); // jump to Bills tab
    }
  }
}

// =============================================================================
// Home tab — service status + quick actions + at-a-glance bill/ticket counts
// =============================================================================

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.me,
    required this.services,
    required this.invoices,
    required this.tickets,
    required this.onJumpToTab,
    required this.api,
  });
  final Map<String, dynamic>? me;
  final Map<String, dynamic>? services;
  final List<dynamic> invoices;
  final List<dynamic> tickets;
  final ValueChanged<int> onJumpToTab;
  final PortalAuthApi api;

  @override
  Widget build(BuildContext context) {
    final status = (me?['status'] as String?) ?? 'unknown';
    final plan = services?['plan'] as Map<String, dynamic>?;
    final unpaid = invoices.whereType<Map<String, dynamic>>().where((i) => i['status'] != 'paid').length;
    final openTickets = tickets.whereType<Map<String, dynamic>>().where((t) => !['resolved', 'closed'].contains(t['status'])).length;

    // Wave 21 — clean dashboard home layout.
    //   1. Greeting display title (date pill + name + subtitle)
    //   2. Aurora hero card — current plan + live status dot
    //   3. Live tech tracker (only when there's an active WO)
    //   4. Trend-aware metric row — Unpaid / Tickets with green/red
    //      arrows + delta vs last period
    //   5. Quick access grid (6 tiles — Pay, Speed test, Support,
    //      Plan, Coverage, Settings)
    //   6. Recent activity strip (latest invoice + latest ticket)
    final shortDate = DateFormat('EEEE, MMM d').format(DateTime.now());
    final fullName = (me?['full_name'] as String?) ?? 'Customer';
    final firstName = fullName.split(' ').first;
    final planName = (plan?['name'] as String?) ?? 'No active plan';
    final planSpeed = (plan?['speed_mbps'] as num?)?.toInt();
    final isActive = status == 'active';
    // Wave 26 — every direct child of this ListView lives at the same
    // page horizontal margin (IonGap.l = 20). Vertical rhythm uses
    // IonGap.xl (24) between sections so the cards never look "off-
    // sides" or mis-aligned. No widget should set its own horizontal
    // margin — the parent owns it via IonGap.pageH.
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, IonGap.xs, 0, IonGap.xl + 4),
      children: [
        // 1) Greeting hero (IonDisplayTitle bakes IonGap.pageH in by
        //    default).
        FadeSlideIn(
          child: IonDisplayTitle(
            eyebrow: shortDate,
            title: 'Hi, $firstName',
            subtitle: isActive
                ? 'Your connection is live and healthy.'
                : 'Account · ${IonHumanize.status(status)}',
            trailing: IonCircleIconButton(
              icon: Icons.notifications_outlined,
              onTap: () => GoRouter.of(context).push('/notifications'),
            ),
          ),
        ),
        IonGap.xlGap,

        // 2) Plan hero as a bento — big photo card + 2 mini stats.
        //    IonPaletteBuilder extracts the dominant color from the
        //    plan photo and forwards it to the secondary mini stat
        //    (Spotify-style content-aware UI).
        FadeSlideIn(
          delay: const Duration(milliseconds: 60),
          child: Padding(
            padding: IonGap.pageH,
            child: IonPaletteBuilder(
              imageUrl: _planPhotoUrl(planSpeed),
              fallback: IonColors.indigo500,
              builder: (context, photoAccent) => IonBentoGrid(
                height: 220,
                feature: IonPhotoCard(
                  imageUrl: _planPhotoUrl(planSpeed),
                  // Wave 24 — pulse the "Live" ribbon via IonHeartbeat
                  // so the eye snaps to it immediately. amplitude kept
                  // gentle (0.06) so it doesn't look frantic.
                  ribbon: isActive
                      ? const IonHeartbeat(
                          amplitude: 0.06,
                          period: Duration(milliseconds: 1800),
                          child: IonRibbonBadge(
                            label: 'Live',
                            color: IonColors.mint500,
                          ),
                        )
                      : null,
                  eyebrow: 'Current plan',
                  title: planName,
                  // Wave 39 — hero subtitle no longer mentions "Renews"
                  // because the tertiary bento tile (below) is the
                  // authoritative renewal surface. Repeating it both
                  // places made the screen read like an error.
                  subtitle: planSpeed == null
                      ? 'Manage your services'
                      : '$planSpeed Mbps · Active',
                  trailing: IonCircleIconButton(
                    icon: Icons.upgrade_rounded,
                    onTap: () => GoRouter.of(context)
                        .push('/services/change-plan', extra: plan),
                    tone: IonCircleIconTone.light,
                  ),
                  onTap: () => onJumpToTab(1),
                ),
                secondary: _MiniStatTile(
                  icon: Icons.speed_rounded,
                  label: 'Plan',
                  value: planSpeed == null ? '—' : '$planSpeed',
                  suffix: 'Mbps',
                  // Content-aware: secondary stat picks up the
                  // dominant photo color once extraction completes.
                  accent: photoAccent,
                ),
                // Wave 28 — was a duplicate "Status: Live" mini stat
                // (the photo card already has a LIVE ribbon, the live
                // tracker says "Live · updated 2 min ago"). Replaced
                // with renewal info — actually useful info-per-pixel
                // that the customer can't get elsewhere on the home tab.
                //
                // Wave 39 — when we have an actual renewal date, show
                // it under a "Renews" label. When we don't, the empty
                // dash placeholder felt broken — fall back to
                // "Monthly" under a "Cycle" label so the tile always
                // carries real meaning instead of looking half-loaded.
                tertiary: _renewTertiaryTile(plan),
              ),
            ),
          ),
        ),

        // 3) Trend-aware metric row
        //    Wave 39 — removed the Live tech-tracker card. The bento
        //    above already carries the active-WO signal (LIVE ribbon
        //    + "Technician · In progress" was duplicating it), and
        //    customers can drill from the photo card itself.
        FadeSlideIn(
          delay: const Duration(milliseconds: 120),
          child: Padding(
            padding: IonGap.pageH,
            child: Row(
              children: [
                Expanded(
                  child: IonMetricTile(
                    icon: Icons.receipt_long_outlined,
                    label: 'Unpaid bills',
                    value: '$unpaid',
                    numericValue: unpaid,
                    sparkline: _billsSparkline(invoices),
                    accent: unpaid > 0
                        ? IonColors.danger
                        : IonColors.mint500,
                    delta: unpaid > 0
                        ? 'Action needed'
                        : 'All paid',
                    trend: unpaid > 0 ? IonTrend.down : IonTrend.up,
                    onTap: () => onJumpToTab(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: IonMetricTile(
                    icon: Icons.support_agent_outlined,
                    label: 'Open tickets',
                    value: '$openTickets',
                    numericValue: openTickets,
                    sparkline: _ticketsSparkline(tickets),
                    accent: openTickets > 0
                        ? IonColors.peach500
                        : IonColors.mint500,
                    delta: openTickets > 0
                        ? 'In progress'
                        : 'Nothing pending',
                    trend: openTickets > 0
                        ? IonTrend.flat
                        : IonTrend.up,
                    onTap: () => onJumpToTab(3),
                  ),
                ),
              ],
            ),
          ),
        ),

        IonGap.xlGap,

        // 5) Quick access — Awwwards-style 4-col grid
        const IonChipDivider(label: 'Quick access'),
        IonGap.sGap,
        FadeSlideIn(
          delay: const Duration(milliseconds: 180),
          child: Padding(
            padding: IonGap.pageH,
            child: IonQuickAccessGrid(
              items: [
                IonQuickAccessItem(
                  icon: Icons.payments_outlined,
                  label: 'Pay bill',
                  accent: IonColors.peach500,
                  badge: unpaid > 0 ? unpaid : null,
                  onTap: () => onJumpToTab(2),
                ),
                IonQuickAccessItem(
                  icon: Icons.support_agent_outlined,
                  label: 'Support',
                  accent: IonColors.indigo500,
                  badge: openTickets > 0 ? openTickets : null,
                  onTap: () => onJumpToTab(3),
                ),
                IonQuickAccessItem(
                  icon: Icons.upgrade_rounded,
                  label: 'Change plan',
                  accent: IonColors.ion500,
                  onTap: () => GoRouter.of(context)
                      .push('/services/change-plan', extra: plan),
                ),
                IonQuickAccessItem(
                  icon: Icons.add_box_outlined,
                  label: 'Buy add-on',
                  accent: IonColors.mint500,
                  onTap: () => GoRouter.of(context).push('/services/buy-addon'),
                ),
                IonQuickAccessItem(
                  icon: Icons.location_on_outlined,
                  label: 'Relocate',
                  accent: IonColors.plum500,
                  onTap: () => GoRouter.of(context).push('/services/relocation'),
                ),
                // Wave 67 (C1) — live tech tracker entry from quick access.
                // The page itself reads the active WO via /portal/active-wo/
                // tech-location; when no active WO, the destination
                // gracefully shows an empty state.
                IonQuickAccessItem(
                  icon: Icons.my_location_rounded,
                  label: 'Track tech',
                  accent: IonColors.mint500,
                  onTap: () => GoRouter.of(context).push('/services/track'),
                ),
                IonQuickAccessItem(
                  icon: Icons.travel_explore_rounded,
                  label: 'Coverage',
                  accent: IonColors.cream500,
                  onTap: () => GoRouter.of(context).push('/coverage-check'),
                ),
                IonQuickAccessItem(
                  icon: Icons.notifications_outlined,
                  label: 'Inbox',
                  accent: IonColors.ion600,
                  onTap: () => GoRouter.of(context).push('/notifications'),
                ),
                IonQuickAccessItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  accent: IonColors.inkBlack,
                  onTap: () => onJumpToTab(4),
                ),
              ],
            ),
          ),
        ),

        // 7) Recent invoices carousel — IonHorizontalCarousel of mini
        //    photo cards, one per recent invoice. Swipe horizontally
        //    to scan billing history. Only shows when ≥1 invoice.
        if (invoices.isNotEmpty) ...[
          IonGap.xlGap,
          const IonChipDivider(label: 'Recent invoices'),
          IonGap.sGap,
          FadeSlideIn(
            delay: const Duration(milliseconds: 220),
            child: IonHorizontalCarousel(
              itemWidth: 240,
              height: 160,
              showDots: invoices.length > 1,
              children: [
                for (final inv
                    in invoices.cast<Map<String, dynamic>>().take(6))
                  _RecentInvoiceCard(invoice: inv, onTap: () => onJumpToTab(2)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Synthesize a 7-point sparkline for unpaid bills from the invoice
  /// list. We don't have historical aging data, so render a simple
  /// monotone ramp toward the current value — gives the tile motion
  /// without lying about real history.
  List<double> _billsSparkline(List<dynamic> invs) {
    final n = invs.whereType<Map<String, dynamic>>().where((i) => i['status'] != 'paid').length.toDouble();
    if (n == 0) return [0, 0, 0, 1, 1, 0, 0];
    return [
      (n * 0.6),
      (n * 0.8),
      (n * 0.7),
      (n * 0.9),
      (n * 0.85),
      (n * 1.0),
      n,
    ];
  }

  /// Same lazy-ramp approach for tickets.
  List<double> _ticketsSparkline(List<dynamic> ts) {
    final n = ts
        .whereType<Map<String, dynamic>>()
        .where((t) =>
            !['resolved', 'closed'].contains(t['status']))
        .length
        .toDouble();
    if (n == 0) return [1, 0, 1, 0, 0, 0, 0];
    return [n * 0.3, n * 0.5, n * 0.7, n * 0.65, n * 0.9, n * 0.95, n];
  }

  /// Wave 23 — curated Unsplash photo per plan speed tier. None of
  /// the images are bundled with the app; they live on Unsplash CDN
  /// so a fresh customer with no plan-photo upload still gets a
  /// branded hero. Photos picked once for visual coherence with the
  /// ION brand palette (cool blues, fiber filaments, network-feel).
  String _planPhotoUrl(int? speedMbps) {
    if (speedMbps == null) {
      // No plan — show the calm "abstract data" image.
      return 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&q=80&auto=format&fit=crop';
    }
    if (speedMbps >= 500) {
      // Premium tier — fiber-strands close-up, electric blue.
      return 'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&q=80&auto=format&fit=crop';
    }
    if (speedMbps >= 100) {
      // Standard tier — connected-city / network feel.
      return 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800&q=80&auto=format&fit=crop';
    }
    // Starter tier — warm desk/home wifi vibe.
    return 'https://images.unsplash.com/photo-1593642632559-0c6d3fc62b89?w=800&q=80&auto=format&fit=crop';
  }

  /// Wave 39 — pick the right rendering for the bento's tertiary tile:
  /// a real date when we have one, a "Monthly · Cycle" pair when we
  /// don't. Avoids the half-loaded "—" placeholder that read as broken.
  Widget _renewTertiaryTile(Map<String, dynamic>? plan) {
    final iso = plan?['renews_at'] as String?;
    final dt = iso == null ? null : DateTime.tryParse(iso);
    if (dt != null) {
      return _MiniStatTile(
        icon: Icons.event_repeat_rounded,
        label: 'Renews',
        value: DateFormat('MMM d').format(dt.toLocal()),
        accent: IonColors.peach500,
      );
    }
    // No specific renewal date — show the implicit cadence instead.
    // Customers get the cadence info without the screen looking like
    // a value failed to fetch.
    return _MiniStatTile(
      icon: Icons.event_repeat_rounded,
      label: 'Cycle',
      value: 'Monthly',
      accent: IonColors.peach500,
    );
  }

}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({required this.name, required this.date});
  final String name;
  final String date;
  @override
  Widget build(BuildContext context) {
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Good Morning' : (h < 18 ? 'Good Afternoon' : 'Good Evening');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IonDatePill(label: date, icon: Icons.calendar_today_rounded),
        const SizedBox(height: 10),
        Text(
          '$greeting,',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: IonColors.ink,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
        Text(
          name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: IonColors.ink,
            height: 1.1,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.plan});
  final String status;
  final Map<String, dynamic>? plan;
  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    final tint = isActive
        ? const [IonColors.ion500, IonColors.ion600]
        : (status == 'suspended'
            ? const [Color(0xFFB45309), Color(0xFF92400E)]
            : const [Color(0xFF52606D), Color(0xFF1F2933)]);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tint,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tint.last.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  IonHumanize.status(status).toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                isActive ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            plan == null ? 'No active plan' : (plan!['name'] as String? ?? 'Plan'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            plan == null
                ? 'Contact ION sales to subscribe.'
                : '${plan!['speed_mbps']} Mbps · ${(plan!['monthly'] as num?)?.toStringAsFixed(0) ?? '—'} IDR/mo',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.fg,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  final Color fg;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: IonForm.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: tint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: fg, size: 18),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: IonColors.ink,
                      height: 1,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: IonColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: IonForm.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: IonColors.ion100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: IonColors.ion600, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: IonColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: IonColors.inkMuted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: IonColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Services tab — current plan + active add-ons
// =============================================================================

class _ServicesTab extends StatelessWidget {
  const _ServicesTab({required this.services, required this.onReload});
  final Map<String, dynamic>? services;
  final VoidCallback onReload;
  @override
  Widget build(BuildContext context) {
    final plan = services?['plan'] as Map<String, dynamic>?;
    final addons = (services?['addons'] as List<dynamic>?) ?? const [];
    return RefreshIndicator(
      // Wave 24 — branded pull-to-refresh. inkBlack spinner over a
      // soft chip-bg disc mirrors the rest of the design system.
      color: IonColors.inkBlack,
      backgroundColor: IonColors.chipBg,
      strokeWidth: 2.5,
      edgeOffset: 8,
      onRefresh: () async => onReload(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const Text(
            'My services',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: IonColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Action shortcuts — change plan / buy add-on / relocate.
          Row(
            children: [
              Expanded(
                child: _ServiceAction(
                  icon: Icons.upgrade_rounded,
                  label: 'Change plan',
                  onTap: () => GoRouter.of(context).push(
                    '/services/change-plan',
                    extra: plan,
                  ).then((_) => onReload()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ServiceAction(
                  icon: Icons.add_box_outlined,
                  label: 'Buy add-on',
                  onTap: () => GoRouter.of(context)
                      .push('/services/buy-addon')
                      .then((_) => onReload()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ServiceAction(
                  icon: Icons.location_on_outlined,
                  label: 'Relocate',
                  onTap: () => GoRouter.of(context)
                      .push('/services/relocation')
                      .then((_) => onReload()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          IonSection(
            title: 'Current plan',
            child: plan == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'No active plan on file.',
                      style: TextStyle(color: IonColors.inkMuted),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan['name'] as String? ?? 'Plan',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: IonColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${plan['speed_mbps']} Mbps · ${(plan['monthly'] as num?)?.toStringAsFixed(0) ?? '—'} IDR/mo',
                        style: const TextStyle(
                          fontSize: 13,
                          color: IonColors.inkMuted,
                        ),
                      ),
                    ],
                  ),
          ),
          IonSection(
            title: 'Add-ons (${addons.length})',
            child: addons.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'No add-ons. Contact ION to subscribe.',
                      style: TextStyle(color: IonColors.inkMuted),
                    ),
                  )
                : Column(
                    children: [
                      for (final a in addons.cast<Map<String, dynamic>>())
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: IonColors.ion100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.shopping_bag_outlined,
                                    color: IonColors.ion600, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      a['name'] as String? ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: IonColors.ink,
                                      ),
                                    ),
                                    Text(
                                      '${a['quantity']}× · ${(a['monthly_fee'] as num?)?.toStringAsFixed(0) ?? '—'} IDR/mo',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: IonColors.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _statusColor(a['status'] as String? ?? '').withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  (a['status'] as String? ?? '').replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _statusColor(a['status'] as String? ?? ''),
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'active':
        return const Color(0xFF15803D);
      case 'pending_install':
        return const Color(0xFFB45309);
      case 'cancelled':
        return IonColors.inkMuted;
      default:
        return IonColors.inkMuted;
    }
  }
}

class _ServiceAction extends StatelessWidget {
  const _ServiceAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: IonForm.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: IonColors.ion100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: IonColors.ion600, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: IonColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Bills tab
// =============================================================================

class _BillsTab extends StatelessWidget {
  const _BillsTab({required this.items, required this.api, required this.onPaid});
  final List<dynamic> items;
  final PortalAuthApi api;
  final VoidCallback onPaid;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        const Text(
          'Bills',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: IonColors.ink,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${items.length} invoice${items.length == 1 ? "" : "s"} on file',
          style: const TextStyle(fontSize: 13, color: IonColors.inkMuted),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          _empty('No invoices yet', Icons.receipt_long_outlined)
        else
          // Wave 20 — stagger invoice cards in via FadeSlideIn with a
          // 60 ms step delay between rows. Total stagger caps at 10
          // rows so very long bills lists still land within ~600 ms.
          for (var i = 0; i < items.length; i++) ...[
            FadeSlideIn(
              delay: Duration(milliseconds: 60 * i.clamp(0, 10)),
              child: _InvoiceCard(
                invoice: items[i] as Map<String, dynamic>,
                api: api,
                onPaid: onPaid,
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.api,
    required this.onPaid,
  });
  final Map<String, dynamic> invoice;
  final PortalAuthApi api;
  final VoidCallback onPaid;
  @override
  Widget build(BuildContext context) {
    final status = invoice['status'] as String? ?? 'unknown';
    final paid = status == 'paid';
    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    final issued = DateTime.tryParse(invoice['issued_at'] as String? ?? '');
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: paid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  paid ? Icons.check_circle_outline : Icons.receipt_long_outlined,
                  color: paid ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice['invoice_number'] as String? ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: IonColors.ink,
                      ),
                    ),
                    if (issued != null)
                      Text(
                        DateFormat('MMM d, yyyy').format(issued.toLocal()),
                        style: const TextStyle(
                          fontSize: 11,
                          color: IonColors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
              // Wave 20.1 — Use IonStatusPill so every invoice status
              // (paid / unpaid / pending / overdue) reads with the
              // same vocabulary as tickets, WOs, and other surfaces.
              IonStatusPill(
                label: status,
                tone: paid
                    ? IonStatusTone.success
                    : (status == 'overdue'
                        ? IonStatusTone.danger
                        : IonStatusTone.warning),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice['kind'] as String? ?? 'invoice',
                    style: const TextStyle(
                      fontSize: 11,
                      color: IonColors.inkMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  Text(
                    total.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: IonColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Text(
                    'IDR',
                    style: TextStyle(fontSize: 10, color: IonColors.inkMuted),
                  ),
                ],
              ),
              const Spacer(),
              if (!paid)
                IonPrimaryButton(
                  label: 'Pay',
                  icon: Icons.payments_outlined,
                  onPressed: () => _openPaySheet(context),
                  // Inline placement inside a Row — `compact` keeps the
                  // button at its natural width instead of grabbing
                  // infinity, which would throw a layout assertion.
                  compact: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openPaySheet(BuildContext context) async {
    final invoiceId = invoice['id'] as String?;
    if (invoiceId == null) return;
    String method = 'xendit_va';
    String bank = 'BCA';
    final picked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: 18 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Pay invoice',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: IonColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                invoice['invoice_number'] as String? ?? '',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: IonColors.inkMuted,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'PAYMENT METHOD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: IonColors.inkMuted,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              RadioListTile<String>(
                dense: true,
                value: 'xendit_va',
                groupValue: method,
                title: const Text('Bank Virtual Account'),
                onChanged: (v) => setSheet(() => method = v!),
              ),
              RadioListTile<String>(
                dense: true,
                value: 'xendit_qris',
                groupValue: method,
                title: const Text('QRIS'),
                onChanged: (v) => setSheet(() => method = v!),
              ),
              RadioListTile<String>(
                dense: true,
                value: 'manual_transfer',
                groupValue: method,
                title: const Text('Manual bank transfer'),
                onChanged: (v) => setSheet(() => method = v!),
              ),
              if (method == 'xendit_va' || method == 'manual_transfer') ...[
                const SizedBox(height: 8),
                const Text(
                  'BANK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: IonColors.inkMuted,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: const ['BCA', 'BNI', 'BRI', 'MANDIRI']
                      .map((b) => ChoiceChip(
                            label: Text(b),
                            selected: bank == b,
                            onSelected: (_) => setSheet(() => bank = b),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              IonPrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != true) return;
    try {
      final r = await api.dio.post<Map<String, dynamic>>(
        '/portal/invoices/$invoiceId/pay',
        data: {'method': method, 'bank': bank},
      );
      final d = r.data ?? const <String, dynamic>{};
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            method == 'manual_transfer'
                ? 'Transfer to this VA'
                : 'Complete your payment',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (d['va_number'] != null) ...[
                Text(
                  '${d['bank']} VA',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: IonColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  (d['va_number'] as String?) ?? '',
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    color: IonColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Amount: Rp ${(d['amount'] as num?)?.toStringAsFixed(0) ?? '—'}',
                style: const TextStyle(fontSize: 13, color: IonColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                'Expires: ${d['expires_at']}',
                style:
                    const TextStyle(fontSize: 11, color: IonColors.inkMuted),
              ),
              if (d['checkout_url'] != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Or pay online: ${d['checkout_url']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: IonColors.ion600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      onPaid();
    } on DioException catch (e) {
      if (!context.mounted) return;
      final body = e.response?.data;
      String msg = e.message ?? 'Payment failed';
      if (body is Map && body['error'] is Map) {
        msg = (body['error']['message'] as String?) ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }
  }
}

Widget _empty(String text, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: IonColors.inkMuted),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, color: IonColors.ink),
          ),
        ],
      ),
    );

// =============================================================================
// Support tab
// =============================================================================

class _SupportTab extends StatelessWidget {
  const _SupportTab({required this.items, required this.onCreated});
  final List<dynamic> items;
  final VoidCallback onCreated;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Support',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: IonColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            IonPrimaryButton(
              label: 'New ticket',
              icon: Icons.add_rounded,
              onPressed: () => GoRouter.of(context).push('/tickets/new').then((_) => onCreated()),
              compact: true,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${items.length} ticket${items.length == 1 ? "" : "s"} on file',
          style: const TextStyle(fontSize: 13, color: IonColors.inkMuted),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          _empty('No tickets yet', Icons.support_agent_outlined)
        else
          for (final t in items.cast<Map<String, dynamic>>()) ...[
            _TicketCard(ticket: t),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final Map<String, dynamic> ticket;
  @override
  Widget build(BuildContext context) {
    // Wave 26 — migrated to IonListCard. Status pill uses
    // IonStatusPill tone enum so the colors line up with the rest of
    // the app's status vocabulary.
    final status = ticket['status'] as String? ?? 'open';
    final opened = DateTime.tryParse(ticket['created_at'] as String? ?? '');
    final ticketNum = ticket['ticket_number'] as String? ?? '';
    return IonListCard(
      leading: const IonLeadingIcon(
        icon: Icons.support_agent_outlined,
        tint: IonColors.indigo500,
      ),
      title: ticket['summary'] as String? ?? '',
      subtitle: ticketNum.isEmpty ? null : ticketNum,
      meta: opened != null
          ? [DateFormat('MMM d, h:mm a').format(opened.toLocal())]
          : const [],
      trailing: IonStatusPill(
        label: status.replaceAll('_', ' '),
        tone: _tone(status),
        dense: true,
      ),
      onTap: () => GoRouter.of(context).push('/tickets/${ticket['id']}'),
    );
  }

  IonStatusTone _tone(String s) {
    switch (s) {
      case 'resolved':
      case 'closed':
        return IonStatusTone.success;
      case 'in_progress':
        return IonStatusTone.info;
      case 'pending_customer':
        return IonStatusTone.warning;
      default:
        return IonStatusTone.info;
    }
  }
}

// =============================================================================
// Account tab
// =============================================================================

class _AccountTab extends StatelessWidget {
  const _AccountTab({required this.me, required this.api});
  final Map<String, dynamic>? me;
  final PortalAuthApi api;
  @override
  Widget build(BuildContext context) {
    final name = (me?['full_name'] as String?) ?? 'Customer';
    final initials = _initials(name);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: IonForm.cardShadow,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: IonColors.ion700,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: IonColors.ink,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            (me?['customer_number'] as String?) ?? '',
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: IonColors.inkMuted,
            ),
          ),
        ),
        const SizedBox(height: 20),
        IonSection(
          title: 'Contact',
          child: Column(
            children: [
              IonInfoRow(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: (me?['email'] as String?)?.isEmpty ?? true
                    ? '—'
                    : me!['email'] as String,
              ),
              IonInfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: (me?['phone'] as String?) ?? '—',
              ),
              IonInfoRow(
                icon: Icons.place_outlined,
                label: 'Address',
                value: (me?['address'] as String?) ?? '—',
              ),
            ],
          ),
        ),
        IonSection(
          title: 'Account status',
          child: IonInfoRow(
            icon: Icons.verified_outlined,
            label: 'Status',
            value: ((me?['status'] as String?) ?? 'unknown').toUpperCase(),
          ),
        ),
        IonSection(
          title: 'Identity verification',
          child: _KTPReuploadTile(api: api),
        ),
        // Wave 24 — appearance preference. The segmented control is
        // wired to the global themeMode notifier; choosing Light/Dark
        // takes effect instantly across the app and survives restart
        // via SharedPreferences (loaded at boot in main.dart).
        IonSection(
          title: 'Appearance',
          child: const _ThemeModePicker(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: IonSecondaryButton(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            onPressed: () async {
              await api.logout();
              if (!context.mounted) return;
              GoRouter.of(context).go('/login');
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: IonSecondaryButton(
            label: 'Terminate service',
            icon: Icons.power_settings_new_rounded,
            destructive: true,
            onPressed: () => GoRouter.of(context).push('/account/terminate'),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final words = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }
}

// =============================================================================
// Bottom nav
// =============================================================================

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.onChanged,
    required this.unpaidCount,
    required this.openTickets,
  });
  final int index;
  final ValueChanged<int> onChanged;
  final int unpaidCount;
  final int openTickets;

  @override
  Widget build(BuildContext context) {
    final tabs = <_Tab>[
      const _Tab(icon: Icons.home_outlined, active: Icons.home, label: 'Home'),
      const _Tab(icon: Icons.wifi_rounded, active: Icons.wifi_rounded, label: 'Services'),
      _Tab(icon: Icons.receipt_long_outlined, active: Icons.receipt_long, label: 'Bills', badge: unpaidCount),
      _Tab(icon: Icons.support_agent_outlined, active: Icons.support_agent, label: 'Support', badge: openTickets),
      const _Tab(icon: Icons.person_outline_rounded, active: Icons.person, label: 'Account'),
    ];
    // ION floating bottom-nav — rounded white capsule on the page
    // background, soft premium shadow, hairline border. Mirrors the
    // medical/task-app references.
    return Container(
      color: IonForm.pageBg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            decoration: BoxDecoration(
              color: IonColors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: IonColors.separator, width: 1),
              boxShadow: IonForm.floatShadow,
            ),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _TabItem(
                      tab: tabs[i],
                      selected: index == i,
                      onTap: () => onChanged(i),
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

class _Tab {
  const _Tab({required this.icon, required this.active, required this.label, this.badge});
  final IconData icon;
  final IconData active;
  final String label;
  final int? badge;
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected, required this.onTap});
  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    // ION floating-nav item. Selected = ion-50 capsule with icon +
    // label inline (the medical-reference look). Unselected = just
    // the icon in muted gray. Badge is a small red pill anchored
    // top-right of the icon.
    final color = selected ? IonColors.ion500 : IonColors.inkMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 44,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: EdgeInsets.symmetric(horizontal: selected ? 14 : 8),
          decoration: BoxDecoration(
            color: selected ? IonColors.ion50 : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? tab.active : tab.icon,
                    size: 22,
                    color: color,
                  ),
                  if ((tab.badge ?? 0) > 0)
                    Positioned(
                      right: -6,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: IonColors.danger,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: selected
                                  ? IonColors.ion50
                                  : IonColors.surface,
                              width: 1.5),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '${tab.badge}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9,
                            height: 1.2,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    tab.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: IonColors.ion500,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KTPReuploadTile extends StatefulWidget {
  const _KTPReuploadTile({required this.api});
  final PortalAuthApi api;
  @override
  State<_KTPReuploadTile> createState() => _KTPReuploadTileState();
}

class _KTPReuploadTileState extends State<_KTPReuploadTile> {
  bool _busy = false;
  String? _last;
  String? _error;

  Future<void> _upload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (x == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final bytes = await File(x.path).readAsBytes();
      // 1. Upload bytes to the storage endpoint.
      final upload = await widget.api.dio.post<Map<String, dynamic>>(
        '/api/uploads/photos',
        data: Stream<List<int>>.fromIterable([bytes]),
        options: Options(
          method: 'POST',
          contentType: 'image/jpeg',
          headers: {'Content-Length': bytes.length.toString()},
        ),
      );
      final url = upload.data?['object_url'] as String?;
      if (url == null) throw 'upload returned no url';
      // 2. POST /portal/ktp → drops a CS ticket for verification.
      final ktp = await widget.api.dio.post<Map<String, dynamic>>(
        '/portal/ktp',
        data: {'object_url': url, 'notes': 'Self-service re-verification'},
      );
      final ticket = ktp.data?['ticket_number'] as String? ?? '—';
      if (mounted) {
        setState(() => _last = ticket);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket $ticket created. CS will verify within 1 business day.')),
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Re-upload your KTP if it expired or your info has changed. '
          'A CS agent will verify it manually within 1 business day.',
          style: TextStyle(fontSize: 12, color: IonColors.inkMuted, height: 1.4),
        ),
        const SizedBox(height: 10),
        if (_last != null)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: Color(0xFF15803D), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Submitted as $_last',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF14532D),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          IonErrorBanner(message: _error!),
        ],
        const SizedBox(height: 10),
        IonSecondaryButton(
          label: _busy ? 'Uploading…' : 'Verify identity',
          icon: Icons.badge_outlined,
          onPressed: _busy ? null : _upload,
        ),
      ],
    );
  }
}

/// Wave 23 — tiny stat tile used inside the customer-home bento.
/// Compact (no animation, no icon disc) to fit the half-height
/// secondary/tertiary slot of [IonBentoGrid].
class _MiniStatTile extends StatelessWidget {
  const _MiniStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.suffix,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final String? suffix;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: IonColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: IonColors.separator, width: 1),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: accent, size: 18),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Wave 24 — gradient the numeric value, fall back to
                  // flat ink for non-numeric strings ("Live"/"Off"/"—")
                  // so the brand colour shines on real metrics only.
                  Flexible(
                    child: value.contains(RegExp(r'^[0-9]'))
                        ? IonGradientText(
                            text: value,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          )
                        : Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: IonColors.ink,
                              letterSpacing: -0.5,
                              height: 1.0,
                            ),
                          ),
                  ),
                  if (suffix != null) ...[
                    const SizedBox(width: 3),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        suffix!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: IonColors.inkMuted,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: IonColors.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Wave 23 — recent-invoice mini card used inside the home carousel.
/// 240×160 rounded card with invoice number, due date, amount, and
/// a status pill. Tapping jumps to the Bills tab.
class _RecentInvoiceCard extends StatelessWidget {
  const _RecentInvoiceCard({required this.invoice, required this.onTap});
  final Map<String, dynamic> invoice;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = invoice['status'] as String? ?? 'unknown';
    final paid = status == 'paid';
    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    final issued = DateTime.tryParse(invoice['issued_at'] as String? ?? '');
    return IonPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          color: IonColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: IonColors.separator, width: 1),
          boxShadow: IonForm.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: paid
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    paid
                        ? Icons.check_circle_outline
                        : Icons.receipt_long_outlined,
                    color: paid
                        ? const Color(0xFF15803D)
                        : const Color(0xFFB91C1C),
                    size: 18,
                  ),
                ),
                const Spacer(),
                IonStatusPill(
                  label: status,
                  tone: paid
                      ? IonStatusTone.success
                      : (status == 'overdue'
                          ? IonStatusTone.danger
                          : IonStatusTone.warning),
                  dense: true,
                ),
              ],
            ),
            const Spacer(),
            Text(
              invoice['invoice_number'] as String? ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: IonColors.inkMuted,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    total.toStringAsFixed(0),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: IonColors.ink,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'IDR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: IonColors.inkMuted,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              issued == null
                  ? 'Issued recently'
                  : 'Issued ${DateFormat('MMM d').format(issued.toLocal())}',
              style: const TextStyle(
                fontSize: 11,
                color: IonColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wave 24 — segmented Light/Dark/System picker bound to the global
/// `themeMode` notifier. Lives inside profile pages — flipping changes
/// theme app-wide instantly + persists to SharedPreferences via
/// `setThemeMode`. A ValueListenableBuilder makes the active chip
/// follow external changes (e.g. system theme switch).
class _ThemeModePicker extends StatelessWidget {
  const _ThemeModePicker();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeMode,
        builder: (context, mode, _) => Row(
          children: [
            Expanded(
              child: _ThemeChip(
                label: 'Light',
                icon: Icons.light_mode_rounded,
                active: mode == ThemeMode.light,
                onTap: () => setThemeMode(ThemeMode.light),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ThemeChip(
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
                active: mode == ThemeMode.dark,
                onTap: () => setThemeMode(ThemeMode.dark),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ThemeChip(
                label: 'System',
                icon: Icons.brightness_auto_rounded,
                active: mode == ThemeMode.system,
                onTap: () => setThemeMode(ThemeMode.system),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: active ? IonColors.inkBlack : IonColors.chipBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: active ? Colors.white : IonColors.inkSoft,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : IonColors.inkSoft,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
