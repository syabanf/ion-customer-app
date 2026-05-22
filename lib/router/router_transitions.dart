import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Tech-app page transitions. Two flavours are exported:
///
///   - `slidePage` — slide-from-right + fade-in. Used for detail
///     screens (WO detail, profile, BAST, etc.) so the navigation
///     feels directional.
///   - `modalPage` — slide-up from the bottom with a slight scale,
///     for forms that act like sheets (reschedule, resolution log,
///     checklist response, QR scan).
///
/// Both pop the same way they came in so back-swipe motion mirrors
/// the entry.
CustomTransitionPage<T> slidePage<T>({
  required Widget child,
  LocalKey? key,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondary, child) {
      // Curve the linear animation into something with a bit of
      // settle at the end — iOS-style ease-out cubic.
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      // Outgoing page slides slightly left while the new page slides
      // in from the right. Adds the parallax effect that makes the
      // transition feel like depth.
      final secondaryCurve = CurvedAnimation(
        parent: secondary,
        curve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: secondaryCurve.drive(
          Tween(begin: Offset.zero, end: const Offset(-0.18, 0)),
        ),
        child: SlideTransition(
          position: curve.drive(
            Tween(begin: const Offset(1, 0), end: Offset.zero),
          ),
          child: FadeTransition(
            opacity: curve,
            child: child,
          ),
        ),
      );
    },
  );
}

CustomTransitionPage<T> modalPage<T>({
  required Widget child,
  LocalKey? key,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondary, child) {
      final curve = CurvedAnimation(
        parent: animation,
        // Sheet entrance — slow start, soft finish. iOS modal feel.
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: curve.drive(
          Tween(begin: const Offset(0, 1), end: Offset.zero),
        ),
        child: FadeTransition(
          // Don't fade all the way to 0 — keeps the sheet readable
          // mid-transition. Start at 0.4 instead of 0.
          opacity: curve.drive(Tween(begin: 0.4, end: 1.0)),
          child: child,
        ),
      );
    },
  );
}

/// `instantPage` — used for the initial route and any place we want
/// no transition (e.g. auth-guard redirects). Keeps the GoRoute API
/// uniform without forcing a default transition.
CustomTransitionPage<T> instantPage<T>({
  required Widget child,
  LocalKey? key,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    transitionsBuilder: (_, __, ___, child) => child,
  );
}

/// Wave 20 — cross-fade page. Use for sibling pages where directional
/// motion would feel arbitrary (e.g. tab-style navigation outside the
/// home shell). 240 ms ease-out — long enough to register, short
/// enough to feel snappy.
CustomTransitionPage<T> fadePage<T>({
  required Widget child,
  LocalKey? key,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, secondary, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: curve, child: child);
    },
  );
}

/// Wave 20 — zoom-from-tap page. Use for a hero-card → detail
/// transition (a list row that expands into its detail). The new page
/// fades in while scaling up subtly from 0.96 → 1.0 — feels like
/// "lifting" the card off the page.
CustomTransitionPage<T> zoomPage<T>({
  required Widget child,
  LocalKey? key,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondary, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curve,
        child: ScaleTransition(
          scale: curve.drive(Tween(begin: 0.96, end: 1.0)),
          child: child,
        ),
      );
    },
  );
}
