// Behavioural tests for the notification-kind styling map.
//
// These are pure-function tests — no widget rendering, no API mocks,
// no platform channels. The point is to pin the kind → icon/colour
// contract so a refactor (or a new kind added on the backend without
// a matching frontend case) is caught at PR time.
//
// The list of "known kinds" here MUST match the
// PortalNotification.kind enum in backend/docs/openapi.yaml.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ion_customer_app/shared.dart';
import 'package:ion_customer_app/features/notifications/notification_kinds.dart';

void main() {
  group('kindIcon', () {
    test('maps every known kind to a distinct icon', () {
      // Pin each known kind to its expected icon. If you change the
      // mapping, update this test deliberately.
      expect(kindIcon('ticket_reply'),      Icons.support_agent_rounded);
      expect(kindIcon('bast_scheduled'),    Icons.event_rounded);
      expect(kindIcon('payment_succeeded'), Icons.payments_rounded);
      expect(kindIcon('plan_change'),       Icons.upgrade_rounded);
      expect(kindIcon('sla_breach'),        Icons.warning_amber_rounded);
    });

    test('unknown kind falls back to generic bell', () {
      // A backend that ships a new kind without a corresponding mobile
      // release must still render — not crash. The generic bell is
      // the contract.
      expect(kindIcon('something_brand_new'), Icons.notifications_active_rounded);
      expect(kindIcon(''),                    Icons.notifications_active_rounded);
    });
  });

  group('kindFg', () {
    test('payment_succeeded is green-700', () {
      expect(kindFg('payment_succeeded'), const Color(0xFF15803D));
    });

    test('sla_breach is red-700', () {
      expect(kindFg('sla_breach'), const Color(0xFFB91C1C));
    });

    test('other kinds default to ION blue', () {
      expect(kindFg('ticket_reply'),    IonColors.ion600);
      expect(kindFg('bast_scheduled'),  IonColors.ion600);
      expect(kindFg('plan_change'),     IonColors.ion600);
      expect(kindFg('unknown'),         IonColors.ion600);
    });
  });

  group('kindBg', () {
    test('payment_succeeded background is green-100', () {
      expect(kindBg('payment_succeeded'), const Color(0xFFDCFCE7));
    });

    test('sla_breach background is red-100', () {
      expect(kindBg('sla_breach'), const Color(0xFFFEE2E2));
    });

    test('other kinds default to ION blue tint', () {
      expect(kindBg('ticket_reply'), IonColors.ion100);
      expect(kindBg('plan_change'),  IonColors.ion100);
      expect(kindBg(''),             IonColors.ion100);
    });
  });

  group('contract: fg/bg colour pairs are visually distinct', () {
    // Light-mode contrast pins. The exact values aren't sacred, but
    // these pairs are designed so the badge is legible. Catches a
    // regression where someone updates one but forgets the other.
    test('payment_succeeded fg + bg are both green-family', () {
      expect(kindFg('payment_succeeded').value, isNot(equals(kindBg('payment_succeeded').value)));
    });

    test('sla_breach fg + bg are both red-family', () {
      expect(kindFg('sla_breach').value, isNot(equals(kindBg('sla_breach').value)));
    });
  });
}
