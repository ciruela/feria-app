import 'package:flutter/material.dart';

import '../../models/presupuesto_branding.dart';

/// Marca de agua Urban Tactical centrada detrás del contenido del recibo.
class UrbanTableWatermark extends StatelessWidget {
  const UrbanTableWatermark({
    super.key,
    required this.branding,
    required this.child,
    this.width = 300,
    this.opacity = 0.18,
  });

  final PresupuestoBranding branding;
  final Widget child;
  final double width;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final asset = branding.watermarkLogoAsset;
    if (asset == null) return child;

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: opacity,
              child: Image.asset(
                asset,
                width: width,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
