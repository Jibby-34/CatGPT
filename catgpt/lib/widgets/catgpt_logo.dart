import 'package:flutter/material.dart';

class CatGptLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const CatGptLogo({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/catgpt_logo.png',
      width: size,
      height: size,
      color: color,
      fit: BoxFit.contain,
    );
  }
}
