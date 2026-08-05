import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Lockup / monograma Armenext del handoff Cobre táctico.
class ArmenextLockup extends StatelessWidget {
  const ArmenextLockup({
    super.key,
    this.width = 150,
    this.height = 36,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/armenext/armenext-lockup-cobre.png',
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => Text(
        'ARMENEXT',
        style: AppText.heading.copyWith(color: AppColors.accent),
      ),
    );
  }
}

class ArmenextMonogram extends StatelessWidget {
  const ArmenextMonogram({
    super.key,
    this.size = 28,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/armenext/armenext-monogram-cobre.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.all(Radius.circular(AppDecorations.radius)),
          ),
          child: Center(
            child: Text('A', style: TextStyle(color: AppColors.onAccent, fontSize: 12)),
          ),
        ),
      ),
    );
  }
}
