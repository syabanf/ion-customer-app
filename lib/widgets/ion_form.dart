// IonForm + design-system widgets — ION-brand refresh (Wave 18).
//
// Every public class + constructor signature is preserved so existing
// pages don't need touch-ups. Visual recipe per the ION brand spec:
//
//   - Cards: 24 px radius, soft `0 12px 30px rgba(31,31,36,0.08)`
//     shadow, 1 px #E4E5E5 hairline border, ample inner padding.
//   - Inputs: 16 px radius filled with a quiet off-white wash.
//   - Primary button: full-width pill, ION primary blue (#1772CF),
//     16 sp semibold label.
//   - Secondary button: pill, ion-50 tinted fill with #1772CF text
//     (or systemRed tint when destructive).
//   - Pills + segmented controls: rounded ION-blue capsule selected,
//     muted gray text inactive.
//   - Info rows: list-row layout with leading circular icon tile in
//     ion-100 (matches the medical/dashboard reference).
//
// Anchor file for tokens: lib/core/theme/app_theme.dart (IonColors).

import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/errors/api_exception.dart';
import '../core/theme/app_theme.dart';
import 'ion_anim.dart' show IonPressable, IonListSkeleton;

// =============================================================================
// IonForm — top-level visual tokens used across the design system.
// =============================================================================

class IonForm {
  IonForm._();

  /// Page background — ION Soft Background Gray (#F5F7FA).
  static const pageBg = IonColors.pageBg;

  /// Hairline divider between rows inside a grouped-list card.
  static const surfaceBorder = IonColors.separator;

  /// Filled-field background — quiet off-white wash.
  static const fieldFill = IonColors.fieldFill;

  /// ION premium card shadow — `0 12px 30px rgba(31,31,36,0.08)`.
  /// Use on every white card surface. Gives the soft elevated feel
  /// of the medical/dashboard reference without being heavy.
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF1F1F24).withValues(alpha: 0.08),
      blurRadius: 30,
      offset: const Offset(0, 12),
    ),
  ];

  /// Floating bottom-nav shadow — slightly stronger so the bar lifts
  /// visibly off the page background.
  static List<BoxShadow> floatShadow = [
    BoxShadow(
      color: const Color(0xFF1F1F24).withValues(alpha: 0.12),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
}

// =============================================================================
// IonSection — iOS grouped-list card with optional section header.
// =============================================================================

class IonSection extends StatelessWidget {
  const IonSection({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18),
  });

  /// Optional section header. Renders in 13 sp semibold, muted ink.
  final String? title;

  /// Card body. Wrap with `Column(children: [...])` for multi-row.
  final Widget child;

  /// Padding inside the card. Defaults to a generous 20×18 — premium
  /// dashboard cards breathe.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Wave 26 — references IonGap.l for the page horizontal margin
    // and IonRadius.section for the card shape, so any later token
    // refresh propagates here automatically. Section title uses
    // IonText.subhead-style label (still 13pt semibold muted).
    return Padding(
      padding: const EdgeInsets.fromLTRB(IonGap.l, IonGap.l, IonGap.l, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, IonGap.s - 2),
              child: Text(
                title!,
                style: IonText.subhead.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: IonColors.surface,
              borderRadius: BorderRadius.circular(IonRadius.section),
              border: Border.all(color: IonColors.separator, width: 1),
              boxShadow: IonForm.cardShadow,
            ),
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// IonDatePill — capsule chip used above page titles.
// =============================================================================

class IonDatePill extends StatelessWidget {
  const IonDatePill({super.key, required this.label, this.icon});
  final String label;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: IonColors.ion100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: IonColors.ion700),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: IonColors.ion700,
              letterSpacing: -0.08,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// IonPillSegment — large 2- or 3-option pill switch with sliding active card.
// =============================================================================

class IonPillSegment<T> extends StatelessWidget {
  const IonPillSegment({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final T value;
  final List<IonSegmentedOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final activeIdx = options.indexWhere((o) => o.value == value);
    final segPct = 1 / options.length;
    return Container(
      height: 36, // iOS UISegmentedControl height
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: IonColors.fieldFill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final segW = c.maxWidth * segPct;
          return Stack(
            children: [
              // iOS sliding capsule — white card with subtle shadow.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: activeIdx * segW,
                top: 0,
                bottom: 0,
                width: segW,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final o in options)
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(7),
                          onTap: () => onChanged(o.value),
                          child: Center(
                            child: Text(
                              o.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: o.value == value
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: o.value == value
                                    ? IonColors.ink
                                    : IonColors.inkSoft,
                                letterSpacing: -0.08,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// =============================================================================
// IonField — labeled filled text input (iOS systemFill look).
// =============================================================================

class IonField extends StatefulWidget {
  const IonField({
    super.key,
    required this.label,
    this.hint,
    this.helper,
    this.controller,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.leading,
    this.trailing,
    this.maxLength,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.showValidMark = true,
  });

  final String label;
  final String? hint;
  final String? helper;
  final TextEditingController? controller;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final IconData? leading;
  final Widget? trailing;
  final int? maxLength;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool enabled;

  /// Wave 23 — show a green check inside the field once the value is
  /// non-empty AND passes [validator]. Defaults to true. Pass false
  /// for fields where you want a custom trailing widget instead.
  final bool showValidMark;

  @override
  State<IonField> createState() => _IonFieldState();
}

class _IonFieldState extends State<IonField> {
  TextEditingController? _ownedCtrl;
  TextEditingController get _ctrl => widget.controller ?? _ownedCtrl!;
  String _last = '';

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _ownedCtrl = TextEditingController();
    _ctrl.addListener(_onChange);
    _last = _ctrl.text;
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChange);
    _ownedCtrl?.dispose();
    super.dispose();
  }

  void _onChange() {
    if (_ctrl.text == _last) return;
    setState(() => _last = _ctrl.text);
  }

  bool get _isValid {
    if (_last.isEmpty) return false;
    if (widget.validator == null) return true;
    return widget.validator!(_last) == null;
  }

  @override
  Widget build(BuildContext context) {
    final showCheck = widget.showValidMark && widget.trailing == null && _isValid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: IonColors.inkSoft,
              letterSpacing: -0.08,
            ),
          ),
        ),
        TextFormField(
          controller: _ctrl,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          maxLength: widget.maxLength,
          obscureText: widget.obscureText,
          enabled: widget.enabled,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          validator: widget.validator,
          style: const TextStyle(
            fontSize: 17, color: IonColors.ink, letterSpacing: -0.4,
          ),
          cursorColor: IonColors.ion500,
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: const TextStyle(
              color: IonColors.inkMuted,
              fontSize: 17,
              letterSpacing: -0.4,
            ),
            prefixIcon: widget.leading == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 14, right: 8),
                    child: Icon(widget.leading,
                        color: IonColors.inkMuted, size: 20),
                  ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: widget.trailing ??
                (showCheck
                    ? const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: IonColors.mint500,
                          size: 20,
                        ),
                      )
                    : null),
            suffixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            counterText: '',
            helperText: widget.helper,
            helperStyle: const TextStyle(
              fontSize: 12,
              color: IonColors.inkMuted,
              letterSpacing: -0.08,
            ),
            filled: true,
            fillColor: IonForm.fieldFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: showCheck ? IonColors.mint500 : IonColors.ion500,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: IonColors.danger, width: 1.0),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: IonColors.danger, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// IonSelect — labeled filled dropdown (iOS systemFill look).
// =============================================================================

class IonSelect<T> extends StatelessWidget {
  const IonSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final T value;
  final List<IonSelectItem<T>> items;
  final ValueChanged<T> onChanged;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: IonColors.inkSoft,
              letterSpacing: -0.08,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: IonForm.fieldFill,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              hint: hint == null ? null : Text(hint!),
              icon: const Icon(Icons.expand_more_rounded,
                  color: IonColors.inkMuted),
              style: const TextStyle(
                fontSize: 17,
                color: IonColors.ink,
                letterSpacing: -0.4,
              ),
              borderRadius: BorderRadius.circular(12),
              items: [
                for (final it in items)
                  DropdownMenuItem<T>(
                    value: it.value,
                    child: Text(it.label),
                  ),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class IonSelectItem<T> {
  const IonSelectItem(this.value, this.label);
  final T value;
  final String label;
}

// =============================================================================
// IonSegmented — compact iOS UISegmentedControl-style pill switch.
// =============================================================================

class IonSegmented<T> extends StatelessWidget {
  const IonSegmented({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final T value;
  final List<IonSegmentedOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: IonColors.fieldFill,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: _Seg(
                label: o.label,
                selected: o.value == value,
                onTap: () => onChanged(o.value),
              ),
            ),
        ],
      ),
    );
  }
}

class IonSegmentedOption<T> {
  const IonSegmentedOption(this.value, this.label);
  final T value;
  final String label;
}

class _Seg extends StatelessWidget {
  const _Seg({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(7),
      elevation: selected ? 0.5 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? IonColors.ink : IonColors.inkSoft,
                letterSpacing: -0.08,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// IonPrimaryButton — iOS .filled style. 50 pt tall, 14 pt radius,
// Headline (17 pt semibold).
// =============================================================================

class IonPrimaryButton extends StatelessWidget {
  const IonPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  /// When true, the button sizes to its label (with iOS-style padding)
  /// instead of stretching to fill the parent. Use for inline placement
  /// inside a `Row` — Row gives children unbounded width which conflicts
  /// with the default `width: double.infinity` and would otherwise throw
  /// `BoxConstraints forces an infinite width`.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Wave 20 — full-width pill, rich near-black surface, 52pt tall.
    // Matches the travel-app reference's primary CTA (e.g. "Book a
    // tour"). Active = inkBlack, disabled = light chip gray.
    //
    // The smaller `compact` variant is intentionally 44pt — same iOS
    // touch-target — and shrink-wraps its label so it can sit inside
    // a Row next to other widgets.
    final btn = ElevatedButton(
      // Wave 25 — mediumImpact haptic on primary CTAs; users physically
      // "feel" decisive actions (pay, submit, convert, complete).
      onPressed: loading || onPressed == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onPressed!();
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: IonColors.inkBlack,
        foregroundColor: Colors.white,
        disabledBackgroundColor: IonColors.chipBg,
        disabledForegroundColor: IonColors.chipText,
        shape: const StadiumBorder(),
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: compact ? 18 : 24),
        minimumSize: Size(0, compact ? 44 : 52),
        // `tapTargetSize: shrinkWrap` keeps the button at its rendered
        // height instead of padding to Material's 48-min default.
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: TextStyle(
          fontSize: compact ? 14 : 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      child: loading
          ? SizedBox(
              width: compact ? 16 : 20,
              height: compact ? 16 : 20,
              child: const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.2,
              ),
            )
          : Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: compact ? 16 : 19),
                  SizedBox(width: compact ? 6 : 10),
                ],
                Text(label),
              ],
            ),
    );
    if (compact) return btn;
    return SizedBox(height: 52, width: double.infinity, child: btn);
  }
}

// =============================================================================
// IonSecondaryButton — iOS .tinted style. Translucent ion-blue fill
// with ion-blue label. Destructive variant uses systemRed.
// =============================================================================

class IonSecondaryButton extends StatelessWidget {
  const IonSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    // Wave 20 — pill, tinted style. Default = neutral chip gray with
    // ink label (matches the inactive tab pills in the travel-app
    // reference); destructive variant keeps the soft red tint.
    final fg = destructive ? IonColors.danger : IonColors.ink;
    final bg = destructive
        ? const Color(0xFFFEE6E3) // soft danger tint
        : IonColors.chipBg;
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: TextButton(
        // Wave 25 — selectionClick on secondary; softer than mediumImpact
        // because secondary actions are usually reversible (cancel,
        // skip, view).
        onPressed: onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onPressed!();
              },
        style: TextButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: bg,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 19),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// IonErrorBanner — inline error card matching iOS HIG (danger tint, no border).
// =============================================================================

class IonErrorBanner extends StatelessWidget {
  const IonErrorBanner({super.key, required this.message});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE5E3), // tinted danger (systemRed @ 12%)
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 19, color: IonColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: IonColors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.3,
                letterSpacing: -0.08,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// IonInfoRow — iOS-settings-list row: label left, value right.
//
// Original API had an `icon` field for a tinted square tile. We keep
// it for source compatibility — but render it smaller and inline with
// the label so the row reads as a flat list item instead of a card.
// Drop the icon (use `Icons.circle` placeholder etc.) for a pure
// label/value row.
// =============================================================================

class IonInfoRow extends StatelessWidget {
  const IonInfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
    this.valueFont,
  });
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? valueFont;

  @override
  Widget build(BuildContext context) {
    // Activity / list row: leading circular icon tile (ion-50 fill +
    // ion-500 glyph), label left, value right. Matches the medical
    // reference's list-row vocabulary.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: IonColors.ion50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: IonColors.ion500, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: IonColors.ink,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (valueWidget != null)
            valueWidget!
          else
            Text(
              value ?? '—',
              style: TextStyle(
                fontSize: 14,
                color: IonColors.inkMuted,
                fontWeight: FontWeight.w500,
                fontFamily: valueFont,
                letterSpacing: -0.1,
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// IonTabPills — Wave 20. Two-or-more pill tab selector with dark active.
//
// Visual recipe per the travel-app reference (e.g. "Tour schedule /
// Booking and..."): the active pill fills with inkBlack and shows
// white text, inactive pills sit in a quiet chip-gray with muted
// text. Stack the pills inline; the row is content-sized so it can
// sit inside a header or a row of icon actions.
// =============================================================================

class IonTabPill<T> {
  const IonTabPill(this.value, this.label);
  final T value;
  final String label;
}

class IonTabPills<T> extends StatelessWidget {
  const IonTabPills({
    super.key,
    required this.value,
    required this.tabs,
    required this.onChanged,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  });
  final T value;
  final List<IonTabPill<T>> tabs;
  final ValueChanged<T> onChanged;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final t in tabs) ...[
          _PillButton(
            label: t.label,
            selected: t.value == value,
            onTap: () => onChanged(t.value),
            padding: padding,
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.padding,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? IonColors.inkBlack : IonColors.chipBg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : IonColors.chipText,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// IonCircleIconButton — Wave 20. The 40×40 circular back / favorite /
// share button used over photo heroes in the travel-app reference.
// White surface, soft shadow, ink glyph. Pass `tone:.light` when
// placing on a busy photo so the chip pops; default `.surface` is
// for on-card placement.
// =============================================================================

enum IonCircleIconTone { surface, light }

class IonCircleIconButton extends StatelessWidget {
  const IonCircleIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tone = IonCircleIconTone.surface,
    this.size = 40,
  });
  final IconData icon;
  final VoidCallback onTap;
  final IonCircleIconTone tone;
  final double size;
  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      IonCircleIconTone.surface => IonColors.surface,
      IonCircleIconTone.light => Colors.white.withValues(alpha: 0.92),
    };
    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        // Wave 25 — light haptic on circular icon taps (back, share,
        // notifications, etc.).
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: IonColors.separator, width: 0.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 19, color: IonColors.ink),
        ),
      ),
    );
  }
}

// =============================================================================
// Wave 20.1 — Eye-satisfying visual primitives. None of these widgets
// change behavior; they only give pages a richer, more deliberate
// visual hierarchy without inflating per-page code. Drop into any
// existing IonSection/Column layout.
// =============================================================================

/// Big rounded hero card with an optional gradient/photo background,
/// overlaid title block, and a single CTA slot. Mirrors the travel-app
/// reference's destination hero — feels like a brochure card.
class IonHeroCard extends StatelessWidget {
  const IonHeroCard({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.imageUrl,
    this.gradient,
    this.trailing,
    this.metaChips = const [],
    this.height = 196,
    this.onTap,
  });

  /// Small uppercase label above the title (e.g. "PLAN", "CURRENT WO").
  final String? eyebrow;
  final String title;

  /// One-line meta string under the title.
  final String? subtitle;

  /// Optional background image. If both image + gradient are given,
  /// the image renders below the gradient (gradient acts as overlay).
  final String? imageUrl;

  /// Optional background gradient. Defaults to ION primary gradient
  /// (ion500 → ion600) when no image + no gradient are supplied.
  final Gradient? gradient;

  /// Right-side overlay action (e.g. IonCircleIconButton with a
  /// bookmark/share icon).
  final Widget? trailing;

  /// Small status chips ("Active", "Due in 3d", etc.) overlaid on the
  /// bottom-left of the hero, above the title.
  final List<Widget> metaChips;

  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ??
        (imageUrl == null ? IonColors.primaryGradient : null);
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background layer — image OR gradient.
            if (imageUrl != null)
              Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: IonColors.primaryGradient,
                  ),
                ),
              ),
            if (effectiveGradient != null)
              DecoratedBox(
                decoration: BoxDecoration(gradient: effectiveGradient),
              ),
            // Bottom shadow gradient for readability of overlaid text
            // on photo heroes.
            if (imageUrl != null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x66000000),
                    ],
                    stops: [0.5, 1.0],
                  ),
                ),
              ),
            // Right-side overlay action.
            if (trailing != null)
              Positioned(top: 14, right: 14, child: trailing!),
            // Title block — pinned to the bottom-left.
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (metaChips.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: metaChips,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (eyebrow != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        eyebrow!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                      height: 1.15,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Compact metric tile — big number, small label, optional delta.
/// Pairs well in a Row/GridView for KPI rows. Numbers render in a
/// dense monospace-feel weight to read like financial UI.
class IonMetricTile extends StatelessWidget {
  const IonMetricTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.icon,
    this.accent,
    this.suffix,
    this.trend = IonTrend.none,
    this.onTap,
    this.numericValue,
    this.sparkline,
  });
  final String label;
  final String value;

  /// Small caption under the value, e.g. "+12% vs last week". When a
  /// [trend] is also supplied, the delta line is prefixed with an
  /// arrow glyph and colored green/red accordingly.
  final String? delta;

  /// Optional leading icon in a soft-tinted tile.
  final IconData? icon;

  /// Override the tile accent (default: ION blue). Ignored for the
  /// delta line when [trend] is set — trend colors take over there.
  final Color? accent;

  /// Optional suffix glyph next to the number (e.g. "GB", "Mbps").
  final String? suffix;

  /// Directional indicator for the delta line. `up` paints the delta
  /// + arrow in mint-500 (green), `down` in danger-red, `flat` in
  /// muted gray. `none` keeps the accent color (back-compat).
  final IonTrend trend;

  /// When supplied, the value renders via [IonCountingNumber] animating
  /// from 0 → this value on first paint. Use for KPI tiles where the
  /// page should feel "alive" on first load. Falls back to the static
  /// [value] string when null.
  final num? numericValue;

  /// Optional list of points for an inline trend chart drawn under
  /// the label. Color follows the accent or trend color.
  final List<double>? sparkline;

  /// Make the whole tile tappable. Adds a subtle highlight on press
  /// via the IonPressable wrapper.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? IonColors.ion500;
    final (trendColor, trendIcon) = switch (trend) {
      IonTrend.up => (IonColors.mint500, Icons.north_east_rounded),
      IonTrend.down => (IonColors.danger, Icons.south_east_rounded),
      IonTrend.flat => (IonColors.inkMuted, Icons.east_rounded),
      IonTrend.none => (c, null),
    };
    final card = Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: IonColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: IonColors.separator, width: 1),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: c, size: 18),
            ),
          if (icon != null) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: numericValue != null
                    // Wave 23 — animate 0 → target on first paint.
                    // Wave 24 — tint the headline number with the
                    // tile's accent so it visually links to the
                    // sparkline below (e.g. red bills with red trend).
                    ? IonCountingNumber(
                        value: numericValue!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: accent ?? IonColors.ink,
                          letterSpacing: -0.6,
                          height: 1.05,
                        ),
                      )
                    : Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: accent ?? IonColors.ink,
                          letterSpacing: -0.6,
                          height: 1.05,
                        ),
                      ),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    suffix!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: IonColors.inkMuted,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ],
          ),
          // Wave 23 — inline trend chart. Drawn below the label so it
          // doesn't fight with the number for attention. Color follows
          // accent (or trend color when one is set).
          if (sparkline != null && sparkline!.length >= 2) ...[
            const SizedBox(height: 8),
            IonSparkline(
              points: sparkline!,
              color: trend == IonTrend.none ? c : trendColor,
              height: 28,
            ),
          ],
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: IonColors.inkMuted,
              letterSpacing: -0.1,
            ),
          ),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trendIcon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(trendIcon, size: 12, color: trendColor),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    delta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: trendColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return IonPressable(onTap: onTap, child: card);
  }
}

/// Trend direction for an [IonMetricTile] delta line.
enum IonTrend { none, up, down, flat }

/// Colored status indicator — leading dot + uppercase label, soft
/// tinted background. Use for ticket/WO/invoice statuses where the
/// state is the headline (e.g. "OPEN", "RESOLVED", "OVERDUE").
class IonStatusPill extends StatelessWidget {
  const IonStatusPill({
    super.key,
    required this.label,
    required this.tone,
    this.dense = false,
  });
  final String label;

  /// Drives both fill + glyph color.
  final IonStatusTone tone;

  /// Tighter padding for inline use inside a card row.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      IonStatusTone.success => (IonColors.mint50, IonColors.mint700),
      IonStatusTone.warning => (
          const Color(0xFFFFFBEB),
          const Color(0xFFB45309),
        ),
      IonStatusTone.danger => (
          const Color(0xFFFFE5E3),
          IonColors.danger,
        ),
      IonStatusTone.info => (IonColors.ion50, IonColors.ion700),
      IonStatusTone.neutral => (IonColors.chipBg, IonColors.chipText),
      // Wave 26 — brand tone for "featured", "new", "highlighted" pills
      // that aren't a real workflow state. Indigo so they don't clash
      // with the existing ION blue info tone.
      IonStatusTone.brand => (IonColors.indigo50, IonColors.indigo700),
    };
    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            // Wave 27 — humanize the raw enum string before
            // upper-casing, so callers passing `in_progress` /
            // `pending_noc_verification` see "IN PROGRESS" /
            // "PENDING NOC REVIEW" instead of the raw snake_case.
            IonHumanize.status(label).toUpperCase(),
            style: TextStyle(
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

enum IonStatusTone {
  success, // resolved, paid, completed, won
  info, // in_progress, qualified, active
  warning, // pending, on_hold, document_pending
  danger, // overdue, failed, lost, cancelled-with-cause
  neutral, // closed, cancelled (no cause), archived
  brand, // featured, new, highlighted (non-workflow)
}

/// Section divider with an optional centered chip label. Use to break
/// a long scrollable into clearly-delimited sections without the heavy
/// "SECTION TITLE" header pattern. Renders a hairline separator with a
/// pill in the middle ("TODAY", "OLDER", "RESOLVED").
class IonChipDivider extends StatelessWidget {
  const IonChipDivider({super.key, required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(color: IonColors.separator, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: IonColors.chipBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: IonColors.inkMuted,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ),
          const Expanded(child: Divider(color: IonColors.separator, height: 1)),
        ],
      ),
    );
  }
}

/// Soft-tinted action chip — large tappable tile with a leading icon
/// disc + title + optional subtitle. Use in a horizontal-scroll Row
/// or 2-col Grid for "quick actions" surfaces (Pay bill, Upgrade,
/// Report issue, etc.).
class IonActionChip extends StatelessWidget {
  const IonActionChip({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? IonColors.ion500;
    return Material(
      color: IonColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 140,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: IonColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: IonColors.separator, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: c, size: 18),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: IonColors.ink,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: IonColors.inkMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty-state widget — for "no invoices yet", "no tickets" etc.
/// Big rounded surface with a centered soft-tinted icon, title, and
/// short hint. Designed to feel intentional rather than barren.
/// Wave 25 — kind of illustration rendered above an empty state.
/// Each maps to a small Flutter-painted vector animation in
/// [IonEmptyArt] — no external Lottie / SVG assets needed.
enum IonArtKind { inbox, tasks, allDone, search, leads }

/// Wave 25 — gently-animated empty-state illustration. Drawn with
/// `CustomPainter` so it stays sharp at any size and adapts to the
/// brand palette automatically. Pass into [IonEmptyState] via its
/// `art` parameter to upgrade the default icon disc.
class IonEmptyArt extends StatefulWidget {
  const IonEmptyArt({super.key, required this.kind, this.size = 120});
  final IonArtKind kind;
  final double size;

  @override
  State<IonEmptyArt> createState() => _IonEmptyArtState();
}

class _IonEmptyArtState extends State<IonEmptyArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => CustomPaint(
            painter: _IonEmptyArtPainter(
              kind: widget.kind,
              t: _ctrl.value,
            ),
          ),
        ),
      ),
    );
  }
}

class _IonEmptyArtPainter extends CustomPainter {
  _IonEmptyArtPainter({required this.kind, required this.t});
  final IonArtKind kind;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Soft circle backdrop — same recipe across all kinds so the art
    // reads as a system of illustrations, not a one-off.
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.45;
    final bobOffset = math.sin(t * 2 * math.pi) * 4;
    final bgPaint = Paint()..color = IonColors.ion50;
    canvas.drawCircle(Offset(cx, cy + 4), r, bgPaint);

    // The foreground bobs gently up/down on a 3.2s sine cycle.
    canvas.save();
    canvas.translate(0, bobOffset);
    switch (kind) {
      case IonArtKind.inbox:
        _paintInbox(canvas, cx, cy, size.width * 0.34);
        break;
      case IonArtKind.tasks:
        _paintTasks(canvas, cx, cy, size.width * 0.34);
        break;
      case IonArtKind.allDone:
        _paintAllDone(canvas, cx, cy, size.width * 0.34);
        break;
      case IonArtKind.search:
        _paintSearch(canvas, cx, cy, size.width * 0.34);
        break;
      case IonArtKind.leads:
        _paintLeads(canvas, cx, cy, size.width * 0.34);
        break;
    }
    canvas.restore();
  }

  void _paintInbox(Canvas c, double cx, double cy, double s) {
    // Envelope: rounded rectangle with a folded-flap chevron on top.
    final body = Paint()..color = IonColors.ion500;
    final flap = Paint()..color = IonColors.ion600;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: s * 1.8, height: s * 1.2),
      const Radius.circular(6),
    );
    c.drawRRect(rrect, body);
    final path = Path()
      ..moveTo(cx - s * 0.9, cy - s * 0.6)
      ..lineTo(cx, cy + s * 0.1)
      ..lineTo(cx + s * 0.9, cy - s * 0.6)
      ..close();
    c.drawPath(path, flap);
    // A small sparkle that orbits to suggest "fresh mail incoming".
    final ang = t * 2 * math.pi;
    final sx = cx + math.cos(ang) * s * 1.3;
    final sy = cy + math.sin(ang) * s * 0.9 - s * 0.4;
    c.drawCircle(Offset(sx, sy), 3, Paint()..color = IonColors.mint500);
  }

  void _paintTasks(Canvas c, double cx, double cy, double s) {
    // Clipboard with 3 horizontal lines (tasks).
    final pad = Paint()..color = IonColors.indigo500;
    final pageStrokeWidth = 2.0;
    final body = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = IonColors.indigo500
      ..style = PaintingStyle.stroke
      ..strokeWidth = pageStrokeWidth;
    // Page
    final pageRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 4), width: s * 1.7, height: s * 2.0),
      const Radius.circular(8),
    );
    c.drawRRect(pageRect, body);
    c.drawRRect(pageRect, outline);
    // Clip top
    final clip = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - s * 0.9), width: s * 0.9, height: s * 0.4),
      const Radius.circular(3),
    );
    c.drawRRect(clip, pad);
    // 3 task lines — top one has a check, others empty
    final lineY = [cy - s * 0.1, cy + s * 0.3, cy + s * 0.7];
    final line = Paint()
      ..color = IonColors.indigo500.withValues(alpha: 0.25)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final y in lineY) {
      c.drawLine(Offset(cx - s * 0.5, y), Offset(cx + s * 0.6, y), line);
    }
    // Check on first line — animates in/out via t
    final checkAlpha = (math.sin(t * 2 * math.pi) * 0.5 + 0.5).clamp(0.35, 1.0);
    final check = Paint()
      ..color = IonColors.mint500.withValues(alpha: checkAlpha)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path()
      ..moveTo(cx - s * 0.65, cy - s * 0.1)
      ..lineTo(cx - s * 0.55, cy - s * 0.02)
      ..lineTo(cx - s * 0.3, cy - s * 0.22);
    c.drawPath(checkPath, check);
  }

  void _paintAllDone(Canvas c, double cx, double cy, double s) {
    // Trophy / star: a big mint check inside a circle.
    final ringPaint = Paint()..color = IonColors.mint500;
    c.drawCircle(Offset(cx, cy), s * 1.05, ringPaint);
    final pulse = (math.sin(t * 2 * math.pi) * 0.05) + 1.0;
    final check = Paint()
      ..color = Colors.white
      ..strokeWidth = s * 0.16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final p = Path()
      ..moveTo(cx - s * 0.5 * pulse, cy)
      ..lineTo(cx - s * 0.1 * pulse, cy + s * 0.35 * pulse)
      ..lineTo(cx + s * 0.55 * pulse, cy - s * 0.35 * pulse);
    c.drawPath(p, check);
  }

  void _paintSearch(Canvas c, double cx, double cy, double s) {
    // Magnifying glass — circle ring + handle.
    final ring = Paint()
      ..color = IonColors.ion500
      ..strokeWidth = s * 0.18
      ..style = PaintingStyle.stroke;
    final glassR = s * 0.7;
    final ang = t * 2 * math.pi;
    // Glass center wobbles slightly so it feels "alive".
    final gx = cx - s * 0.25 + math.cos(ang) * 2;
    final gy = cy - s * 0.25 + math.sin(ang) * 2;
    c.drawCircle(Offset(gx, gy), glassR, ring);
    // Handle
    final handle = Paint()
      ..color = IonColors.ion500
      ..strokeWidth = s * 0.22
      ..strokeCap = StrokeCap.round;
    c.drawLine(
      Offset(gx + glassR * 0.7, gy + glassR * 0.7),
      Offset(gx + s * 0.95, gy + s * 0.95),
      handle,
    );
  }

  void _paintLeads(Canvas c, double cx, double cy, double s) {
    // Three overlapping head silhouettes (avatar stack).
    final colors = [
      IonColors.indigo500,
      IonColors.mint500,
      IonColors.peach500,
    ];
    final positions = [
      Offset(cx - s * 0.5, cy),
      Offset(cx, cy - 2),
      Offset(cx + s * 0.5, cy),
    ];
    for (var i = 0; i < 3; i++) {
      final paint = Paint()..color = colors[i];
      final p = positions[i];
      // Head
      c.drawCircle(Offset(p.dx, p.dy - s * 0.45), s * 0.32, paint);
      // Shoulder arc
      final shoulder = Path()
        ..moveTo(p.dx - s * 0.55, p.dy + s * 0.6)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + s * 0.55, p.dy + s * 0.6)
        ..close();
      c.drawPath(shoulder, paint);
    }
  }

  @override
  bool shouldRepaint(_IonEmptyArtPainter old) =>
      old.t != t || old.kind != kind;
}

class IonEmptyState extends StatelessWidget {
  const IonEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
    this.art,
  });
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  /// Wave 25 — optional animated illustration kind. When set, an
  /// [IonEmptyArt] renders above the title in place of the small
  /// icon disc — gives the empty state real personality.
  final IonArtKind? art;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      decoration: BoxDecoration(
        color: IonColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: IonColors.separator, width: 1),
      ),
      child: Column(
        children: [
          if (art != null)
            IonEmptyArt(kind: art!)
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: IonColors.ion50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: IonColors.ion500, size: 24),
            ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: IonColors.ink,
              letterSpacing: -0.2,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: IonColors.inkMuted,
                height: 1.4,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Wave 21 — Awwwards-tier primitives. Distinctive, confident, and
// composable. None of these widgets bake in business logic; they're
// pure visual primitives that any page can drop in.
// =============================================================================

/// Oversized display title. The big, confident page headline used at
/// the top of a hero scroll — pairs a small "eyebrow" pill (date,
/// section label, breadcrumb) with a 30-pt headline. Use sparingly,
/// one per page max.
class IonDisplayTitle extends StatelessWidget {
  const IonDisplayTitle({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });
  final String title;

  /// Small pill above the title. e.g. "Tuesday, May 21", or a
  /// breadcrumb like "Account · Profile".
  final String? eyebrow;

  /// Optional line under the title — same baseline as a metric subtitle.
  final String? subtitle;

  /// Optional right-side widget aligned with the eyebrow row (e.g.
  /// IonCircleIconButton with bell icon for notifications).
  final Widget? trailing;

  /// Override the horizontal padding. Default `EdgeInsets.symmetric(20)`.
  /// Pass `EdgeInsets.zero` when nesting inside an already-padded list.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // Wave 26 — uses IonText tokens (display + subhead) so any visual
    // refresh of the type ladder propagates everywhere this primitive
    // is used without per-page edits.
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null || trailing != null)
            Row(
              children: [
                if (eyebrow != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: IonColors.chipBg,
                      borderRadius: BorderRadius.circular(IonRadius.pill),
                    ),
                    child: Text(eyebrow!, style: IonText.eyebrow),
                  ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
          if (eyebrow != null || trailing != null) IonGap.mGap,
          Text(title, style: IonText.display),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: IonText.subhead),
          ],
        ],
      ),
    );
  }
}

/// Wave 25 — sliver-friendly hero header that collapses to a compact
/// title as the user scrolls down. Use inside a `CustomScrollView` as
/// the first sliver:
///
///   CustomScrollView(
///     slivers: [
///       IonSliverHero(eyebrow: today, title: 'Hi, Budi', subtitle: …),
///       SliverList(...),
///     ],
///   )
///
/// Expanded: shows the full IonDisplayTitle (eyebrow chip + 30-pt
/// headline + subtitle). As scrolled the eyebrow + subtitle fade out
/// and the headline shrinks toward a 17-pt toolbar title pinned to
/// the top — same pattern as Apple Mail / Notes / Music large titles.
class IonSliverHero extends StatelessWidget {
  const IonSliverHero({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.expandedHeight = 168,
  });
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? trailing;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      stretch: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: IonColors.pageBg,
      surfaceTintColor: Colors.transparent,
      expandedHeight: expandedHeight,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: IonColors.ink,
          letterSpacing: -0.2,
        ),
      ),
      // Only show the small title once the large hero is fully
      // collapsed — until then, the SliverAppBar.title slot stays
      // transparent so the large title in flexibleSpace owns the eye.
      centerTitle: true,
      actions: trailing != null
          ? [Padding(padding: const EdgeInsets.only(right: 8), child: trailing)]
          : null,
      flexibleSpace: LayoutBuilder(
        builder: (context, c) {
          // 0 = fully expanded, 1 = fully collapsed.
          final t = ((expandedHeight - c.maxHeight) /
                  (expandedHeight - kToolbarHeight))
              .clamp(0.0, 1.0);
          final showSmallTitle = t > 0.92;
          return FlexibleSpaceBar(
            collapseMode: CollapseMode.parallax,
            titlePadding: EdgeInsets.zero,
            title: const SizedBox.shrink(),
            background: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 8,
                20,
                12,
              ),
              child: Opacity(
                opacity: showSmallTitle ? 0 : 1 - (t * 0.6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (eyebrow != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: IonColors.chipBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          eyebrow!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: IonColors.inkSoft,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    if (eyebrow != null) const SizedBox(height: 12),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 30 - (t * 13), // 30 → 17
                        fontWeight: FontWeight.w800,
                        color: IonColors.ink,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: IonColors.inkMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Status dot with an animated halo glow. The dot pulses outward
/// every ~1.6 s — perfect for "live", "online", "in progress" cues.
/// Set `enabled: false` to render a static dot (idle states).
class IonGlowingDot extends StatefulWidget {
  const IonGlowingDot({
    super.key,
    this.size = 10,
    this.color = IonColors.mint500,
    this.enabled = true,
  });
  final double size;
  final Color color;
  final bool enabled;

  @override
  State<IonGlowingDot> createState() => _IonGlowingDotState();
}

class _IonGlowingDotState extends State<IonGlowingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.enabled) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant IonGlowingDot old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_ctrl.isAnimating) _ctrl.repeat();
    if (!widget.enabled && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        // Halo ring expands 1.0 → 2.4 while fading 0.4 → 0.
        final haloScale = 1.0 + 1.4 * t;
        final haloAlpha = widget.enabled ? (0.4 * (1 - t)) : 0.0;
        return SizedBox(
          width: widget.size * 2.6,
          height: widget.size * 2.6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Halo
              Container(
                width: widget.size * haloScale,
                height: widget.size * haloScale,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: haloAlpha),
                  shape: BoxShape.circle,
                ),
              ),
              // Core dot
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: widget.enabled
                      ? [
                          BoxShadow(
                            color: widget.color.withValues(alpha: 0.45),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dotted-line section separator. Premium alternative to a plain hairline.
/// 4-px dots, 4-px gaps, full width by default.
class IonDottedSeparator extends StatelessWidget {
  const IonDottedSeparator({
    super.key,
    this.color = IonColors.separator,
    this.thickness = 1.5,
    this.dotWidth = 4,
    this.spacing = 4,
  });
  final Color color;
  final double thickness;
  final double dotWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final dotCount = (c.maxWidth / (dotWidth + spacing)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dotCount,
            (_) => Container(
              width: dotWidth,
              height: thickness,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(thickness),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Floating bottom nav bar with sliding active indicator. Replaces
/// the standard Material BottomNavigationBar with a 64-pt pill that
/// floats above the page bottom with a soft shadow. Active tab gets
/// an animated black capsule that slides between positions.
class IonFloatingNavBar extends StatelessWidget {
  const IonFloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });
  final List<IonNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: SafeArea(
        top: false,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: IonColors.surface,
            borderRadius: BorderRadius.circular(999),
            boxShadow: IonForm.floatShadow,
            border: Border.all(color: IonColors.separator, width: 1),
          ),
          padding: const EdgeInsets.all(6),
          child: LayoutBuilder(
            builder: (context, c) {
              final segW = c.maxWidth / items.length;
              return Stack(
                children: [
                  // Sliding active indicator.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    left: currentIndex * segW,
                    top: 0,
                    bottom: 0,
                    width: segW,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        decoration: BoxDecoration(
                          color: IonColors.inkBlack,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavItem(
                            item: items[i],
                            selected: i == currentIndex,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class IonNavItem {
  const IonNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Small numeric badge — null hides it, "0"/0 also hides it.
  final int? badge;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final IonNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : IonColors.inkMuted;
    final hasBadge = item.badge != null && item.badge! > 0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        // Wave 25 — selectionClick when switching tabs; lighter than
        // mediumImpact so navigation doesn't feel like a "decision".
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    selected ? item.activeIcon : item.icon,
                    color: fg,
                    size: 20,
                  ),
                  if (hasBadge)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: IonColors.danger,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? IonColors.inkBlack
                                : IonColors.surface,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          item.badge! > 9 ? '9+' : '${item.badge}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Show label only on selected tab — the classic
              // "expanding pill" pattern that keeps inactive tabs
              // visually quiet.
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: selected
                    ? Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: fg,
                            letterSpacing: -0.1,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Compact stat chip — icon + number side-by-side in a tight rounded
/// shape. Use in a Wrap for a "stats glance" row (3-5 mini KPIs).
class IonStatChip extends StatelessWidget {
  const IonStatChip({
    super.key,
    required this.icon,
    required this.value,
    this.label,
    this.accent,
  });
  final IconData icon;
  final String value;
  final String? label;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final c = accent ?? IonColors.ion500;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: IonColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: IonColors.separator, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: IonColors.ink,
              letterSpacing: -0.1,
            ),
          ),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label!,
              style: const TextStyle(
                fontSize: 11,
                color: IonColors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Gradient-filled big number (the kind that headlines a stats hero).
/// Uses ShaderMask to fill the text with the aurora gradient.
class IonGradientText extends StatelessWidget {
  const IonGradientText({
    super.key,
    required this.text,
    this.fontSize = 40,
    this.fontWeight = FontWeight.w800,
    this.gradient,
    this.letterSpacing = -1.0,
  });
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Gradient? gradient;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? IonColors.auroraGradient;
    return ShaderMask(
      shaderCallback: (bounds) => g.createShader(
        Rect.fromLTWH(0, 0, bounds.width, bounds.height),
      ),
      blendMode: BlendMode.srcIn,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white, // overridden by ShaderMask
          letterSpacing: letterSpacing,
          height: 1.0,
        ),
      ),
    );
  }
}

// =============================================================================
// IonQuickAccessGrid — Wave 21. Grid-style quick-access row for the
// home / dashboard. Each item is a compact tappable tile with a
// tinted icon disc + 2-line label + optional numeric badge. Lays out
// as a 4-column wrap by default — pass `columns: 3` for a denser
// grid that fits longer labels.
// =============================================================================

class IonQuickAccessItem {
  const IonQuickAccessItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent,
    this.badge,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent;

  /// Optional badge — null hides it. Use for "3 new", "2 unread".
  final int? badge;
}

class IonQuickAccessGrid extends StatelessWidget {
  const IonQuickAccessGrid({
    super.key,
    required this.items,
    this.columns = 4,
    this.spacing = 10,
  });
  final List<IonQuickAccessItem> items;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Calculate the per-item width so the row wraps evenly.
        final w = (c.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final it in items)
              SizedBox(
                width: w,
                child: _QuickAccessTile(item: it),
              ),
          ],
        );
      },
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({required this.item});
  final IonQuickAccessItem item;
  @override
  Widget build(BuildContext context) {
    final c = item.accent ?? IonColors.ion500;
    final hasBadge = item.badge != null && item.badge! > 0;
    return IonPressable(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
        decoration: BoxDecoration(
          color: IonColors.surface,
          // Wave 24 — match the dominant 16-radius list-card recipe
          // used everywhere else, plus 1 px separator + cardShadow so
          // the grid reads "lifted" instead of flat-on-page.
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: IonColors.separator, width: 1),
          boxShadow: IonForm.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.12),
                    // Wave 24 — align icon disc to the standard 12-radius
                    // used elsewhere for inline tinted icon backdrops.
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(item.icon, color: c, size: 20),
                ),
                if (hasBadge)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: IonColors.danger,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: IonColors.surface, width: 1.5),
                      ),
                      child: Text(
                        item.badge! > 9 ? '9+' : '${item.badge}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: IonColors.ink,
                letterSpacing: -0.1,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Wave 22 — Magazine-tier primitives. Image-first, mixed-grid, and
// inline-data-viz building blocks for surfaces that need to feel
// editorial rather than utilitarian.
// =============================================================================

/// Photo-backed hero card. Drop a network image url (or local asset)
/// and the card renders the photo with a soft bottom-aligned gradient
/// for legibility of overlaid title + chips. Falls back to an aurora
/// gradient if the image fails to load.
/// Wave 25 — scroll-aware parallax image. Listens to the nearest
/// [Scrollable]'s position and translates the underlying image at
/// roughly 30% of the scroll speed, so when the user pans the page
/// the image inside the card glides at a quieter rate — a depth cue
/// borrowed from the iOS Photos / Apple Music large-card layouts.
///
/// Falls back to a plain centered Image when no Scrollable ancestor
/// exists (e.g. card placed inside a single-screen view).
class _IonParallaxImage extends StatefulWidget {
  const _IonParallaxImage({required this.image, required this.cardHeight});
  final ImageProvider image;
  final double cardHeight;

  @override
  State<_IonParallaxImage> createState() => _IonParallaxImageState();
}

class _IonParallaxImageState extends State<_IonParallaxImage> {
  ScrollPosition? _position;
  final GlobalKey _key = GlobalKey();

  void _onScroll() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Scrollable.maybeOf(context)?.position;
    if (next != _position) {
      _position?.removeListener(_onScroll);
      _position = next;
      _position?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  /// Compute a parallax offset in pixels based on where the card sits
  /// in the viewport. -20 .. +20 range — subtle enough not to draw
  /// the eye on its own, large enough to be felt during scrolling.
  double _offset() {
    final pos = _position;
    if (pos == null) return 0;
    final ctx = _key.currentContext;
    if (ctx == null) return 0;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return 0;
    final scrollable = Scrollable.of(context).context.findRenderObject();
    if (scrollable is! RenderBox) return 0;
    final cardTop = box.localToGlobal(Offset.zero, ancestor: scrollable).dy;
    final viewport = pos.viewportDimension;
    // Fraction: 0 at top of viewport, 1 at bottom.
    final f = ((cardTop + widget.cardHeight / 2) / viewport).clamp(0.0, 1.0);
    return (f - 0.5) * -40; // 20 → -20 across viewport pass
  }

  @override
  Widget build(BuildContext context) {
    final y = _offset();
    // OverflowBox renders the image 1.25× the card height so we have
    // room to translate it vertically without revealing empty
    // background. Centered by default; transform offsets from there.
    return ClipRect(
      child: OverflowBox(
        key: _key,
        maxHeight: widget.cardHeight * 1.25,
        minHeight: widget.cardHeight * 1.25,
        alignment: Alignment.center,
        child: Transform.translate(
          offset: Offset(0, y),
          child: Image(
            image: widget.image,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: IonColors.auroraGradient,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class IonPhotoCard extends StatelessWidget {
  const IonPhotoCard({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.imageUrl,
    this.imageProvider,
    this.metaChips = const [],
    this.trailing,
    this.height = 220,
    this.ribbon,
    this.onTap,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;

  /// URL for `Image.network`. Use null + [imageProvider] for assets.
  final String? imageUrl;

  /// Alternative — supply any ImageProvider (asset, file, memory).
  final ImageProvider? imageProvider;

  final List<Widget> metaChips;
  final Widget? trailing;
  final double height;

  /// Optional corner ribbon ("NEW", "HOT", "LIVE", …).
  /// Typed as a generic Widget so the caller may wrap an
  /// IonRibbonBadge in IonHeartbeat / FadeSlideIn for animation.
  final Widget? ribbon;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final image = imageProvider ??
        (imageUrl != null ? NetworkImage(imageUrl!) : null);
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image != null)
              // Wave 25 — scroll-aware parallax: the image translates
              // at ~30% of the page's scroll speed, giving the card a
              // sense of depth as the user scrolls past. Falls back to
              // a static Image when no Scrollable is found (e.g. the
              // card placed at the top of a non-scrollable surface).
              _IonParallaxImage(image: image, cardHeight: height)
            else
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: IonColors.auroraGradient,
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x99000000)],
                  stops: [0.4, 1.0],
                ),
              ),
            ),
            if (ribbon != null)
              Positioned(top: 0, left: 18, child: ribbon!),
            if (trailing != null)
              Positioned(top: 16, right: 16, child: trailing!),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (metaChips.isNotEmpty) ...[
                    Wrap(spacing: 6, runSpacing: 6, children: metaChips),
                    const SizedBox(height: 12),
                  ],
                  if (eyebrow != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        eyebrow!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.92),
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Corner ribbon for [IonPhotoCard]. Notched flag dropping from the
/// top-left edge.
class IonRibbonBadge extends StatelessWidget {
  const IonRibbonBadge({
    super.key,
    required this.label,
    this.color = IonColors.danger,
  });
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _RibbonClipper(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
        color: color,
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _RibbonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final p = Path()
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height - 8)
      ..lineTo(s.width / 2, s.height)
      ..lineTo(0, s.height - 8)
      ..close();
    return p;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> _) => false;
}

/// Asymmetric bento grid — 1 large feature card + 2 stacked smaller
/// cards on the right. The primary number gets visual weight while
/// supporting stats hug the side.
class IonBentoGrid extends StatelessWidget {
  const IonBentoGrid({
    super.key,
    required this.feature,
    required this.secondary,
    required this.tertiary,
    this.height = 220,
    this.spacing = 12,
  });
  final Widget feature;
  final Widget secondary;
  final Widget tertiary;
  final double height;
  final double spacing;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(flex: 3, child: feature),
          SizedBox(width: spacing),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(child: secondary),
                SizedBox(height: spacing),
                Expanded(child: tertiary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal snap-to-card carousel with optional page dots.
class IonHorizontalCarousel extends StatefulWidget {
  const IonHorizontalCarousel({
    super.key,
    required this.children,
    this.itemWidth = 280,
    this.spacing = 12,
    this.height = 200,
    this.showDots = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });
  final List<Widget> children;
  final double itemWidth;
  final double spacing;
  final double height;
  final bool showDots;
  final EdgeInsets padding;
  @override
  State<IonHorizontalCarousel> createState() => _IonHorizontalCarouselState();
}

class _IonHorizontalCarouselState extends State<IonHorizontalCarousel> {
  late final PageController _ctrl;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = PageController(
      viewportFraction: (widget.itemWidth /
              MediaQueryData.fromView(WidgetsBinding.instance.platformDispatcher.views.first).size.width)
          .clamp(0.3, 0.95),
    );
    _ctrl.addListener(() {
      final p = _ctrl.page?.round() ?? 0;
      if (p != _page && mounted) setState(() => _page = p);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _ctrl,
            padEnds: false,
            itemCount: widget.children.length,
            itemBuilder: (context, i) => Padding(
              padding: EdgeInsets.only(
                left: i == 0 ? widget.padding.left : widget.spacing / 2,
                right: i == widget.children.length - 1
                    ? widget.padding.right
                    : widget.spacing / 2,
              ),
              child: widget.children[i],
            ),
          ),
        ),
        if (widget.showDots && widget.children.length > 1) ...[
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.children.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page
                      ? IonColors.inkBlack
                      : IonColors.separator,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
/// Frosted-glass surface card. Soft white wash + thin border that
/// picks up underlying gradients.
class IonGlassCard extends StatelessWidget {
  const IonGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 24,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.42),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Clustered overlapping avatars. Last cluster element can be a "+N"
/// count badge.
class IonAvatarStack extends StatelessWidget {
  const IonAvatarStack({
    super.key,
    required this.avatars,
    this.size = 32,
    this.overlap = 12,
    this.extra,
  });
  final List<IonAvatar> avatars;
  final double size;
  final double overlap;
  final String? extra;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size + (avatars.length - 1) * (size - overlap),
          height: size,
          child: Stack(
            children: [
              for (var i = 0; i < avatars.length; i++)
                Positioned(
                  left: i * (size - overlap),
                  child: _AvatarCircle(avatar: avatars[i], size: size),
                ),
            ],
          ),
        ),
        if (extra != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: IonColors.chipBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              extra!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: IonColors.inkSoft,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class IonAvatar {
  const IonAvatar({this.imageUrl, this.initials, this.color});
  final String? imageUrl;
  final String? initials;
  final Color? color;
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.avatar, required this.size});
  final IonAvatar avatar;
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: avatar.color ?? IonColors.ion100,
        border: Border.all(color: IonColors.surface, width: 2),
        image: avatar.imageUrl != null
            ? DecorationImage(
                image: NetworkImage(avatar.imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: avatar.imageUrl == null
          ? Center(
              child: Text(
                avatar.initials ?? '?',
                style: TextStyle(
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w700,
                  color: IonColors.ion700,
                ),
              ),
            )
          : null,
    );
  }
}

/// Animated number that counts up from 0 → target on mount.
class IonCountingNumber extends StatefulWidget {
  const IonCountingNumber({
    super.key,
    required this.value,
    this.duration = const Duration(milliseconds: 900),
    this.style,
    this.suffix,
    this.decimals = 0,
  });
  final num value;
  final Duration duration;
  final TextStyle? style;
  final String? suffix;
  final int decimals;
  @override
  State<IonCountingNumber> createState() => _IonCountingNumberState();
}

class _IonCountingNumberState extends State<IonCountingNumber>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
  }

  @override
  void didUpdateWidget(covariant IonCountingNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wave 24 — RepaintBoundary isolates the count-up animation so it
    // doesn't repaint the surrounding metric card every frame.
    return RepaintBoundary(
      child: AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        final v = widget.value * t;
        final s = widget.decimals == 0
            ? v.round().toString()
            : v.toStringAsFixed(widget.decimals);
        return Text(
          '$s${widget.suffix ?? ''}',
          style: widget.style ??
              const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: IonColors.ink,
                letterSpacing: -0.6,
              ),
        );
      },
      ),
    );
  }
}

// =============================================================================
// IonSearchSheet — Wave 23. Branded full-screen search modal. Pass a
// suggestion list (recent + curated entries) and an `onSelected`
// callback that receives the picked value. The sheet itself owns
// the input field + filter logic; the host page only owns "what
// happens when an item is tapped."
// =============================================================================

class IonSearchEntry {
  const IonSearchEntry({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
    this.accent,
    this.tag,
  });
  final String id;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? accent;

  /// Optional uppercase chip on the right (e.g. "LEAD", "INVOICE").
  final String? tag;
}

/// Helper to show the modal — host pages do:
/// `IonSearchSheet.show(context, entries: …, onSelected: …)`.
class IonSearchSheet {
  static Future<IonSearchEntry?> show(
    BuildContext context, {
    required List<IonSearchEntry> entries,
    String placeholder = 'Search…',
    String recentHeader = 'Recent',
    String suggestedHeader = 'Suggested',
  }) {
    return showModalBottomSheet<IonSearchEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => _IonSearchSheetBody(
        entries: entries,
        placeholder: placeholder,
        recentHeader: recentHeader,
        suggestedHeader: suggestedHeader,
      ),
    );
  }
}

class _IonSearchSheetBody extends StatefulWidget {
  const _IonSearchSheetBody({
    required this.entries,
    required this.placeholder,
    required this.recentHeader,
    required this.suggestedHeader,
  });
  final List<IonSearchEntry> entries;
  final String placeholder;
  final String recentHeader;
  final String suggestedHeader;
  @override
  State<_IonSearchSheetBody> createState() => _IonSearchSheetBodyState();
}

class _IonSearchSheetBodyState extends State<_IonSearchSheetBody> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() => _q = _ctrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final filtered = _q.isEmpty
        ? widget.entries
        : widget.entries
            .where((e) =>
                e.title.toLowerCase().contains(_q) ||
                (e.subtitle?.toLowerCase().contains(_q) ?? false))
            .toList();
    return Container(
      height: h * 0.85,
      decoration: const BoxDecoration(
        color: IonColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle.
            const SizedBox(height: 10),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: IonColors.separator,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            // Search field.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 17,
                  color: IonColors.ink,
                  letterSpacing: -0.4,
                ),
                cursorColor: IonColors.ion500,
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  hintStyle: const TextStyle(
                    color: IonColors.inkMuted,
                    fontSize: 17,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: Icon(Icons.search_rounded,
                        color: IonColors.inkMuted, size: 22),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: IonColors.inkMuted, size: 20),
                          onPressed: () => _ctrl.clear(),
                        ),
                  filled: true,
                  fillColor: IonForm.fieldFill,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                        color: IonColors.ion500, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Section header + list.
            IonChipDivider(
              label: _q.isEmpty ? widget.suggestedHeader : 'Results',
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: IonEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No matches',
                        hint:
                            'Try a different keyword — name, phone, ID, address.',
                      ),
                    )
                  : ListView.separated(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, i) => _SearchResultRow(
                        entry: filtered[i],
                        onTap: () =>
                            Navigator.of(context).pop(filtered[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.entry, required this.onTap});
  final IonSearchEntry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = entry.accent ?? IonColors.ion500;
    return IonPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: IonColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: IonColors.separator, width: 1),
        ),
        child: Row(
          children: [
            if (entry.icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(entry.icon, color: c, size: 18),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: IonColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (entry.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      entry.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: IonColors.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (entry.tag != null) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: IonColors.chipBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.tag!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: IonColors.inkSoft,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: IonColors.inkMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// IonSnackbar — Wave 25. Branded snackbar helper with optional UNDO
// affordance. Replaces ad-hoc `ScaffoldMessenger.showSnackBar` calls.
//
// Two flavors:
//   - `IonSnackbar.show(context, "Saved")` — bottom toast, 3s, no action.
//   - `IonSnackbar.showWithUndo(context, "Resolved", onUndo: () => …)`
//     — toast + bold "Undo" button, 4s window for the user to recover
//     from a destructive action. Pairs naturally with swipe-to-action
//     lists (Wave 25 A2).
//
// Design recipe: near-black filled pill with white text + mint500 undo
// label. Slides up from the bottom over the bottom nav.
// =============================================================================

class IonSnackbar {
  static void show(
    BuildContext context,
    String message, {
    IconData? icon,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: IonColors.inkBlack,
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: duration,
        elevation: 8,
      ),
    );
  }

  /// Show a snackbar with an "Undo" affordance. [onUndo] fires when the
  /// user taps the action; otherwise the bar auto-dismisses silently.
  /// Use for destructive list-row actions (swipe-to-archive, etc.) so
  /// the user always has a 4-second escape hatch.
  static void showWithUndo(
    BuildContext context,
    String message, {
    required VoidCallback onUndo,
    IconData? icon,
    Duration duration = const Duration(seconds: 4),
    String undoLabel = 'Undo',
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: IonColors.inkBlack,
        behavior: SnackBarBehavior.floating,
        shape: const StadiumBorder(),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: duration,
        elevation: 8,
        action: SnackBarAction(
          label: undoLabel.toUpperCase(),
          textColor: IonColors.mint500,
          onPressed: () {
            HapticFeedback.lightImpact();
            onUndo();
          },
        ),
      ),
    );
  }
}

// =============================================================================
// Wave 26 — STANDARD LIBRARY PRIMITIVES
//
// Three canonical building blocks that every list/detail page should
// adopt. Replaces the 38 ad-hoc *Card classes scattered across feature
// pages and the orphan `Text('TIMELINE')` section headers — locks the
// app's visual vocabulary to one learnable shape.
// =============================================================================

/// IonListCard — the single recipe for every tappable row card.
/// Replaces _LeadCard / _WOCard / _TicketCard / _InvoiceCard / _AlertCard
/// / _OppCard / _CustomerCard / etc. (38 ad-hoc variants).
///
/// Layout: leading icon disc + title/subtitle column + optional trailing
/// pill. Card is radius-16, padding-16h×14v, cardShadow, separator
/// border, light haptic on tap via IonPressable.
///
///   IonListCard(
///     leading: const IonLeadingIcon(
///       icon: Icons.support_agent_outlined,
///       tint: IonColors.indigo500,
///     ),
///     title: 'Ticket #0042 · Slow speed',
///     subtitle: 'Updated 2h ago',
///     trailing: const IonStatusPill(label: 'OPEN', tone: IonStatusTone.info),
///     meta: const ['JKT-001', 'Priority HIGH'],
///     onTap: () => GoRouter.of(context).push('/tickets/0042'),
///   )
class IonListCard extends StatelessWidget {
  const IonListCard({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.meta = const [],
    this.onTap,
    this.titleStyle,
    this.subtitleStyle,
    this.dense = false,
  });

  /// Optional leading widget — usually [IonLeadingIcon]. ~40×40 max
  /// to keep row height predictable.
  final Widget? leading;

  /// Bold title line. Single-line, ellipsis if it overflows.
  final String title;

  /// Optional subtitle line below the title (caption style).
  final String? subtitle;

  /// Optional trailing widget — usually [IonStatusPill] or a value chip.
  final Widget? trailing;

  /// Optional dot-separated meta line (date, location, priority…).
  /// Renders below subtitle in caption style with bullet separators.
  final List<String> meta;

  final VoidCallback? onTap;

  /// Override the default `IonText.title` style if needed (rare).
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;

  /// Tighter padding for in-card list (e.g. inside an IonSection).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final pad = dense
        ? const EdgeInsets.fromLTRB(12, 10, 12, 10)
        : const EdgeInsets.fromLTRB(IonGap.m, IonGap.s, IonGap.m, IonGap.s);
    final card = Container(
      padding: pad,
      decoration: BoxDecoration(
        color: IonColors.surface,
        borderRadius: BorderRadius.circular(IonRadius.card),
        border: Border.all(color: IonColors.separator, width: 1),
        boxShadow: IonForm.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: IonGap.s),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle ?? IonText.bodyBold,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle ?? IonText.subhead,
                  ),
                ],
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    meta.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IonText.caption,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: IonGap.s),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return IonPressable(onTap: onTap, child: card);
  }
}

/// Small tinted icon disc — the canonical "leading" for [IonListCard]
/// and many tile-based layouts. 40×40, radius 12, soft tint of the
/// passed [tint] color (12% alpha) with the icon in full [tint].
class IonLeadingIcon extends StatelessWidget {
  const IonLeadingIcon({
    super.key,
    required this.icon,
    required this.tint,
    this.size = 40,
    this.iconSize = 20,
  });
  final IconData icon;
  final Color tint;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(IonRadius.chip),
      ),
      child: Icon(icon, color: tint, size: iconSize),
    );
  }
}

/// Sibling to [IonLeadingIcon] — same 40×40 tinted disc but shows 1-2
/// initials instead of an icon. Use for people-flavoured rows (leads,
/// customers, technicians).
class IonLeadingInitials extends StatelessWidget {
  const IonLeadingInitials({
    super.key,
    required this.initials,
    this.tint = IonColors.ion500,
    this.size = 40,
  });
  final String initials;
  final Color tint;
  final double size;

  /// Compute 1-2 uppercase initials from a full name. Falls back to
  /// "?" when the input is empty.
  static String fromName(String name) {
    final words =
        name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first[0].toUpperCase();
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(IonRadius.chip),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: tint,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}

/// IonSectionHeader — canonical section start. Pair with [IonText.eyebrow]
/// + [IonText.title] for a magazine-clean hierarchy. Replaces orphan
/// uppercase Text widgets and ad-hoc Section title rows.
///
///   IonSectionHeader(
///     eyebrow: 'ACTIVITY',
///     title: 'Recent timeline',
///     trailing: TextButton(onPressed: ..., child: const Text('See all')),
///   )
///
/// Lives at the page level (page padding handles horizontal margin).
/// Vertical rhythm: 8 px between eyebrow + title, 24 px below header
/// before the next surface.
class IonSectionHeader extends StatelessWidget {
  const IonSectionHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.trailing,
    this.padding = IonGap.pageH,
  });
  final String? eyebrow;
  final String title;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (eyebrow != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(eyebrow!.toUpperCase(), style: IonText.eyebrow),
                  ),
                Text(title, style: IonText.title),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// =============================================================================
// Wave 29 — EXCEPTION HANDLING
//
// Two primitives that every page should default to instead of rolling
// their own loading-/error-/empty- state UI.
//
//   IonError.humanize(error)
//     Returns a customer-friendly message for any thrown object.
//     Handles ApiException (kind-aware copy), DioException (network /
//     timeout / cancelled), TimeoutException, FormatException, and a
//     polite generic fallback. Never returns "Exception: 500" gibberish.
//
//   IonAsyncBuilder<T>(future: ..., builder: (data) => ...)
//     Drop-in replacement for FutureBuilder that always renders the
//     right state:
//       - loading → IonListSkeleton (or compact spinner if `compact`)
//       - error → IonErrorBanner with friendly message + Retry
//       - has data → caller's builder
//     Pages stop reinventing 4 branches per FutureBuilder.
//
// Pair with the global FlutterError.onError + PlatformDispatcher.onError
// guards wired in main.dart so framework-level failures also surface
// inline instead of blanking the canvas.
// =============================================================================

class IonError {
  IonError._();

  /// Convert any thrown object into a single short, customer-friendly
  /// message. NEVER returns enum names, status codes, or stack traces.
  /// Use to populate snackbars, banners, and inline errors.
  static String humanize(Object? error) {
    if (error == null) return 'Something went wrong.';

    if (error is ApiException) {
      // Trust the backend's `message` only if it's set and readable.
      // Fall back to a kind-aware copy when the message looks
      // engineer-y (contains "$", code-paths, stack-y substrings).
      final raw = error.message;
      if (raw.isNotEmpty && !_looksEngineery(raw)) return raw;
      return _byKind(error.kind);
    }

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return "That took too long. Check your connection and try again.";
        case DioExceptionType.cancel:
          return 'Request cancelled.';
        case DioExceptionType.connectionError:
          return "Can't reach the server. Check your internet.";
        case DioExceptionType.badCertificate:
          return 'Secure connection failed. Try again later.';
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode ?? 0;
          if (code == 401 || code == 403) return 'Please sign in again.';
          if (code == 404) return "We couldn't find what you were looking for.";
          if (code >= 500) {
            return "Our system is having a moment. Please retry in a bit.";
          }
          return 'Request failed. Please try again.';
        case DioExceptionType.unknown:
          return 'Something went wrong. Please try again.';
      }
    }

    if (error is TimeoutException) {
      return "That took too long. Please try again.";
    }
    if (error is FormatException) {
      return "We got an unexpected response. Try refreshing.";
    }
    if (error is StateError || error is ArgumentError) {
      return "Something went wrong on our end.";
    }

    // Fallback — return a polite generic.
    return 'Something went wrong. Please try again.';
  }

  /// Best-effort copy keyed by [ApiErrorKind] when the backend message
  /// is missing or engineer-y.
  static String _byKind(ApiErrorKind k) {
    switch (k) {
      case ApiErrorKind.validation:
        return 'Please double-check your input.';
      case ApiErrorKind.notFound:
        return "We couldn't find that.";
      case ApiErrorKind.conflict:
        return "That's already taken or in use.";
      case ApiErrorKind.unauthorized:
        return 'Please sign in again.';
      case ApiErrorKind.forbidden:
        return "You don't have access to that.";
      case ApiErrorKind.unavailable:
        return "We can't reach the server right now.";
      case ApiErrorKind.internal:
        return "Our system is having a moment. Please retry in a bit.";
      case ApiErrorKind.precondition:
        return 'Some prerequisite is missing — please refresh.';
      case ApiErrorKind.unknown:
        return 'Something went wrong. Please try again.';
    }
  }

  static bool _looksEngineery(String s) {
    if (s.length > 240) return true;
    if (s.contains(RegExp(r'[\$\{\}]'))) return true;
    if (s.contains(RegExp(r'\b(Exception|null|stacktrace|Error)\b'))) return true;
    if (s.contains(RegExp(r'^[a-z_]+\.[a-z_]+'))) return true;
    return false;
  }

  /// Show a friendly snackbar for any thrown error. Used by catch blocks
  /// that don't have a more specific recovery.
  static void snack(BuildContext context, Object error) {
    IonSnackbar.show(
      context,
      humanize(error),
      icon: Icons.error_outline_rounded,
    );
  }
}

/// Drop-in replacement for `FutureBuilder<T>` that always renders the
/// right state: branded skeleton on load, branded error banner on
/// throw, an optional empty state when data is `null` / empty, and the
/// caller's builder on success.
///
/// Typical usage:
///
///   IonAsyncBuilder<List<Ticket>>(
///     future: _ticketsFuture,
///     onRetry: () => setState(() => _ticketsFuture = _load()),
///     emptyTitle: 'No tickets yet',
///     emptyHint: "We'll list them here when you open one.",
///     emptyArt: IonArtKind.inbox,
///     builder: (context, tickets) => ListView(...),
///   )
class IonAsyncBuilder<T> extends StatelessWidget {
  const IonAsyncBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.onRetry,
    this.compactLoading = false,
    this.loadingSkeletonCount = 5,
    this.emptyTitle,
    this.emptyHint,
    this.emptyArt,
    this.isEmpty,
  });

  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;

  /// Called when the user taps Retry in the error banner. If null, the
  /// banner just shows the message without an action.
  final VoidCallback? onRetry;

  /// When `true`, render a compact 20-px spinner instead of the full
  /// list skeleton (useful inside small inline regions).
  final bool compactLoading;
  final int loadingSkeletonCount;

  /// Empty-state copy. When provided AND [isEmpty] returns true, the
  /// builder isn't called — we render an [IonEmptyState] instead.
  final String? emptyTitle;
  final String? emptyHint;
  final IonArtKind? emptyArt;

  /// Predicate that decides whether [data] is "empty". Defaults to:
  ///   data == null
  ///   data is List && data.isEmpty
  ///   data is Map && data.isEmpty
  ///   data is String && data.isEmpty
  final bool Function(T data)? isEmpty;

  bool _defaultIsEmpty(T data) {
    if (data is List) return data.isEmpty;
    if (data is Map) return data.isEmpty;
    if (data is String) return data.isEmpty;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          if (compactLoading) {
            return const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: IonColors.ion500,
                ),
              ),
            );
          }
          return IonListSkeleton(count: loadingSkeletonCount);
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: IonGap.l),
            child: _IonErrorPanel(
              message: IonError.humanize(snap.error),
              onRetry: onRetry,
            ),
          );
        }
        final data = snap.data;
        if (data == null) {
          // Treat null as either empty or unexpected; prefer empty UI
          // when copy is provided, else show a generic error.
          if (emptyTitle != null) {
            return _renderEmpty();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: IonGap.l),
            child: _IonErrorPanel(
              message: 'Nothing to show.',
              onRetry: onRetry,
            ),
          );
        }
        final empty = (isEmpty ?? _defaultIsEmpty)(data);
        if (empty && emptyTitle != null) {
          return _renderEmpty();
        }
        return builder(context, data);
      },
    );
  }

  Widget _renderEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: IonGap.l),
      child: IonEmptyState(
        icon: Icons.inbox_outlined,
        art: emptyArt,
        title: emptyTitle ?? 'Nothing here',
        hint: emptyHint,
      ),
    );
  }
}

/// Internal — branded error panel used inside [IonAsyncBuilder]. Mirrors
/// IonErrorBanner shape but adds an explicit "Try again" action.
class _IonErrorPanel extends StatelessWidget {
  const _IonErrorPanel({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
          IonGap.m, IonGap.m, IonGap.m, IonGap.m),
      decoration: BoxDecoration(
        color: IonColors.surface,
        borderRadius: BorderRadius.circular(IonRadius.card),
        border: Border.all(color: IonColors.separator, width: 1),
        boxShadow: IonForm.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: IonColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(IonRadius.chip),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: IonColors.danger, size: 18),
              ),
              const SizedBox(width: IonGap.s),
              Expanded(
                child: Text(message, style: IonText.bodyBold),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: IonGap.s),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Try again'),
                style: TextButton.styleFrom(
                  foregroundColor: IonColors.ink,
                  backgroundColor: IonColors.chipBg,
                  padding: const EdgeInsets.symmetric(
                      horizontal: IonGap.s, vertical: 6),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Custom-painted inline trend chart. Smooth curve + optional shaded
/// area below + endpoint dot.
class IonSparkline extends StatelessWidget {
  const IonSparkline({
    super.key,
    required this.points,
    this.color = IonColors.ion500,
    this.fillBelow = true,
    this.thickness = 2.0,
    this.height = 36,
  });
  final List<double> points;
  final Color color;
  final bool fillBelow;
  final double thickness;
  final double height;
  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return SizedBox(height: height);
    // Wave 24 — RepaintBoundary isolates the custom-paint layer from
    // its parent so scrolling a card carrying a sparkline doesn't
    // mark the whole card dirty every frame.
    return RepaintBoundary(
      child: SizedBox(
        height: height,
        child: CustomPaint(
          painter: _SparklinePainter(
            points: points,
            color: color,
            fillBelow: fillBelow,
            thickness: thickness,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.points,
    required this.color,
    required this.fillBelow,
    required this.thickness,
  });
  final List<double> points;
  final Color color;
  final bool fillBelow;
  final double thickness;
  @override
  void paint(Canvas canvas, Size size) {
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final minV = points.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 0.0001 ? 1.0 : (maxV - minV);
    final dx = size.width / (points.length - 1);
    Offset pt(int i) {
      final y = size.height -
          ((points[i] - minV) / range) * size.height * 0.88 -
          size.height * 0.06;
      return Offset(i * dx, y);
    }

    final path = Path()..moveTo(0, pt(0).dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = pt(i);
      final p1 = pt(i + 1);
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }
    if (fillBelow) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.22),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = shader
          ..style = PaintingStyle.fill,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final last = pt(points.length - 1);
    canvas.drawCircle(last, thickness * 1.6, Paint()..color = color);
    canvas.drawCircle(last, thickness * 0.8, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.points != points || old.color != color;
}

