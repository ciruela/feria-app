import 'package:flutter/material.dart';

import '../../models/presupuesto_branding.dart';

/// Marca de agua Urban Tactical detrás de la tabla de ítems (como el PDF original).
class UrbanTableWatermark extends StatelessWidget {
  const UrbanTableWatermark({
    super.key,
    required this.branding,
    required this.child,
  });

  final PresupuestoBranding branding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final asset = branding.watermarkLogoAsset;
    if (asset == null) return child;

    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Opacity(
            opacity: 0.22,
            child: Image.asset(
              asset,
              width: 300,
              fit: BoxFit.contain,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
