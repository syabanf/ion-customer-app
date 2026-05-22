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
      GoRoute(
        path: '/account/terminate',
        pageBuilder: (_, __) => modalPage(child: TerminateRequestPage(api: api)),
      ),
      GoRoute(
        path: '/notifications',
        pageBuilder: (_, __) =>
            slidePage(child: NotificationsPage(api: api)),
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
