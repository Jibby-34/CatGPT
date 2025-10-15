import 'package:flutter/material.dart';

class CatGptLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const CatGptLogo({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Image.asset(
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
      ),
    );
  }
}
