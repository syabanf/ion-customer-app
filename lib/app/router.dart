import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ion_customer_app/shared.dart';
import '../features/account/terminate_page.dart';
import '../features/auth/login_page.dart';
import '../features/auth/portal_auth.dart';
import '../features/home/home_shell.dart';
import '../features/notifications/notifications_page.dart';
import '../features/onboarding/coverage_check_page.dart';
import '../features/onboarding/self_order_page.dart';
import '../features/services/buy_addon_page.dart';
import '../features/services/change_plan_page.dart';
import '../features/services/relocation_page.dart';
import '../features/services/tech_tracker_page.dart';
import '../features/support/new_ticket_page.dart';
import '../features/support/ticket_detail_page.dart';

/// CustomerRouter — declarative route table for the customer app.
///
/// Auth-gating uses a simple ChangeNotifier (PortalAuthState) so
/// redirects fire on sign-in / sign-out without the staff AuthBloc
/// involvement (the customer app has its own JWT stream).
class CustomerRouter {
  CustomerRouter({required this.api, required this.authState});
  final PortalAuthApi api;
  final PortalAuthState authState;

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: authState,
    errorBuilder: (context, state) => _RouteFallback(uri: state.uri.toString()),
    redirect: (context, state) {
      final goingToLogin = state.matchedLocation == '/login';
      final goingToCoverage = state.matchedLocation == '/coverage-check';
      final goingToSelfOrder = state.matchedLocation == '/self-order';
      // /coverage-check + /self-order are publicly accessible —
      // prospective customers without a portal session need them
      // as the self-order entry point.
      if (!authState.isAuthed &&
          !goingToLogin &&
          !goingToCoverage &&
          !goingToSelfOrder) {
        return '/login';
      }
      if (authState.isAuthed && goingToLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (_, __) => instantPage(
          child: CustomerLoginPage(
            api: api,
            onSignedIn: () => authState.isAuthed = true,
          ),
        ),
      ),
      GoRoute(
        path: '/coverage-check',
        pageBuilder: (_, __) => slidePage(child: const CoverageCheckPage()),
      ),
      GoRoute(
        path: '/self-order',
        pageBuilder: (_, s) => slidePage(
          child: SelfOrderPage(
            extra: (s.extra is Map<String, dynamic>
                ? s.extra as Map<String, dynamic>
                : const {}),
          ),
        ),
      ),
      GoRoute(
        path: '/',
        pageBuilder: (_, __) => instantPage(child: CustomerHomeShell(api: api)),
      ),
      GoRoute(
        path: '/tickets/new',
        pageBuilder: (_, __) => modalPage(child: NewTicketPage(api: api)),
      ),
      GoRoute(
        path: '/tickets/:id',
        pageBuilder: (_, s) => slidePage(
          child: TicketDetailPage(api: api, ticketId: s.pathParameters['id']!),
        ),
      ),

      // Self-service flows.
      GoRoute(
        path: '/services/change-plan',
        pageBuilder: (_, s) {
          final currentPlan =
              s.extra is Map<String, dynamic> ? s.extra as Map<String, dynamic> : null;
          return modalPage(
            child: ChangePlanPage(api: api, currentPlan: currentPlan),
          );
        },
      ),
      GoRoute(
        path: '/services/buy-addon',
        pageBuilder: (_, __) => modalPage(child: BuyAddonPage(api: api)),
      ),
      GoRoute(
        path: '/services/relocation',
        pageBuilder: (_, __) => modalPage(child: RelocationRequestPage(api: api)),
      ),
      // Wave 67 (C1) — live tech tracker. Customer-facing surface
      // for "where's my technician?" during an active visit.
      GoRoute(
        path: '/services/track',
        pageBuilder: (_, __) => slidePage(child: TechTrackerPage(api: api)),
      ),
      GoRoute(
        path: '/account/terminate',
        pageBuilder: (_, __) => modalPage(child: TerminateRequestPage(api: api)),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, __) =>
            slidePage(child: NotificationsPage(api: api)),
      ),

      // ----------------------------------------------------------------
      // Wave 91 (UX consolidation) — legacy + alias redirects.
      //
      // We never want to drop an existing route, because customers
      // receive push notifications, WhatsApp deep-links, and email
      // links that bake the URL into the payload. Renaming a route
      // would silently 404 every old notification in the wild.
      //
      // Redirects below cover three classes of incoming URL:
      //
      //  1. `/support/tickets/:id` (and `/support/tickets/new`) —
      //     an older naming convention used in earlier waves and
      //     still referenced by some push templates. Canonical is
      //     `/tickets/:id`.
      //  2. `/services/terminate` — termination is conceptually a
      //     service-lifecycle action; the destination still lives at
      //     `/account/terminate` (Account tab owns destructive surface
      //     area) but the symmetric "services" URL also works.
      //  3. `/account/notifications` — some early notification deep
      //     links nested the inbox under Account.
      // ----------------------------------------------------------------
      GoRoute(
        path: '/support/tickets/new',
        redirect: (_, __) => '/tickets/new',
      ),
      GoRoute(
        path: '/support/tickets/:id',
        redirect: (_, s) => '/tickets/${s.pathParameters['id']}',
      ),
      GoRoute(
        path: '/services/terminate',
        redirect: (_, __) => '/account/terminate',
      ),
      GoRoute(
        path: '/account/notifications',
        redirect: (_, __) => '/notifications',
      ),
    ],
  );
}

/// Friendly fallback when GoRouter receives a URL that doesn't match
/// any declared route (out-of-date deep link, typo, etc.).
class _RouteFallback extends StatelessWidget {
  const _RouteFallback({required this.uri});
  final String uri;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IonColors.pageBg,
      appBar: const IonAppBar(title: 'Page not found'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.travel_explore_rounded,
                  size: 48, color: IonColors.inkMuted),
              const SizedBox(height: 14),
              const Text(
                'We couldn’t find that page',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: IonColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'No route matches "$uri". The link may be out of date.',
                style: const TextStyle(
                  fontSize: 13,
                  color: IonColors.inkMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              IonPrimaryButton(
                label: 'Back to home',
                icon: Icons.home_outlined,
                onPressed: () => GoRouter.of(context).go('/'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
