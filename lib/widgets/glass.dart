import 'dart:ui';

import 'package:flutter/material.dart';

class Glass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double radius;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;

  const Glass({
    super.key,
    required this.child,
    this.blur = 18,
    this.opacity = .10,
    this.radius = 20,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: br,
            color: Colors.white.withValues(alpha: opacity),
            border: Border.all(
              color: Colors.white.withValues(alpha: .22),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 22,
                offset: const Offset(0, 12),
                color: Colors.black.withValues(alpha: .10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Superficie translúcida uniforme, sin tintes ni degradados de color.
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final double opacity;
  final double blur;
  final bool showShadow;
  final double? width;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.opacity = .82,
    this.blur = 10,
    this.showShadow = true,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceOpacity = opacity.clamp(0.0, 1.0);

    final surface = Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: Colors.white.withValues(alpha: surfaceOpacity),
        border: Border.all(
          color: const Color(0xFFB8C9E5).withValues(alpha: .58),
        ),
      ),
      child: child,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  blurRadius: 18,
                  spreadRadius: -4,
                  offset: const Offset(0, 9),
                  color: const Color(0xFF1E3A5F).withValues(alpha: .12),
                ),
                BoxShadow(
                  blurRadius: 8,
                  spreadRadius: -5,
                  offset: const Offset(-2, -2),
                  color: Colors.white.withValues(alpha: .85),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: blur <= 0
            ? surface
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: surface,
              ),
      ),
    );
  }
}

class LiquidGlassAppBarBackground extends StatelessWidget {
  const LiquidGlassAppBarBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xDD2196F3),
            border: Border(
              bottom: BorderSide(color: Color(0x66FFFFFF), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 5),
                color: const Color(0xFF0F4C81).withValues(alpha: .16),
              ),
            ],
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class LiquidGlassIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const LiquidGlassIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .16),
          border: Border.all(color: Colors.white.withValues(alpha: .42)),
        ),
        child: SizedBox.square(
          dimension: 40,
          child: IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: 23),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
