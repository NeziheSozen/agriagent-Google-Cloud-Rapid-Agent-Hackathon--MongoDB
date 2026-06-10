import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app/theme.dart';

/// A premium glassmorphism card with frosted-glass effect,
/// neon glows, and micro-interaction scale animations.
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double borderRadius;
  final Color? accentColor;
  final bool showGradientBorder;
  final double opacity;
  final bool isGlowing; // New property for critical threats or AI focus

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.borderRadius = 16,
    this.accentColor,
    this.showGradientBorder = false,
    this.opacity = 0.05,
    this.isGlowing = false,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final card = Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final glowColor = widget.accentColor ?? AgriAgentTheme.mossGreen;
        
        if (isDark) {
          // Dark mode: frosted glass effect
          return ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(widget.opacity + 0.05),
                      Colors.white.withOpacity(widget.opacity * 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: widget.showGradientBorder
                      ? Border.all(color: glowColor.withOpacity(0.8), width: 1.5)
                      : Border.all(color: Colors.white.withOpacity(0.12), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    if (widget.isGlowing || widget.showGradientBorder)
                      BoxShadow(
                        color: glowColor.withOpacity(widget.isGlowing ? 0.3 : 0.1),
                        blurRadius: widget.isGlowing ? 30 : 15,
                        spreadRadius: widget.isGlowing ? 2 : 0,
                      ),
                  ],
                ),
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          );
        } else {
          // Light mode: clean white card, no glassmorphism
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: widget.showGradientBorder
                  ? Border.all(color: glowColor.withOpacity(0.5), width: 1.5)
                  : Border.all(color: Colors.black.withOpacity(0.06), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                if (widget.isGlowing || widget.showGradientBorder)
                  BoxShadow(
                    color: glowColor.withOpacity(0.15),
                    blurRadius: widget.isGlowing ? 20 : 10,
                    spreadRadius: widget.isGlowing ? 1 : 0,
                  ),
              ],
            ),
            padding: widget.padding,
            child: widget.child,
          );
        }
      },
    );

    Widget result = card;

    if (widget.onTap != null) {
      result = GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap!();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: card,
      );
    }

    // Micro-interaction bounce on tap
    return result
        .animate(target: _isPressed ? 1 : 0)
        .scale(end: const Offset(0.97, 0.97), duration: 150.ms, curve: Curves.easeOutCubic);
  }
}
