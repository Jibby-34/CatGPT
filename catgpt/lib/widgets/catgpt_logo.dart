import 'package:flutter/material.dart';

class CatGptLogo extends StatelessWidget {
  final double size;
  final Color? color;
  final bool? isDark;

  const CatGptLogo({super.key, this.size = 24, this.color, this.isDark});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = isDark ?? Theme.of(context).brightness == Brightness.dark;

    final image = Image.asset(
      'assets/icons/catgpt_logo.png',
      width: size,
      height: size,
      color: color,
      fit: BoxFit.contain,
      colorBlendMode: color != null ? BlendMode.srcIn : null,
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

    final shouldInvert = isDarkMode && color == null;

    return ClipRect(
      child: shouldInvert
          ? ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                -1,  0,  0, 0, 255,
                 0, -1,  0, 0, 255,
                 0,  0, -1, 0, 255,
                 0,  0,  0, 1,   0,
              ]),
              child: image,
            )
          : image,
    );
  }
}
