import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';

/// IonAppBar — iOS-modern navigation bar (Wave 17).
///
/// Default visual is the iOS-standard small nav bar:
///   - 44 pt content height (52 pt total inside the safe area)
///   - Centered 17 pt semibold title with -0.4 letter-spacing
///   - SF-Symbol-style back chevron in iOS blue
///   - 0.5 px hairline separator below
///   - Same systemGroupedBackground as the page (no white band)
///
/// Public surface kept stable — same constructor + same field names as
/// before — so no page touch-ups required. The only visual jump is the
/// look itself.
class IonAppBar extends StatelessWidget implements PreferredSizeWidget {
  const IonAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.leading,
    this.onBack,
  });

  /// Page title — centered. 17 pt semibold to match iOS Headline.
  final String title;

  /// Optional small subtitle below the title (e.g. WO number).
  /// Renders in 12 pt SF-Mono-style monospace, muted ink.
  final String? subtitle;

  /// Right-side actions. Use [IonAppBarAction] for consistent visuals.
  final List<Widget> actions;

  /// Custom leading widget. Defaults to the iOS chevron-left back.
  /// Pass [const SizedBox.shrink()] to hide it entirely.
  final Widget? leading;

  /// Override the back action. Defaults to `GoRouter.pop()` falling
  /// back to a sensible home route.
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: IonColors.pageBg,
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: IonColors.pageBg,
          border: Border(
            bottom: BorderSide(color: IonColors.separator, width: 0.5),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: kToolbarHeight,
            child: Row(
              children: [
                const SizedBox(width: 4),
                // iOS-style chevron back — no pill, no circle.
                leading ??
                    _IosBackButton(
                      onTap: onBack ?? () => _defaultBack(context),
                    ),
                // Title block — centered, with the iOS Headline recipe.
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: IonColors.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: IonColors.inkMuted,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Symmetric right slot — reserve 44 pt if no actions
                // so the title stays optically centred.
                if (actions.isEmpty)
                  const SizedBox(width: 44)
                else
                  Row(mainAxisSize: MainAxisSize.min, children: actions),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _defaultBack(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/');
    }
  }
}

/// ION-style back chip — circular 40×40 white card with soft border,
/// hairline shadow, and an arrow chevron in ION primary blue. Mirrors
/// the medical-reference back-button vocabulary.
class _IosBackButton extends StatelessWidget {
  const _IosBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: IonColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: IonColors.separator, width: 1),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: IonColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// IonAppBarAction — 40 × 40 circular icon chip in the right slot
/// of [IonAppBar]. White surface with hairline border, ION primary
/// blue glyph, optional red badge dot.
class IonAppBarAction extends StatelessWidget {
  const IonAppBarAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.color,
    this.hasBadge = false,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final Color? color;
  final bool hasBadge;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IonColors.ion500;
    final btn = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          // Wave 25 — light haptic on app-bar action taps.
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: IonColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: IonColors.separator, width: 1),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 19, color: c),
                if (hasBadge)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: IonColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: IonColors.surface, width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}
