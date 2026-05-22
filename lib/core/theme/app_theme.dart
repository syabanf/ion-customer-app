import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ION Network design tokens — ION-brand refresh (Wave 18).
///
/// Palette anchored to the ION brand spec (primary #1772CF, deep navy
/// #2C4B95, soft background #F5F7FA, dark text #1F1F24). Replaces the
/// Wave 17 iOS-systemBlue palette while keeping the same widget surface
/// so the 39 UI surfaces refresh without per-page edits.
///
/// Cross-reference:
///   - ion500   = #1772CF  (ION Primary Blue — main CTA, active nav)
///   - ion600   = #2C4B95  (ION Deep Navy — hero, accent depth)
///   - ion400   = #3E90D9  (Secondary Blue — supporting UI)
///   - ion300   = #84B2E3  (Soft Blue — chart accents)
///   - pageBg   = #F5F7FA  (ION soft-background gray)
///   - ink      = #1F1F24  (primary text)
///   - inkMuted = #8C8788  (subtitles, metadata)
///   - separator= #E4E5E5  (borders + dividers)
class IonColors {
  IonColors._();

  // Brand blues. Tints below ion400 are derived for surfaces that
  // need a softer wash (button-tinted bg, pill chip bg, etc.).
  static const ion50  = Color(0xFFE9F1FB);
  static const ion100 = Color(0xFFD3E3F8);
  static const ion200 = Color(0xFFA8C7F0);
  static const ion300 = Color(0xFF84B2E3); // ION Soft Blue
  static const ion400 = Color(0xFF3E90D9); // ION Secondary Blue
  static const ion500 = Color(0xFF1772CF); // ION Primary Blue
  static const ion600 = Color(0xFF2C4B95); // ION Deep Navy
  static const ion700 = Color(0xFF223A75); // darker navy for pressed
  static const ion800 = Color(0xFF182B58);
  static const ion900 = Color(0xFF0F1F38); // hero-card darkest

  // Text / ink.
  static const ink      = Color(0xFF0F172A); // primary text — rich near-black
  static const inkSoft  = Color(0xFF334155); // section labels
  static const inkMuted = Color(0xFF94A3B8); // metadata + placeholders

  // Wave 20 — neutral "carbon" palette. Drives the new clean primary
  // surface (CTA buttons, active tab pills, sticky footers) per the
  // travel-app reference. Brand blues are kept for accents + the
  // login hero, but the page chrome reads as quiet white now.
  static const inkBlack     = Color(0xFF111111); // CTA fill + active tab
  static const inkBlackSoft = Color(0xFF1F1F1F); // pressed state
  static const chipBg       = Color(0xFFF1F4F8); // inactive tab + plain chip
  static const chipText     = Color(0xFF64748B); // inactive tab label

  // Surfaces.
  static const pageBg         = Color(0xFFFAFBFD); // very light off-white
  static const surface        = Color(0xFFFFFFFF); // card background
  static const fieldFill      = Color(0xFFF1F4F8); // input fill
  static const separator      = Color(0xFFE2E8F0); // borders + dividers
  static const separatorLight = Color(0xFFEEF0F2); // softer hairline

  // Status — kept consistent across waves so existing per-status
  // surfaces (notification kinds, validation hints) stay readable.
  static const success = Color(0xFF1E9E5C); // calmer green to match palette
  static const warning = Color(0xFFE08800);
  static const danger  = Color(0xFFD84A3F);
  static const info    = ion500;

  // =========================================================================
  // Wave 21 — Awwwards-tier accent palette. Used for tinted surfaces
  // (hero cards, decorative gradient orbs, category chips) to break
  // up an all-neutral page without losing the clean foundation. Each
  // accent has a -50 (tint background) and -500 (accent fill) variant.
  // =========================================================================
  // Wave 26 — every accent now exposes 50/200/500/700 so callers can
  // build dim, surface, body, and emphatic variants without re-rolling
  // alpha math. Used by IonStatusPill tones, IonListCard leading discs,
  // and IonGradientText fallbacks.
  static const cream50    = Color(0xFFFBF6EE);
  static const cream500   = Color(0xFFD9B384); // warm sand
  static const indigo50   = Color(0xFFEEF0FF);
  static const indigo200  = Color(0xFFC7D2FE);
  static const indigo500  = Color(0xFF4F46E5); // electric indigo
  static const indigo700  = Color(0xFF3730A3);
  static const mint50     = Color(0xFFE6F7F1);
  static const mint200    = Color(0xFFA7F3D0);
  static const mint500    = Color(0xFF10B981); // mint accent
  static const mint700    = Color(0xFF047857);
  static const peach50    = Color(0xFFFFEFE7);
  static const peach200   = Color(0xFFFED7AA);
  static const peach500   = Color(0xFFEF6C4D); // peach accent
  static const peach700   = Color(0xFFC2410C);
  static const plum50     = Color(0xFFF6EAF6);
  static const plum200    = Color(0xFFDDD6FE);
  static const plum500    = Color(0xFF8B5CF6); // plum/purple accent
  static const plum700    = Color(0xFF6D28D9);

  /// ION primary gradient — `linear-gradient(135deg, #1772CF → #2C4B95)`.
  /// Use behind hero cards, login splash, dashboard summaries.
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ion500, ion600],
  );

  /// Aurora gradient — a richer 3-stop blend for hero surfaces that
  /// want to feel premium without being loud. Indigo → ion-blue →
  /// mint, diagonal. Pairs with white overlay text.
  static const auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigo500, ion500, mint500],
    stops: [0.0, 0.55, 1.0],
  );

  /// Dusk gradient — moody navy → plum for late-evening UI states
  /// (e.g. "after-hours support", premium tier).
  static const duskGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ion900, ion700, plum500],
    stops: [0.0, 0.55, 1.0],
  );
}

class AppTheme {
  AppTheme._();

  /// Wave 23 — branded typography:
  /// - Plus Jakarta Sans for display + headline (modern, slightly-condensed
  ///   geometric sans with strong personality)
  /// - Inter for body + UI text (industry-standard SaaS-readable sans)
  /// Both load via google_fonts — no asset bundling needed.
  static TextStyle display(TextStyle base) =>
      GoogleFonts.plusJakartaSans(textStyle: base);
  static TextStyle body(TextStyle base) =>
      GoogleFonts.inter(textStyle: base);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    final interBase = GoogleFonts.interTextTheme(base.textTheme);

    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: IonColors.ion500,
        primary: IonColors.ion500,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: IonColors.pageBg,
      textTheme: interBase
          .apply(bodyColor: IonColors.ink, displayColor: IonColors.ink)
          .copyWith(
            // Large title for hero sections (28-34 sp) — Plus Jakarta Sans.
            displaySmall: GoogleFonts.plusJakartaSans(
              fontSize: 32, fontWeight: FontWeight.w800,
              letterSpacing: -0.6, color: IonColors.ink,
            ),
            // Section title (22 sp semibold) — Plus Jakarta Sans.
            headlineSmall: GoogleFonts.plusJakartaSans(
              fontSize: 22, fontWeight: FontWeight.w700,
              letterSpacing: -0.4, color: IonColors.ink,
            ),
            // Card title / list-row primary (17 sp semibold) — Inter.
            titleMedium: GoogleFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w600,
              letterSpacing: -0.3, color: IonColors.ink,
            ),
            // Body (16 sp) — Inter.
            bodyLarge: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w400,
              letterSpacing: -0.2, color: IonColors.ink,
            ),
            // Subhead (14 sp) — Inter.
            bodyMedium: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w400,
              letterSpacing: -0.1, color: IonColors.ink,
            ),
            // Footnote / metadata (12 sp, muted) — Inter.
            bodySmall: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w500,
              letterSpacing: 0, color: IonColors.inkMuted,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: IonColors.pageBg,
        foregroundColor: IonColors.ink,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: IonColors.pageBg,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: IonColors.ink,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: IonColors.separator,
        thickness: 1,
        space: 1,
      ),
      // Wave 20 — buttons are full pills, primary surface is rich
      // near-black. Inactive states use the light chip gray.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: IonColors.inkBlack,
          foregroundColor: Colors.white,
          disabledBackgroundColor: IonColors.chipBg,
          disabledForegroundColor: IonColors.chipText,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: IonColors.inkBlack,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: IonColors.ink,
          textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: -0.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: IonColors.fieldFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: IonColors.ion500, width: 1.5),
        ),
        labelStyle: const TextStyle(color: IonColors.inkSoft),
        hintStyle: const TextStyle(color: IonColors.inkMuted),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: IonColors.ink,
        contentTextStyle: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
        dragHandleColor: IonColors.separator,
        dragHandleSize: Size(40, 4),
      ),
    );
  }

  /// Wave 23 — dark theme. Inverts the page surface to a near-black
  /// (#0B0F19) while keeping the brand accents readable. Text inverts
  /// to off-white. Cards become elevated dark surfaces. Used for
  /// night-shift technicians + system-following users.
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: IonColors.ion500,
        primary: IonColors.ion500,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF0B0F19),
      textTheme: GoogleFonts.interTextTheme(base.textTheme)
          .apply(bodyColor: Colors.white, displayColor: Colors.white)
          .copyWith(
            displaySmall: GoogleFonts.plusJakartaSans(
              fontSize: 32, fontWeight: FontWeight.w800,
              letterSpacing: -0.6, color: Colors.white,
            ),
            headlineSmall: GoogleFonts.plusJakartaSans(
              fontSize: 22, fontWeight: FontWeight.w700,
              letterSpacing: -0.4, color: Colors.white,
            ),
            titleMedium: GoogleFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w600,
              letterSpacing: -0.3, color: Colors.white,
            ),
            bodyLarge: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w400,
              letterSpacing: -0.2, color: Colors.white,
            ),
            bodyMedium: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w400,
              letterSpacing: -0.1,
              color: const Color(0xFFCBD5E1),
            ),
            bodySmall: GoogleFonts.inter(
              fontSize: 12, fontWeight: FontWeight.w500,
              letterSpacing: 0,
              color: const Color(0xFF94A3B8),
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0B0F19),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        surfaceTintColor: const Color(0xFF0B0F19),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: Colors.white,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1F2937),
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0B0F19),
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          elevation: 0,
        ),
      ),
    );
  }
}

/// Wave 23/24 — global theme mode controller. Single source of truth
/// for the light/dark/system preference. Each MaterialApp wraps itself
/// in a `ValueListenableBuilder<ThemeMode>(valueListenable: themeMode)`
/// so flipping the value rebuilds with the right theme everywhere.
///
/// Wave 24 — persistence via SharedPreferences. `loadPersistedThemeMode`
/// reads the saved value (call from main() before runApp) and
/// `setThemeMode` writes any new selection back so the user's choice
/// survives app restart. The reader is silent on error so a missing
/// plugin (e.g. tests, web cold-boot) doesn't crash startup.
final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

const String _kThemePrefKey = 'ion.themeMode';

/// Load the previously-saved theme mode from SharedPreferences. Sets
/// `themeMode.value` if a saved value exists. Safe to call before any
/// runApp; failures are swallowed so app startup never blocks on it.
Future<void> loadPersistedThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kThemePrefKey);
    themeMode.value = _decodeThemeMode(raw);
  } catch (_) {
    // Swallow — fall back to ThemeMode.system on any plugin error.
  }
}

/// Update the live theme mode and persist it. Call this from the
/// profile-page segmented control instead of mutating `themeMode.value`
/// directly, so the selection survives a restart.
Future<void> setThemeMode(ThemeMode mode) async {
  themeMode.value = mode;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemePrefKey, _encodeThemeMode(mode));
  } catch (_) {
    // Swallow — runtime change still works even if persistence fails.
  }
}

String _encodeThemeMode(ThemeMode m) => switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

ThemeMode _decodeThemeMode(String? s) => switch (s) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

// =============================================================================
// Wave 26 — STANDARD LIBRARY TOKENS
//
// Locks the typography / spacing / radius scales so every widget snaps
// to the same ladder. Pages should reference IonText/IonGap/IonRadius
// instead of hardcoding fontSize/EdgeInsets/borderRadius numbers — the
// audit revealed 15+ font sizes, 42+ EdgeInsets recipes, and 12+ radius
// values littered across the codebase. These three classes collapse
// that surface to a small, learnable vocabulary.
// =============================================================================

/// IonText — 8-step type ladder. Reference instead of inline `TextStyle`.
///
/// | Token    | Size | Weight | Letter | Role                              |
/// |----------|------|--------|--------|-----------------------------------|
/// | display  |  30  |  800   | -0.8   | One-per-page hero title           |
/// | headline |  22  |  700   | -0.4   | Card hero numbers, in-page titles |
/// | title    |  17  |  700   | -0.2   | Card titles, navbar labels        |
/// | body     |  15  |  400   |   0    | Default running text              |
/// | bodyBold |  15  |  600   | -0.1   | Emphasized body                   |
/// | subhead  |  13  |  500   |   0    | Secondary descriptions            |
/// | caption  |  12  |  500   |   0    | Meta lines, dates                 |
/// | eyebrow  |  10  |  800   | +1.2   | Uppercase chip / section eyebrow  |
///
/// All tokens default to `IonColors.ink`. Override with `.copyWith(color:)`.
class IonText {
  IonText._();
  static const TextStyle display = TextStyle(
    fontSize: 30, fontWeight: FontWeight.w800,
    letterSpacing: -0.8, color: IonColors.ink, height: 1.1,
  );
  static const TextStyle headline = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w700,
    letterSpacing: -0.4, color: IonColors.ink, height: 1.15,
  );
  static const TextStyle title = TextStyle(
    fontSize: 17, fontWeight: FontWeight.w700,
    letterSpacing: -0.2, color: IonColors.ink, height: 1.25,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w400,
    color: IonColors.ink, height: 1.4,
  );
  static const TextStyle bodyBold = TextStyle(
    fontSize: 15, fontWeight: FontWeight.w600,
    letterSpacing: -0.1, color: IonColors.ink, height: 1.4,
  );
  static const TextStyle subhead = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w500,
    color: IonColors.inkSoft, height: 1.4,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w500,
    color: IonColors.inkMuted, height: 1.35,
  );
  static const TextStyle eyebrow = TextStyle(
    fontSize: 10, fontWeight: FontWeight.w800,
    letterSpacing: 1.2, color: IonColors.inkMuted, height: 1.0,
  );
}

/// IonGap — 6-step spacing ladder. Use as `IonGap.m` to get `EdgeInsets.all(16)`,
/// or `IonGap.mSize` for a raw `SizedBox(height: 16)`. The vocabulary maps
/// directly to design intent:
///
/// | Token | px | Use                                                  |
/// |-------|----|------------------------------------------------------|
/// | xxs   |  4 | inside a pill (chip vertical padding)                |
/// | xs    |  8 | tight cluster gap (icon to label)                    |
/// | s     | 12 | inside a card (label to value)                       |
/// | m     | 16 | card-internal padding, list item vertical            |
/// | l     | 20 | page horizontal margin                               |
/// | xl    | 24 | BETWEEN sections                                     |
class IonGap {
  IonGap._();
  static const double xxs = 4;
  static const double xs  = 8;
  static const double s   = 12;
  static const double m   = 16;
  static const double l   = 20;
  static const double xl  = 24;

  // Raw SizedBox helpers for vertical rhythm — `IonGap.mGap` instead of
  // `const SizedBox(height: 16)`.
  static const SizedBox xxsGap = SizedBox(height: xxs);
  static const SizedBox xsGap  = SizedBox(height: xs);
  static const SizedBox sGap   = SizedBox(height: s);
  static const SizedBox mGap   = SizedBox(height: m);
  static const SizedBox lGap   = SizedBox(height: l);
  static const SizedBox xlGap  = SizedBox(height: xl);

  // Standard page edge insets.
  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: l);
  static const EdgeInsets pageHTop = EdgeInsets.fromLTRB(l, xs, l, 0);
  static const EdgeInsets cardInner = EdgeInsets.fromLTRB(m, m - 2, m, m - 2);
  static const EdgeInsets listRow = EdgeInsets.fromLTRB(m, m - 2, m, m - 2);
}

/// IonRadius — 4 corner-radius roles. Reference instead of magic numbers:
///
/// | Token    | px | Use                                       |
/// |----------|----|-------------------------------------------|
/// | chip     | 12 | Pills, badges, inline icon discs          |
/// | card     | 16 | List rows, action tiles                   |
/// | section  | 20 | Section cards, hero metric tiles          |
/// | hero     | 28 | Photo card, aurora hero, full-bleed media |
/// | pill     |999 | Stadium pills (status, action chip)       |
class IonRadius {
  IonRadius._();
  static const double chip    = 12;
  static const double card    = 16;
  static const double section = 20;
  static const double hero    = 28;
  static const double pill    = 999;
}

// =============================================================================
// Wave 27 — HUMANIZE
//
// Backend enums (snake_case) ship to the UI as raw strings: `in_progress`,
// `pending_noc_verification`, `cs_referral`, `no_internet`. Displaying
// those as-is feels engineer-y. This module gives every page one
// canonical way to render them as natural English.
//
// Two entry points:
//   - `'in_progress'.humanized` — generic snake_case → "In progress"
//   - `IonHumanize.status('pending_noc_verification')` — specific maps
//     that override the generic rule for known enum families (status,
//     source, category, severity, etc.).
//
// Always prefer the specific helper when one exists — the generic
// `.humanized` getter is a sane fallback for unknown strings.
// =============================================================================

/// Acronyms we keep ALL-CAPS in humanized output. These show up in the
/// codebase as snake_case words like `noc`, `gps`, `ktp`, `bast`, `wo`,
/// `sla`, `csat`, `ont`, `boq` etc.
const _ionUpperAcronyms = <String>{
  'noc', 'gps', 'ktp', 'bast', 'wo', 'ewo', 'sla', 'csat',
  'ont', 'boq', 'po', 'qr', 'id', 'idr', 'cs', 'tv', 'iptv',
};

extension IonStringHumanize on String {
  /// snake_case → Sentence case, keeping known acronyms in ALL CAPS.
  ///
  ///   "in_progress"              → "In progress"
  ///   "pending_noc_verification" → "Pending NOC verification"
  ///   "ewo_management"           → "EWO management"
  String get humanized {
    if (isEmpty) return this;
    final words = split('_');
    final out = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (w.isEmpty) continue;
      // Known acronym — render ALL CAPS regardless of position.
      if (_ionUpperAcronyms.contains(w.toLowerCase())) {
        out.add(w.toUpperCase());
        continue;
      }
      // First word: capitalize. Rest: lowercase.
      if (i == 0) {
        out.add('${w[0].toUpperCase()}${w.substring(1).toLowerCase()}');
      } else {
        out.add(w.toLowerCase());
      }
    }
    return out.join(' ');
  }
}

/// Centralized enum → display-string mappings. Each helper falls back
/// to `String.humanized` when no specific override exists.
class IonHumanize {
  IonHumanize._();

  /// Work-order / ticket / lead lifecycle statuses.
  static String status(String s) {
    return _statusMap[s] ?? s.humanized;
  }

  /// Lead source / acquisition channel.
  static String source(String s) {
    return _sourceMap[s] ?? s.humanized;
  }

  /// Customer-facing ticket category labels.
  static String category(String c) {
    return _categoryMap[c] ?? c.humanized;
  }

  /// Severity tier for alerts / SLA / stock breaches.
  static String severity(String s) {
    return _severityMap[s] ?? s.humanized;
  }

  /// Priority labels (low / medium / high).
  static String priority(String p) {
    return _priorityMap[p] ?? p.humanized;
  }

  /// Generic kind / type label fallback — alias for `.humanized`.
  static String kind(String k) => k.humanized;

  static const _statusMap = <String, String>{
    // Tickets
    'open': 'Open',
    'in_progress': 'In progress',
    'pending_customer': 'Awaiting your reply',
    'resolved': 'Resolved',
    'closed': 'Closed',
    // Work orders
    'unassigned': 'Not assigned',
    'assigned': 'Assigned',
    'dispatched': 'On the way',
    'on_hold': 'On hold',
    'pending_noc_verification': 'Awaiting NOC review',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
    // Invoices / payments
    'paid': 'Paid',
    'unpaid': 'Unpaid',
    'overdue': 'Overdue',
    'pending': 'Pending',
    'partial': 'Partially paid',
    // Leads / opportunities
    'new': 'New',
    'qualified': 'Qualified',
    'ready_to_convert': 'Ready to convert',
    'converted': 'Converted',
    'lost': 'Lost',
    'document_pending': 'Documents pending',
    // Quotations
    'draft': 'Draft',
    'issued': 'Sent',
    'accepted': 'Accepted',
    'rejected': 'Rejected',
    // Generic
    'active': 'Active',
    'inactive': 'Inactive',
    'archived': 'Archived',
  };

  static const _sourceMap = <String, String>{
    'cs_referral': 'CS referral',
    'self_order': 'Self-signup',
    'referral': 'Referral',
    'walk_in': 'Walk-in',
    'cold_call': 'Cold call',
    'web': 'Website',
    'marketplace': 'Marketplace',
  };

  static const _categoryMap = <String, String>{
    'no_internet': 'No internet',
    'slow_speed': 'Slow speed',
    'frequent_drops': 'Frequent disconnects',
    'equipment_damage': 'Equipment issue',
    'billing_dispute': 'Billing question',
    'service_request': 'Service request',
    'feedback': 'Feedback',
    'other': 'Other',
  };

  static const _severityMap = <String, String>{
    'low': 'Low',
    'medium': 'Medium',
    'high': 'High',
    'critical': 'Critical',
    'out': 'Out of stock',
  };

  static const _priorityMap = <String, String>{
    'low': 'Low',
    'medium': 'Normal',
    'high': 'High',
    'urgent': 'Urgent',
  };
}
