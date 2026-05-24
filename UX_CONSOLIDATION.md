# Customer App — UX Consolidation (Wave 91)

Pass conducted **2026-05-24** as part of Wave 129A. Goal: simpler IA,
no duplicated flows, every deep link still resolves.

## Header

| Metric                | Before | After |
| --------------------- | -----: | ----: |
| Routable destinations |     12 |    12 |
| Bottom-nav tabs       |      5 |     5 |
| Distinct pages (.dart under `lib/features/`) | 12 | 12 |
| GoRoutes              |     12 |    16 |
| Deep-link redirects   |      0 |     4 |
| Global-search entries |      5 |   12  |
| Bugs found            |      1 |     0 |

The customer app was already in good shape after Waves 18–44 of design
polish — most "consolidation" candidates had already been folded into
the 5-tab home shell (Home / Services / Bills / Support / Account).
This pass therefore did **not** drop or merge any pages. Instead it:

1. Fixed a navigation bug (Issue A — search hit a 404 fallback).
2. Backfilled deep-link redirects for legacy URL shapes.
3. Made every routable destination findable from global search.

Page count is intentionally unchanged. The total *reachability* improved
significantly — anything previously requiring tribal knowledge of the
URL is now discoverable through search or push deep-link.

## Acceptance

```
$ cd mobile/customer_app && flutter analyze
47 issues found. (ran in 1.3s)
```

Same 47 baseline issues as before this pass — all pre-existing
`prefer_const_constructors`, `deprecated_member_use`, and
`inference_failure_on_function_invocation` notices that pre-date Wave
129A. **Zero new issues** introduced.

---

## Audit by cluster

### 1. Bills / Invoices / Payment / Add-on
**Status: already consolidated.** No action needed.

- `_BillsTab` (home_shell.dart) is the single billing surface.
- Pay flow is an inline modal sheet within the tab (lines 1264–1465);
  no separate "Pay" page exists.
- "Buy add-on" is a separate flow because it spawns a sales/install
  pipeline (modal at `/services/buy-addon`) — different shape, kept apart.

### 2. Tickets / CSAT / Communications
**Status: already consolidated.** No action needed.

- `_SupportTab` is the ticket list.
- `/tickets/new` (modal) creates one.
- `/tickets/:id` (slide) shows the timeline + CSAT rating block
  inline when the ticket is resolved/closed.
- CSAT is **not** a separate page — it surfaces inside
  `TicketDetailPage` only when needed.

### 3. Settings / Profile / Notifications / Account
**Status: already consolidated**, with one minor backfill.

- `_AccountTab` owns profile, identity verification (KTP re-upload),
  appearance/theme picker, sign-out, and terminate.
- Notifications inbox lives at `/notifications` (separate page so
  push deep-links can hit it directly).
- Wave 91 added an `/account/notifications` legacy-redirect for
  older push payloads that nested the inbox under Account.

### 4. Live tracker / Tech status / WO update
**Status: kept as dedicated route**, surfaced via Quick Access.

- `/services/track` (TechTrackerPage) is the only tech-status surface.
- Reached from: (a) Home quick-access tile "Track tech", (b) push
  deep-link when a tech is en-route, (c) NEW: global search now lists
  it as a destination.
- Earlier comment in `_HomeTab` ("Live tech tracker (only when there's
  an active WO)") was about a hero-card that Wave 70 dropped — the
  page itself was never duplicated.

### 5. Onboarding / KTP / Survey
**Status: already consolidated.** No action needed.

- Public funnel: `/coverage-check` → `/self-order` (correct two-step
  pre-auth flow with explicit lat/lng + product picker).
- Post-auth identity surface: `_KTPReuploadTile` inlined inside the
  Account tab (line 1883+). One screen, one tap.

### 6. Plan / Speedtest / Service status
**Status: already consolidated.** No action needed.

- `_ServicesTab` aggregates current plan + add-ons + actions
  (change-plan, buy-addon, relocate) in one screen.
- No standalone "speedtest" page exists in this app; the home hero
  surfaces plan speed.

### 7. Bottom nav
**Status: at the 5-tab ceiling, well-balanced.** No action needed.

| Tab      | Owns                                                |
| -------- | --------------------------------------------------- |
| Home     | Greeting, key metrics, plan hero, quick-access grid |
| Services | Plan, add-ons, change-plan/buy-addon/relocate tiles |
| Bills    | Invoice list + inline pay                           |
| Support  | Ticket list + new-ticket CTA                        |
| Account  | Profile, KTP, theme, sign out, terminate            |

---

## Shipped (low-risk, no UX change)

### Fix 1 — Search-result ticket navigation bug
**File:** `lib/features/home/home_shell.dart` (line ~219)

Search-sheet ticket entries pushed `/support/tickets/${id}`, but the
router only declared `/tickets/:id`. Result: tapping a ticket from
search hit the `_RouteFallback` 404 screen.

**Fix:** Use the canonical `/tickets/:id`. The router additionally
accepts the legacy URL via a redirect (below) so external deep links
still work.

### Fix 2 — Legacy / alias route redirects
**File:** `lib/app/router.dart` (new GoRoutes appended to the routes
list)

Added 4 redirect-only GoRoutes so historical URL shapes never 404:

| Incoming                       | Redirects to               |
| ------------------------------ | -------------------------- |
| `/support/tickets/new`         | `/tickets/new`             |
| `/support/tickets/:id`         | `/tickets/:id`             |
| `/services/terminate`          | `/account/terminate`       |
| `/account/notifications`       | `/notifications`           |

GoRouter's `redirect:` on a GoRoute returns the destination immediately
without instantiating the page — zero-cost compatibility shim.

### Fix 3 — Search-sheet coverage
**File:** `lib/features/home/home_shell.dart` (`_openSearch`)

Search was missing 7 reachable destinations:
- Account tab (only 4 of 5 tabs were searchable)
- Change plan
- Buy add-on
- Relocate service
- Track technician
- Coverage check
- New ticket

Backfilled all 7 as `IonSearchEntry` rows tagged `PAGE` or `ACTION`.
The tab→index map was also missing `'account': 4`, so even if Account
had been listed the result would have no-opped.

---

## Proposed (needs user review — not shipped)

### Proposal P1 — Move "Terminate service" into a Danger Zone subsection
**File:** `lib/features/home/home_shell.dart` (_AccountTab, ~line 1702)

Currently:
```
Sign out  [secondary button]
Terminate service  [destructive secondary button]
```

Both are at the very bottom of the Account tab as plain buttons. The
visual weight of "terminate" is *identical* to "sign out" — same shape,
just red. Suggest wrapping termination in an `IonSection(title:
'Danger zone', …)` with a brief warning paragraph before the button.

**Why this is "propose" not "ship":** changes user-visible copy and
visual layout. Worth a designer review.

### Proposal P2 — Restore or remove the Home tab's tech-tracker hero
**File:** `lib/features/home/home_shell.dart` (~line 257)

The comment at the top of `_HomeTab`'s `build()` lists:
> 3) Live tech tracker (only when there's an active WO)

…but the actual widget tree no longer renders one. Wave 70 dropped it
during a layout refactor. Either:
- **Restore it** — when `/portal/active-wo/tech-location` reports an
  active WO, surface a hero card on Home that links to `/services/track`.
- **Remove the dead comment.**

**Why this is "propose" not "ship":** restoring requires an extra
API call from Home (cost) and design buy-in for the card; removing the
comment is trivially safe but better paired with a decision either way.

### Proposal P3 — Drop the dead `lib/auth/` and most of `lib/core/`
**Files:**
- `lib/auth/data/auth_api.dart`
- `lib/auth/data/auth_repository_impl.dart`
- `lib/auth/domain/auth_repository.dart`
- `lib/auth/domain/auth_user.dart`
- `lib/auth/presentation/bloc/*`
- `lib/auth/presentation/pages/home_page.dart`
- `lib/auth/presentation/pages/login_page.dart`
- `lib/core/api/api_client.dart`
- `lib/core/di/injector.dart`
- `lib/core/errors/api_exception.dart`
- `lib/core/storage/token_storage.dart`

These are the staff-app AuthBloc + DI scaffolding. The customer app
uses its own `PortalAuthApi` (`lib/features/auth/portal_auth.dart`),
plumbed through constructors — no Bloc, no injector. Nothing imports
`lib/auth/**` or the unused half of `lib/core/**`. They survive only
because of the project skeleton.

Removing them would:
- Shrink the bundle (~6 files of unused state-management code).
- Cut analyzer noise.

**Why this is "propose" not "ship":** out of scope for a UX pass;
deserves its own "dead code removal" PR with a careful import check
across the test suite and platform plumbing.

### Proposal P4 — Promote "Notifications" to a tab or floating chip
**Surface:** Bottom nav

Notifications currently lives behind a bell icon in the IonAppBar and
in the quick-access grid. For an ISP, unread notifications (invoice
issued, payment received, ticket update, WO scheduled, NOC alert) are
the most time-sensitive signal in the app. Two options:

- **Replace "Account" with "Inbox"** in bottom nav, move Account to a
  profile-circle in the app bar (very common pattern — Instagram,
  Twitter).
- **Add a floating un-read pill** to the bottom-nav strip that animates
  when count > 0.

**Why this is "propose" not "ship":** bottom-nav change is a core IA
decision; needs user research / A/B before shipping.

### Proposal P5 — Reduce "Services" tab actions from 3 buttons to a single CTA + drawer
**File:** `lib/features/home/home_shell.dart` (_ServicesTab, ~line 875)

Currently the Services tab has three equal-weight action tiles
(Change plan / Buy add-on / Relocate). Most users only need them
rarely — they fight the current-plan summary card for attention.
Consider a single "Modify service" CTA that opens a sheet with the
three options + "Terminate" (linking out via redirect P2 above).

**Why this is "propose" not "ship":** customer-behaviour change;
worth measuring tap-through on the current tiles first.

---

## Before / after IA

### Before
```
/
├── Home tab
│   ├── Greeting + metric tiles
│   ├── Plan hero
│   ├── Quick access (9 tiles)
│   └── Recent invoices
├── Services tab
│   ├── 3 action tiles
│   ├── Current plan card
│   └── Add-ons list
├── Bills tab
│   └── Invoice cards (with inline pay sheet)
├── Support tab
│   └── Ticket cards
└── Account tab
    ├── Profile header
    ├── Contact info
    ├── Account status
    ├── Identity verification (KTP)
    ├── Appearance
    ├── Sign out
    └── Terminate

Routes:
  /login                       (public, OTP)
  /coverage-check              (public)
  /self-order                  (public)
  /                            (home shell)
  /tickets/new                 (modal)
  /tickets/:id                 (slide)
  /services/change-plan        (modal)
  /services/buy-addon          (modal)
  /services/relocation         (modal)
  /services/track              (slide)
  /account/terminate           (modal)
  /notifications               (slide)

Global search:
  Home, Services, Bills, Support, Notifications
  + dynamic invoices / tickets
  Account NOT searchable.
  Self-service actions NOT searchable.
  Ticket result navigates to non-existent /support/tickets/:id → 404.
```

### After
```
/                              (unchanged structure — already clean)
├── Home tab                   (unchanged)
├── Services tab               (unchanged)
├── Bills tab                  (unchanged)
├── Support tab                (unchanged)
└── Account tab                (unchanged)

Routes (12 canonical + 4 redirects):
  /login                       canonical
  /coverage-check              canonical
  /self-order                  canonical
  /                            canonical
  /tickets/new                 canonical
  /tickets/:id                 canonical
  /services/change-plan        canonical
  /services/buy-addon          canonical
  /services/relocation         canonical
  /services/track              canonical
  /account/terminate           canonical
  /notifications               canonical
  /support/tickets/new         → /tickets/new
  /support/tickets/:id         → /tickets/:id
  /services/terminate          → /account/terminate
  /account/notifications       → /notifications

Global search:
  Home, Services, Bills, Support, Account, Notifications     (all 5 tabs + inbox)
  Change plan, Buy add-on, Relocate, Track tech, Coverage,
  New ticket                                                 (all reachable actions)
  + dynamic invoices / tickets
  Ticket result correctly navigates to /tickets/:id.
```

---

## Constraints honoured

- **No broken routes** — 4 redirect-only GoRoutes preserve legacy URLs.
- **No dropped features** — every page and quick-action still exists.
- **No i18n changes** — only the search-entry titles/subtitles in the
  default English copy were edited; no l10n keys were added, removed,
  or renamed. (The customer app has no l10n bundle wired today; copy
  is inline strings. If/when l10n is added, the new search entries
  pick up the same string-extraction pass as everything else.)
- **Design tokens preserved** — used existing `IonSearchEntry`,
  `Icons.*`, no custom widgets introduced.
- **No shared primitive touched** — `IonListCard`, `IonSectionHeader`,
  `IonSearchSheet`, `IonAppBar`, etc. untouched.
- **`flutter analyze` clean** — 47 issues before, 47 after.
- **Not committed** — per instructions.
