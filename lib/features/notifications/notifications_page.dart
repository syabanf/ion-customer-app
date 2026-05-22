import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ion_customer_app/shared.dart';
import '../auth/portal_auth.dart';
import 'notification_kinds.dart';

/// NotificationsPage — customer-facing in-app inbox.
///
/// Pulls /portal/notifications and shows unread first. Tapping a row
/// marks it read and follows `deep_link` if present.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.api});
  final PortalAuthApi api;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with WidgetsBindingObserver {
  late Future<_Bundle> _future;
  Timer? _refreshTimer;

  /// Auto-refresh cadence. 30s is the same rhythm the tech app's
  /// priority-insertion poll uses — fast enough to feel "live" without
  /// hammering the API. Once FCM lands the timer can drop to 2-3 min
  /// (timer becomes the fallback for missed pushes).
  static const Duration _refreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _future = _load();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      // Skip the tick if a fetch is already in flight; the next tick
      // will catch up. We don't bother with cancellation because the
      // gateway responds in well under 30s.
      if (!mounted) return;
      setState(() => _future = _load());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume from background → refresh immediately so the inbox isn't
    // stale by ~minutes. The 30s timer continues its normal cadence
    // afterwards.
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _future = _load());
    }
  }

  Future<_Bundle> _load() async {
    final r = await widget.api.dio.get<Map<String, dynamic>>('/portal/notifications');
    final data = r.data ?? const {};
    return _Bundle(
      items: ((data['items'] as List<dynamic>?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      unreadCount: (data['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _markRead(String id) async {
    try {
      await widget.api.dio.post('/portal/notifications/$id/read');
    } on DioException {
      /* swallow — UI reload will reflect true state next time */
    }
    setState(() => _future = _load());
  }

  Future<void> _markAllRead() async {
    try {
      await widget.api.dio.post('/portal/notifications/mark-all-read');
    } on DioException {/* ignore */}
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonForm.pageBg,
      appBar: IonAppBar(
        title: 'Notifications',
        actions: [
          IonAppBarAction(
            icon: Icons.done_all_rounded,
            onTap: _markAllRead,
          ),
        ],
      ),
      body: FutureBuilder<_Bundle>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const IonListSkeleton(count: 5);
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: IonErrorBanner(message: 'Failed: ${snap.error}'),
            );
          }
          final bundle = snap.data!;
          if (bundle.items.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: const [
                IonDisplayTitle(
                  eyebrow: 'Inbox',
                  title: 'Notifications',
                  subtitle: 'Your account activity will show up here.',
                ),
                SizedBox(height: 24),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: IonEmptyState(
                    icon: Icons.notifications_none_rounded,
                    art: IonArtKind.inbox,
                    title: 'No notifications yet',
                    hint: 'We\'ll buzz you when there\'s news about your service.',
                  ),
                ),
              ],
            );
          }
          // Wave 22 — dashboard header for the inbox.
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
            children: [
              FadeSlideIn(
                child: IonDisplayTitle(
                  eyebrow: 'Inbox',
                  title: 'Notifications',
                  subtitle: bundle.unreadCount == 0
                      ? 'All caught up — nothing unread.'
                      : '${bundle.unreadCount} unread item${bundle.unreadCount == 1 ? "" : "s"} on your account.',
                ),
              ),
              const SizedBox(height: 18),
              const IonChipDivider(label: 'Recent'),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (var i = 0; i < bundle.items.length; i++) ...[
                      FadeSlideIn(
                        delay: Duration(milliseconds: 40 * i.clamp(0, 10)),
                        child: _SwipeableNotif(
                          notification: bundle.items[i],
                          // Wave 25 — swipe a still-unread row to mark
                          // it read in one gesture. We hide the swipe
                          // affordance entirely on already-read rows
                          // so it's not a redundant action.
                          canSwipe: bundle.items[i]['read_at'] == null,
                          onSwipeMarkRead: () {
                            final n = bundle.items[i];
                            final id = n['id'] as String?;
                            if (id != null) _markRead(id);
                            IonSnackbar.show(
                              context,
                              'Marked as read',
                              icon: Icons.mark_email_read_outlined,
                            );
                          },
                          child: _NotifCard(
                            notification: bundle.items[i],
                            onTap: () {
                              final n = bundle.items[i];
                              if (n['read_at'] == null) {
                                final id = n['id'] as String?;
                                if (id != null) _markRead(id);
                              }
                              final link = n['deep_link'] as String?;
                              if (link != null && link.isNotEmpty) {
                                GoRouter.of(context).push(link);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Wave 25 — Dismissible wrapper that converts a swipe-right into
/// "mark as read". Quietly bypasses Dismissible on already-read rows
/// so the gesture surface only exists when there's something to do.
/// Hosts a soft "Mark read" background tint behind the card so the
/// user sees the action label while their finger is still on screen.
class _SwipeableNotif extends StatelessWidget {
  const _SwipeableNotif({
    required this.notification,
    required this.canSwipe,
    required this.onSwipeMarkRead,
    required this.child,
  });
  final Map<String, dynamic> notification;
  final bool canSwipe;
  final VoidCallback onSwipeMarkRead;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!canSwipe) return child;
    return Dismissible(
      key: ValueKey('notif-${notification['id']}'),
      direction: DismissDirection.startToEnd,
      // We don't actually remove the row — `confirmDismiss` returns
      // false so Dismissible animates back. The mark-read fires once,
      // then the row stays put as "read" (lighter background).
      confirmDismiss: (_) async {
        onSwipeMarkRead();
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: IonColors.mint500.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.mark_email_read_outlined,
                size: 18, color: IonColors.mint500),
            SizedBox(width: 8),
            Text(
              'Mark read',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: IonColors.mint500,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
      child: child,
    );
  }
}

class _Bundle {
  _Bundle({required this.items, required this.unreadCount});
  final List<Map<String, dynamic>> items;
  final int unreadCount;
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.notification, required this.onTap});
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Wave 26 — migrated to IonListCard. Unread state surfaces in 3
    // signals that survive the migration: bold (w800) title via
    // titleStyle override, the trailing ion blue dot, and the leading
    // icon disc colored per notification kind. We drop the previous
    // ion50 row-background — relying on the trailing dot is the
    // pattern used by every modern inbox (Apple Mail, Gmail, Linear).
    final unread = notification['read_at'] == null;
    final kind = notification['kind'] as String? ?? '';
    final created =
        DateTime.tryParse(notification['created_at'] as String? ?? '');
    return IonListCard(
      leading: IonLeadingIcon(icon: kindIcon(kind), tint: kindFg(kind)),
      title: notification['title'] as String? ?? '',
      subtitle: notification['body'] as String? ?? '',
      meta: created != null
          ? [DateFormat('MMM d · h:mm a').format(created.toLocal())]
          : const [],
      trailing: unread
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: IonColors.ion500,
                shape: BoxShape.circle,
              ),
            )
          : null,
      titleStyle: unread
          ? IonText.bodyBold.copyWith(fontWeight: FontWeight.w800)
          : null,
      onTap: onTap,
    );
  }
}
