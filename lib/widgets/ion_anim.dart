import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:palette_generator/palette_generator.dart';

import '../core/theme/app_theme.dart';

/// IonAnim — small animation helpers used to give pages an iOS-style
/// "soft entrance" feel without depending on a third-party package.

/// Fade + slight upward slide as the widget mounts. Useful for content
/// blocks that appear after a network fetch (next-job card, stat tiles,
/// list rows). Optional [delay] supports staggered list reveals.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 320),
    this.offset = 16,
  });
  final Widget child;
  final Duration delay;
  final Duration duration;

  /// How far below the final position to start, in logical pixels.
  /// Keep small (12–20 px) — bigger values feel sluggish on a phone.
  final double offset;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
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
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Wraps a child so that the *cross-fade between rebuilds* happens
/// smoothly — used inside FutureBuilders so the transition from
/// "loading spinner" to "data" doesn't pop.
class IonCrossfade extends StatelessWidget {
  const IonCrossfade({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
  });
  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// Tab-switch fade. Drop-in around an [IndexedStack] to fade the active
/// child in without rebuilding inactive ones — preserves scroll state.
///
/// We can't fade inside IndexedStack directly (it just hides children),
/// so this stacks all of them with `Opacity` + `IgnorePointer`. Each
/// child stays mounted so scroll position survives a tab switch.
class IonAnimatedTabs extends StatelessWidget {
  const IonAnimatedTabs({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 220),
  });
  final int index;
  final List<Widget> children;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          IgnorePointer(
            ignoring: i != index,
            child: AnimatedOpacity(
              duration: duration,
              curve: Curves.easeOutCubic,
              opacity: i == index ? 1.0 : 0.0,
              child: children[i],
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// IonPressable — Wave 20. Scale-on-tap wrapper (0.97 + slight fade)
// that adds tactile feedback to any tappable surface. Wrap a Card,
// Container, or any widget that responds to onTap. Internally uses
// GestureDetector so it composes with Material InkWell underneath if
// you want both ripple + scale.
// =============================================================================

class IonPressable extends StatefulWidget {
  const IonPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
    this.duration = const Duration(milliseconds: 120),
    this.enabled = true,
    this.haptic = true,
  });
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final bool enabled;

  /// Wave 25 — fire HapticFeedback.lightImpact on tap-down. Default
  /// `true` so every IonPressable in the app gets the premium "I felt
  /// that" tactile micro-pulse. Disable for purely-decorative pressables
  /// or auto-fire animation hosts.
  final bool haptic;

  @override
  State<IonPressable> createState() => _IonPressableState();
}

class _IonPressableState extends State<IonPressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.enabled
          ? (_) {
              if (widget.haptic) HapticFeedback.lightImpact();
              setState(() => _down = true);
            }
          : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _down = false) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _down = false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _down ? 0.92 : 1.0,
          duration: widget.duration,
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

// =============================================================================
// IonShimmer — Wave 20. Skeleton-loader pulse for cards mid-fetch.
// Renders a soft horizontally-moving gradient sweep over a neutral
// gray base. Place it inside a Container shaped like the eventual
// content so the layout doesn't jump when real data arrives.
// =============================================================================

class IonShimmer extends StatefulWidget {
  const IonShimmer({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius = 8,
  });
  final double height;
  final double width;
  final double radius;

  @override
  State<IonShimmer> createState() => _IonShimmerState();
}

class _IonShimmerState extends State<IonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

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
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1.5 + _ctrl.value * 3, 0),
              end: Alignment(1.5 + _ctrl.value * 3, 0),
              colors: const [
                Color(0xFFEDEFF3),
                Color(0xFFF7F8FA),
                Color(0xFFEDEFF3),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// IonStaggeredList — Wave 20. Wraps a list of children and stages
// each one through FadeSlideIn with an incrementing delay, so list
// items land one after another instead of all at once. The total
// stagger duration caps at ~600 ms to keep long lists snappy.
// =============================================================================

class IonStaggeredList extends StatelessWidget {
  const IonStaggeredList({
    super.key,
    required this.children,
    this.stepMs = 60,
    this.maxStepCount = 10,
    this.offset = 12,
  });
  final List<Widget> children;
  final int stepMs;

  /// After this many items, the delay stops increasing — keeps very
  /// long lists from feeling like they take forever to settle.
  final int maxStepCount;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++)
          FadeSlideIn(
            delay: Duration(milliseconds: stepMs * i.clamp(0, maxStepCount)),
            offset: offset,
            child: children[i],
          ),
      ],
    );
  }
}

// =============================================================================
// IonHeartbeat — Wave 20. Subtle pulse animation for badge counters
// or status dots that should draw the eye without being noisy. Scales
// between 1.0 and 1.12 on a sine wave; pauses between pulses.
// =============================================================================

class IonHeartbeat extends StatefulWidget {
  const IonHeartbeat({
    super.key,
    required this.child,
    this.amplitude = 0.12,
    this.period = const Duration(milliseconds: 1600),
    this.enabled = true,
  });
  final Widget child;
  final double amplitude;
  final Duration period;
  final bool enabled;

  @override
  State<IonHeartbeat> createState() => _IonHeartbeatState();
}

class _IonHeartbeatState extends State<IonHeartbeat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _ctrl.repeat(reverse: false);
  }

  @override
  void didUpdateWidget(covariant IonHeartbeat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: false);
    } else if (!widget.enabled && _ctrl.isAnimating) {
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
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Spend roughly the first 40% of the period pulsing, the rest
        // at rest. Smoother + less attention-grabbing than a constant
        // bounce.
        final t = _ctrl.value;
        final pulse = t < 0.4
            ? Curves.easeOutSine.transform(t / 0.4)
            : 1.0 - Curves.easeInSine.transform((t - 0.4).clamp(0, 0.4) / 0.4);
        final s = 1.0 + widget.amplitude * pulse.clamp(0, 1);
        return Transform.scale(scale: s, child: child);
      },
      child: widget.child,
    );
  }
}

// =============================================================================
// IonListSkeleton — Wave 24. Drop-in skeleton placeholder for listing
// pages while async data is loading. Renders [count] rounded shimmer
// "cards" with internal title/subtitle bars. Designed to replace the
// stock CircularProgressIndicator on listing pages so the page already
// looks "shaped like itself" before the data arrives.
// =============================================================================

class IonListSkeleton extends StatelessWidget {
  const IonListSkeleton({
    super.key,
    this.count = 6,
    this.cardHeight = 88,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24),
    this.gap = 12,
  });

  /// How many skeleton rows to render. ~6 fills a typical phone viewport
  /// without looking gratuitous.
  final int count;
  final double cardHeight;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: count,
      separatorBuilder: (_, __) => SizedBox(height: gap),
      itemBuilder: (context, i) {
        return _SkeletonCard(height: cardHeight, index: i);
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height, required this.index});
  final double height;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Vary the title-bar width a bit per row so the page doesn't look
    // mechanically uniform — the eye reads it as real content faster.
    const widths = [0.55, 0.42, 0.62, 0.5, 0.48, 0.58, 0.46];
    final titleW = widths[index % widths.length];

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E8EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const IonShimmer(width: 40, height: 40, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: titleW,
                  child: const IonShimmer(height: 12, radius: 4),
                ),
                const SizedBox(height: 10),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (titleW - 0.15).clamp(0.25, 0.7),
                  child: const IonShimmer(height: 10, radius: 4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const IonShimmer(width: 56, height: 24, radius: 12),
        ],
      ),
    );
  }
}

// =============================================================================
// IonOfflineBanner — Wave 25. Listens to the device connectivity
// stream and animates a thin pill banner down from the top of the
// screen when the connection drops. Auto-dismisses with a soft slide-up
// when connectivity returns. Mount once at the top of MaterialApp's
// builder so it overlays every route.
//
// Usage in MaterialApp.router:
//
//   builder: (context, child) => IonOfflineBanner.wrap(child!),
//
// On web the connectivity_plus plugin returns `ConnectivityResult.wifi`
// roughly accurately based on `navigator.onLine` — good enough to
// surface "you went offline mid-task" warnings.
// =============================================================================

class IonOfflineBanner extends StatefulWidget {
  const IonOfflineBanner({super.key, required this.child});
  final Widget child;

  /// Convenience wrapper for MaterialApp.builder. Wraps [child] in the
  /// offline-banner Stack so the banner floats at the very top of the
  /// app's render tree.
  static Widget wrap(Widget child) => IonOfflineBanner(child: child);

  @override
  State<IonOfflineBanner> createState() => _IonOfflineBannerState();
}

class _IonOfflineBannerState extends State<IonOfflineBanner> {
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = Connectivity();
      final initial = await c.checkConnectivity();
      if (!mounted) return;
      setState(() => _offline = _isOffline(initial));
      _sub = c.onConnectivityChanged.listen((r) {
        if (!mounted) return;
        setState(() => _offline = _isOffline(r));
      });
    } catch (_) {
      // Plugin missing on this platform (e.g. headless test) — quietly
      // assume online so the banner never falsely covers the UI.
    }
  }

  bool _isOffline(List<ConnectivityResult> r) {
    if (r.isEmpty) return true;
    return r.every((x) => x == ConnectivityResult.none);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // The banner sits BELOW SafeArea top so it tucks under the
        // notch on iOS / status bar on Android cleanly.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            offset: _offline ? Offset.zero : const Offset(0, -1.5),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _offline ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2933),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.cloud_off_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "You're offline — changes will sync when back online",
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// IonConfetti — Wave 25. Fire-and-forget confetti burst overlay for
// success milestones (lead converted, WO completed, invoice paid,
// ticket resolved).
//
// Usage:
//   IonConfetti.celebrate(context);
//
// The burst is implemented as a transient OverlayEntry hosting a
// ConfettiWidget that auto-disposes after the animation finishes
// (~2.4s). Confetti emits from top-center pointing downward — feels
// like a "shower" not a "cannon", which matches a business B2B
// app's restrained mood. A mediumImpact haptic fires alongside.
// =============================================================================

class IonConfetti {
  static void celebrate(BuildContext context, {Duration? duration}) {
    // Haptic always — even if Overlay can't find a host (e.g. during
    // route transition) the user still gets feedback.
    HapticFeedback.mediumImpact();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiHost(
        duration: duration ?? const Duration(milliseconds: 1400),
        onDone: () {
          try {
            entry.remove();
          } catch (_) {
            // Already removed (e.g. host route popped) — silent.
          }
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _ConfettiHost extends StatefulWidget {
  const _ConfettiHost({required this.duration, required this.onDone});
  final Duration duration;
  final VoidCallback onDone;

  @override
  State<_ConfettiHost> createState() => _ConfettiHostState();
}

class _ConfettiHostState extends State<_ConfettiHost> {
  late final ConfettiController _ctrl =
      ConfettiController(duration: widget.duration);

  @override
  void initState() {
    super.initState();
    // Slight delay so the play() runs after the overlay mounts and
    // the ConfettiWidget has a layout pass.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.play();
    });
    // Self-clean once the controller's stopped state stabilises. We
    // add a bit of padding past the controller's duration so the
    // last fragments finish their fall before we unmount.
    Future.delayed(widget.duration + const Duration(milliseconds: 1200), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _ctrl,
          blastDirection: math.pi / 2, // straight down
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.05,
          numberOfParticles: 22,
          maxBlastForce: 22,
          minBlastForce: 8,
          gravity: 0.25,
          shouldLoop: false,
          colors: const [
            IonColors.ion500,
            IonColors.mint500,
            IonColors.indigo500,
            IonColors.peach500,
            IonColors.plum500,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// IonPalette — Wave 25. Async dominant-color extraction from a remote
// or asset image. Wraps `palette_generator` with a memo cache + safe
// error swallowing so misbehaving images never crash the caller. Pair
// with [IonPaletteBuilder] to drive content-aware UI tinting (Spotify
// / Apple Music adapts surrounding chrome to the artwork's color).
// =============================================================================

class IonPalette {
  IonPalette._();

  // Memo keyed by image url — keeps the network roundtrip + decode
  // cost down to one-per-image-per-session.
  static final Map<String, Color> _memo = {};

  /// Extract the dominant color from a [imageProvider]. Returns null
  /// (instead of throwing) when the image can't be decoded, the
  /// network drops, or no usable swatch is found.
  static Future<Color?> dominant(ImageProvider provider) async {
    // Memo lookup — only NetworkImage URLs are stable identifiers
    // we can hash; other providers re-extract.
    final memoKey = provider is NetworkImage ? provider.url : null;
    if (memoKey != null && _memo.containsKey(memoKey)) {
      return _memo[memoKey];
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        provider,
        size: const Size(120, 120),
        maximumColorCount: 6,
      ).timeout(const Duration(seconds: 4));
      final c = palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color;
      if (c != null && memoKey != null) _memo[memoKey] = c;
      return c;
    } catch (_) {
      return null;
    }
  }

  /// Convenience: extract from a network URL string. Returns null if
  /// the URL is null/empty or extraction fails.
  static Future<Color?> dominantFromUrl(String? url) {
    if (url == null || url.isEmpty) return Future.value(null);
    return dominant(NetworkImage(url));
  }
}

/// Builder that resolves an `ImageProvider`'s dominant color and rebuilds
/// its child once the color is ready. While extraction is in flight,
/// the [fallback] color is supplied. Use to tint surfaces around an
/// image without committing to a Stateful host widget.
class IonPaletteBuilder extends StatefulWidget {
  const IonPaletteBuilder({
    super.key,
    required this.imageUrl,
    required this.fallback,
    required this.builder,
  });
  final String? imageUrl;
  final Color fallback;
  final Widget Function(BuildContext, Color color) builder;

  @override
  State<IonPaletteBuilder> createState() => _IonPaletteBuilderState();
}

class _IonPaletteBuilderState extends State<IonPaletteBuilder> {
  Color? _resolved;
  String? _resolvedFor;

  @override
  void initState() {
    super.initState();
    _maybeExtract();
  }

  @override
  void didUpdateWidget(IonPaletteBuilder old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) _maybeExtract();
  }

  void _maybeExtract() {
    final url = widget.imageUrl;
    if (url == _resolvedFor) return;
    _resolvedFor = url;
    IonPalette.dominantFromUrl(url).then((c) {
      if (!mounted || _resolvedFor != url) return;
      if (c != null) setState(() => _resolved = c);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _resolved ?? widget.fallback);
  }
}
