# ion-customer-app

The customer-facing portal for the ION Network ISP. Customers log in
via OTP (their customer number + last-4 of phone), view their service
status, pay invoices, file tickets, request plan changes / relocation /
termination, and follow tech location during an active install.

Part of a 5-repo system:

| Repo | What it is |
|---|---|
| [ion-backend](https://github.com/syabanf/ion-backend) | Go services, migrations, e2e suite |
| [ion-frontend](https://github.com/syabanf/ion-frontend) | Next.js admin dashboard |
| **ion-customer-app** (this) | Flutter customer portal |
| [ion-sales-app](https://github.com/syabanf/ion-sales-app) | Flutter sales-rep app |
| [ion-tech-app](https://github.com/syabanf/ion-tech-app) | Flutter technician app |

---

## Tech stack

| Layer | Choice | Notes |
|---|---|---|
| Framework | **Flutter** (stable channel) | Single codebase → web, Android, iOS |
| Language | **Dart 3** | Sound null safety, sealed classes for state |
| Routing | **go_router** | Declarative routes, deep-link friendly |
| HTTP | **Dio** | Interceptors for auth header + retry |
| Secure storage | **flutter_secure_storage** | Keychain / Keystore for OTP refresh token |
| Auth | Customer OTP (portal flow, distinct from staff JWT) | Token has `role='customer'`; server-side `claims.UserID = customer_id` |
| Push | **firebase_messaging** (gated by `ION_PUSH_ENABLED`) | Bootstrap is a no-op until the FCM service-account JSON lands |
| Tests | `flutter_test` | Widget + unit tests in `test/` |

---

## Quick start

### Prerequisites

- Flutter SDK 3.x (stable channel)
- A running ION backend on `http://localhost:8080` (see
  [ion-backend](https://github.com/syabanf/ion-backend))
- For mobile builds: Xcode (iOS) + Android Studio (Android)

### Run on web (the canonical dev surface)

```bash
flutter pub get
flutter run -d chrome --web-port=9100 \
  --dart-define=API_URL=http://localhost:8080
```

Opens at `http://localhost:9100`. The portal-OTP login flow needs:

- `CRM_PORTAL_OTP_DEMO=true` set on `crm-svc` so the OTP comes back
  inline in the response (no real WhatsApp/SMS needed for local dev)
- A customer already in `crm.customers` — easiest path is to use
  ion-backend's broadband happy-path E2E (or seed-demo + run the
  full lead-to-customer flow)

### Run on Android / iOS

```bash
flutter pub get
flutter run                          # picks up any connected device/emulator
# Or:
flutter run -d "iPhone 15 Pro"       # explicit device id
```

### Build for production

```bash
flutter build web --release          # build/web/
flutter build apk --release          # build/app/outputs/flutter-apk/
flutter build ios --release          # build/ios/ (then archive in Xcode)
```

### Enable push notifications (when credentials land)

```bash
flutter run -d chrome \
  --dart-define=API_URL=https://api.your-domain.com \
  --dart-define=ION_PUSH_ENABLED=true
```

Requires `google-services.json` (Android) + `GoogleService-Info.plist`
(iOS) in the standard locations. The bootstrap in
`lib/push/push_notifier.dart` is a no-op until `ION_PUSH_ENABLED=true`.

---

## Project structure

```
lib/
├── main.dart                   # Entry point — wires PortalAuthApi + state
├── shared.dart                 # Barrel export (theme, DI, primitives)
├── app/
│   ├── customer_app.dart       # Root MaterialApp.router
│   └── router.dart             # go_router route table
├── core/
│   └── theme/app_theme.dart    # ION-brand tokens + typography
├── features/
│   ├── auth/
│   │   ├── portal_auth.dart    # PortalAuthApi + PortalAuthState
│   │   └── login_page.dart     # Customer-number + phone-last4 + OTP
│   ├── home/                   # Dashboard tabs, live-tracker, bento grid
│   ├── invoices/               # List + detail + "Pay now"
│   ├── tickets/                # Inbox, detail, CSAT
│   ├── notifications/          # Inbox + mark-read
│   ├── plan_change/            # Upgrade/downgrade request
│   ├── relocation/             # Address change request
│   ├── termination/            # Voluntary termination request
│   └── ktp/                    # KTP re-upload + Maps deep-link
├── gps/                        # GPS streamer (during install)
├── push/
│   └── push_notifier.dart      # FCM bootstrap (kill-switched)
├── portal/portal_link.dart     # Deep-link parser for /portal/* URLs
├── uploads/uploads_gateway.dart
└── widgets/                    # Cross-feature UI primitives
    ├── ion_app_bar.dart
    ├── ion_form.dart
    └── ion_anim.dart

test/
└── notification_kinds_test.dart
└── login_page_widget_test.dart
```

---

## Authentication flow

1. Customer enters their **customer number** + **last 4 digits of
   phone** on the login screen
2. App POSTs `/api/portal/auth/otp-request` — server matches the
   credentials, mints a 6-digit OTP, stores its bcrypt hash
3. In demo mode (`CRM_PORTAL_OTP_DEMO=true`) the OTP comes back in the
   response so we can complete the test without WhatsApp wired
4. Customer enters the OTP; app POSTs `/api/portal/auth/otp-verify`
5. Server returns `{access_token, refresh_token, expires_at}` — both
   tokens go into `flutter_secure_storage`
6. Subsequent requests carry the access token via a Dio interceptor;
   401 triggers single-flight refresh

The customer JWT has `role='customer'` + `UserID=customer_id`. The
backend uses this to scope every `/portal/*` query: "this customer's
tickets" never has to take an `?id=` filter — the claim IS the filter.

---

## Testing

```bash
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
```

Coverage: notification-kind contract pin (5 known kinds → icon/colour
mapping), login-page widget smoke (renders fields without throwing).

The full **portal data-isolation** E2E lives in `ion-backend`'s
`test/e2e/portal_data_isolation_e2e_test.go` — it proves that one
customer can't read another customer's tickets via the portal.

---

## Theming + design system

- ION brand tokens in `lib/core/theme/app_theme.dart`
- Dark mode via `ThemeMode` `ValueListenable`; toggle on profile page
- Magazine-tier primitives in `lib/widgets/` — bento grid, photo card,
  glass card, gradient text, status pill, heartbeat indicator
- Status pills humanize backend enums (`pending_install` →
  "Pending install") via a shared `humanize()` helper

---

## Where this fits

```
                    ┌────────────────────┐
  Customer's phone  │  ion-customer-app  │
                    └─────────┬──────────┘
                              │ /portal/* via gateway
                              ▼
                    ┌────────────────────┐
                    │     api-gateway    │
                    │      :8080         │
                    └─────────┬──────────┘
                              │ → crm-svc
                              ▼
                    PostgreSQL (crm.customers,
                    crm.customer_portal_otp,
                    crm.customer_notifications)
```

Distinct from the staff apps (sales/tech) which use email + password
on `/api/identity/auth/login`. The two auth systems never overlap —
a customer JWT can't hit `/api/crm/leads`, and a staff JWT can't hit
`/portal/tickets/{id}`.

---

## Browser support

Modern Chromium / Safari / Firefox / Edge — Flutter web renders to
canvas + dom, works on any browser with WebGL2.
