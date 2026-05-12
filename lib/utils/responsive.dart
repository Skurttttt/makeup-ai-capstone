import 'package:flutter/material.dart';

/// Centralized responsive design helpers.
///
/// Breakpoints follow Material 3 window-size classes (compact / medium /
/// expanded / large). All client and admin screens should rely on these
/// helpers instead of hard-coding widths so that the UI scales gracefully
/// from a 320px small phone up to a desktop browser window.
class Breakpoints {
  static const double compact = 600; // phones
  static const double medium = 905; // small tablets / large phones landscape
  static const double expanded = 1240; // tablets / small laptops
  static const double large = 1440; // desktop
}

enum ScreenSize { compact, medium, expanded, large }

extension ScreenSizeX on BuildContext {
  ScreenSize get screenSize {
    final w = MediaQuery.sizeOf(this).width;
    if (w < Breakpoints.compact) return ScreenSize.compact;
    if (w < Breakpoints.medium) return ScreenSize.medium;
    if (w < Breakpoints.expanded) return ScreenSize.expanded;
    return ScreenSize.large;
  }

  bool get isCompact => screenSize == ScreenSize.compact;
  bool get isMedium => screenSize == ScreenSize.medium;
  bool get isExpanded => screenSize == ScreenSize.expanded;
  bool get isLarge => screenSize == ScreenSize.large;
  bool get isMobile => screenSize == ScreenSize.compact;
  bool get isTabletOrLarger => screenSize.index >= ScreenSize.medium.index;
  bool get isDesktop => screenSize.index >= ScreenSize.expanded.index;

  /// Picks a value based on the current breakpoint, falling back to the
  /// nearest smaller value when an explicit value is omitted.
  T responsive<T>({
    required T compact,
    T? medium,
    T? expanded,
    T? large,
  }) {
    switch (screenSize) {
      case ScreenSize.compact:
        return compact;
      case ScreenSize.medium:
        return medium ?? compact;
      case ScreenSize.expanded:
        return expanded ?? medium ?? compact;
      case ScreenSize.large:
        return large ?? expanded ?? medium ?? compact;
    }
  }
}

/// Wraps content with a max width and adaptive horizontal padding so layouts
/// stay readable on tablet/desktop while remaining edge-to-edge on phones.
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding,
    this.center = true,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final pad = padding ??
        EdgeInsets.symmetric(
          horizontal: context.responsive<double>(
            compact: 16,
            medium: 24,
            expanded: 32,
            large: 40,
          ),
          vertical: context.responsive<double>(
            compact: 12,
            medium: 16,
            expanded: 20,
          ),
        );
    final box = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: pad, child: child),
    );
    return center ? Center(child: box) : box;
  }
}

/// A grid that automatically picks the column count based on the available
/// width. Useful for product grids, dashboard cards, etc.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 220,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childAspectRatio = 1,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / minItemWidth).floor().clamp(1, 6);
        final itemWidth =
            (width - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: AspectRatio(
                  aspectRatio: childAspectRatio,
                  child: child,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Picks between a mobile and desktop/tablet layout.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  @override
  Widget build(BuildContext context) {
    switch (context.screenSize) {
      case ScreenSize.compact:
        return mobile;
      case ScreenSize.medium:
        return tablet ?? mobile;
      case ScreenSize.expanded:
      case ScreenSize.large:
        return desktop ?? tablet ?? mobile;
    }
  }
}
