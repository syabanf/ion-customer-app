// Notification-kind → visual styling map.
//
// Extracted from notifications_page.dart so the tests can pin the
// kind → icon/colour mapping. Adding a new kind to the backend
// (kinds enum in openapi.yaml + crm.customer_notifications.kind)
// needs a matching case here or the badge falls back to the
// generic bell.

import 'package:flutter/material.dart';
import 'package:ion_customer_app/shared.dart';

/// Pick the icon shown in the notification card's avatar slot.
IconData kindIcon(String kind) {
  switch (kind) {
    case 'ticket_reply':
      return Icons.support_agent_rounded;
    case 'bast_scheduled':
      return Icons.event_rounded;
    case 'payment_succeeded':
      return Icons.payments_rounded;
    case 'plan_change':
      return Icons.upgrade_rounded;
    case 'sla_breach':
      return Icons.warning_amber_rounded;
    default:
      return Icons.notifications_active_rounded;
  }
}

/// Foreground (icon) colour for the kind. Defaults to ION blue.
Color kindFg(String kind) {
  switch (kind) {
    case 'payment_succeeded':
      return const Color(0xFF15803D); // green-700
    case 'sla_breach':
      return const Color(0xFFB91C1C); // red-700
    default:
      return IonColors.ion600;
  }
}

/// Background tint for the avatar tile.
Color kindBg(String kind) {
  switch (kind) {
    case 'payment_succeeded':
      return const Color(0xFFDCFCE7); // green-100
    case 'sla_breach':
      return const Color(0xFFFEE2E2); // red-100
    default:
      return IonColors.ion100;
  }
}
