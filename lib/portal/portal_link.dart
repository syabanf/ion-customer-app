// Helpers for deep-linking into the public customer portal.
//
// The portal is a web flow served by the same backend (`/portal/*`),
// not a native mobile surface. Both the Sales App and the Tech App
// occasionally need to "open the portal for the customer" — e.g. a
// sales rep who can't process a same-day termination, or a tech who's
// on-site and finds a billing dispute. They tap "Customer portal" →
// the OS browser opens the live page → the rep hands the device to
// the customer.
//
// The base URL comes from the same --dart-define knob as the API
// base, with /portal appended. The portal pages route themselves once
// loaded.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _apiBase = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:8080',
);

/// Opens the public portal landing page in the OS browser. Returns
/// false when the launcher refuses (no browser, sandboxed env).
Future<bool> openCustomerPortal({String path = '/portal'}) async {
  // The same API_URL serves both /api/* and the public /portal/*
  // routes (the gateway proxies /portal/* to the web frontend in
  // production; local dev runs Next.js on the same origin).
  final uri = Uri.parse('$_apiBase$path');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// A pre-styled `ListTile` ready to drop into a drawer or settings
/// page. Wires `onTap` to `openCustomerPortal`; logs the failure mode
/// via a SnackBar when present in the widget tree.
class CustomerPortalTile extends StatelessWidget {
  const CustomerPortalTile({super.key, this.subtitle});

  /// Optional subtitle override — defaults to the generic "open the
  /// public portal" copy.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.open_in_browser),
      title: const Text('Customer portal'),
      subtitle: Text(subtitle ?? 'Self-service for cancellations etc.'),
      onTap: () async {
        final ok = await openCustomerPortal();
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Couldn't open the portal in a browser")),
          );
        }
      },
    );
  }
}
