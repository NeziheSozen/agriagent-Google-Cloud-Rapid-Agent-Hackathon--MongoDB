import 'package:flutter/material.dart';

/// Responsive breakpoints and BuildContext extensions for adaptive layouts.
class Breakpoints {
  Breakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1200;
}

/// Extension on [BuildContext] providing responsive utility getters.
extension ResponsiveExtension on BuildContext {
  /// The screen width in logical pixels.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// The screen height in logical pixels.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// True when screen width is below the mobile breakpoint.
  bool get isMobile => screenWidth < Breakpoints.mobile;

  /// True when screen width is between mobile and desktop breakpoints.
  bool get isTablet =>
      screenWidth >= Breakpoints.mobile && screenWidth < Breakpoints.desktop;

  /// True when screen width is at or above the desktop breakpoint.
  bool get isDesktop => screenWidth >= Breakpoints.desktop;

  /// Returns a value based on the current breakpoint.
  T responsive<T>({
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop) return desktop ?? tablet ?? mobile;
    if (isTablet) return tablet ?? mobile;
    return mobile;
  }

  /// Adaptive padding that scales with screen size.
  EdgeInsets get responsivePadding {
    if (isDesktop) return const EdgeInsets.all(24);
    if (isTablet) return const EdgeInsets.all(16);
    return const EdgeInsets.all(12);
  }

  /// Number of grid columns for responsive layouts.
  int get gridColumns {
    if (isDesktop) return 3;
    if (isTablet) return 2;
    return 1;
  }
}
