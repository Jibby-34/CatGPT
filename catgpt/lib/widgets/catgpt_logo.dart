import 'package:flutter/material.dart';

class CatGptLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool? isDark;

  const CatGptLogo({super.key, this.size = 24, this.color, this.isDark});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = isDark ?? Theme.of(context).brightness == Brightness.dark;
    // If a specific color is provided, use it. Otherwise, when in dark mode
    // prefer tinting the logo to the theme's onSurface color so it appears
    // correctly against dark backgrounds (this is more reliable than using
    // a ColorFiltered inversion when the logo sits above platform views like
    // the camera preview).
    final Color? tintColor = color ?? (isDarkMode ? Theme.of(context).colorScheme.onSurface : null);

    final image = Image.asset(
      'assets/icons/catgpt_logo.png',
      width: size,
      height: size,
      color: tintColor,
      fit: BoxFit.contain,
      colorBlendMode: tintColor != null ? BlendMode.srcIn : null,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
      excludeFromSemantics: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: child,
        );
      },
    );

    return ClipRect(child: image);
  }
}
